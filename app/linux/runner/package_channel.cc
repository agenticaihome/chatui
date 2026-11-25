#include "channels.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <atomic>

// The package of a service (`docs/celaut/package.md`), as PackageHandler.kt does it on
// Android: the user picks a `.celaut.bee` file, and the app copies it into its folder with
// a stream, or (setting "Do not keep the filesystem of a service") gives Rust a file
// descriptor with no copy. While the copy runs, it tells its bytes to Flutter (`copied`).

namespace {

// The time between two counts of the copy that go to Flutter.
constexpr gint64 kReportUs = 100 * 1000;

FlMethodChannel* channel = nullptr;
GtkWindow* parent_window = nullptr;
FlMethodCall* pending_pick = nullptr;

// The copy that runs now stops when this is set. One copy at a time.
std::atomic<bool> cancelled(false);

void respond_null(FlMethodCall* call) {
  g_autoptr(FlValue) result = fl_value_new_null();
  fl_method_call_respond_success(call, result, nullptr);
}

void pick_response_cb(GtkNativeDialog* dialog, gint response, gpointer) {
  FlMethodCall* call = pending_pick;
  pending_pick = nullptr;
  g_autofree gchar* path = nullptr;
  if (response == GTK_RESPONSE_ACCEPT) {
    path = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
  }
  if (call != nullptr) {
    if (path != nullptr) {
      g_autoptr(FlValue) chosen = package_describe(path);
      fl_method_call_respond_success(call, chosen, nullptr);
    } else {
      respond_null(call);
    }
    g_object_unref(call);
  }
  g_object_unref(dialog);
}

void pick(FlMethodCall* call) {
  // One question at a time: an older one that is still open gets no file.
  if (pending_pick != nullptr) {
    respond_null(pending_pick);
    g_clear_object(&pending_pick);
  }
  pending_pick = FL_METHOD_CALL(g_object_ref(call));
  // Any type: a .celaut.bee file has no MIME type that every desktop knows. The labels
  // of the buttons are the ones of GTK, in the language of the desktop.
  GtkFileChooserNative* dialog = gtk_file_chooser_native_new(
      nullptr, parent_window, GTK_FILE_CHOOSER_ACTION_OPEN, nullptr, nullptr);
  gtk_native_dialog_set_modal(GTK_NATIVE_DIALOG(dialog), TRUE);
  g_signal_connect(dialog, "response", G_CALLBACK(pick_response_cb), nullptr);
  gtk_native_dialog_show(GTK_NATIVE_DIALOG(dialog));
}

const gchar* uri_of(FlMethodCall* call) {
  FlValue* args = fl_method_call_get_args(call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return nullptr;
  FlValue* uri = fl_value_lookup_string(args, "uri");
  if (uri == nullptr || fl_value_get_type(uri) != FL_VALUE_TYPE_STRING) return nullptr;
  return fl_value_get_string(uri);
}

// The path of a `uri` of the Dart side: the path that pickPackage or the command line
// gave, or a file:// uri.
gchar* path_of(const gchar* uri) {
  if (g_str_has_prefix(uri, "file:")) return g_filename_from_uri(uri, nullptr, nullptr);
  return g_path_is_absolute(uri) ? g_strdup(uri) : nullptr;
}

gboolean report_idle(gpointer data) {
  gint64 bytes = GPOINTER_TO_SIZE(data);
  if (channel != nullptr) {
    g_autoptr(FlValue) args = fl_value_new_int(bytes);
    fl_method_channel_invoke_method(channel, "copied", args, nullptr, nullptr, nullptr);
  }
  return G_SOURCE_REMOVE;
}

// At the priority of the answer of the copy, so that the last count comes before it.
void report(gint64 bytes) {
  g_idle_add_full(G_PRIORITY_DEFAULT, report_idle,
                  GSIZE_TO_POINTER(static_cast<gsize>(bytes)), nullptr);
}

struct Copy {
  gchar* source;
  gchar* target;
  gint64 bytes;
  gboolean was_cancelled;
};

void copy_free(gpointer data) {
  Copy* copy = static_cast<Copy*>(data);
  g_free(copy->source);
  g_free(copy->target);
  g_free(copy);
}

// Not in the cache: the folder is next to the library of the services, on the same disk,
// so the import moves the copy and does not copy it again. One copy at a time: what is in
// the folder is left from a copy that stopped (the app was closed).
gchar* incoming_folder() {
  g_autofree gchar* db = secure_storage_celaut_db_path();
  g_autofree gchar* celaut = g_path_get_dirname(db);
  return g_build_filename(celaut, "packages", "incoming", nullptr);
}

void copy_thread(GTask* task, gpointer, gpointer data, GCancellable*) {
  Copy* copy = static_cast<Copy*>(data);
  g_autofree gchar* folder = incoming_folder();
  if (g_mkdir_with_parents(folder, 0700) != 0) {
    g_task_return_new_error(task, G_IO_ERROR, g_io_error_from_errno(errno), "%s",
                            g_strerror(errno));
    return;
  }
  g_autoptr(GDir) dir = g_dir_open(folder, 0, nullptr);
  if (dir != nullptr) {
    const gchar* name;
    while ((name = g_dir_read_name(dir)) != nullptr) {
      g_autofree gchar* old = g_build_filename(folder, name, nullptr);
      unlink(old);
    }
  }
  g_autofree gchar* file_name =
      g_strdup_printf("picked-%" G_GINT64_FORMAT ".bee", g_get_real_time() / 1000);
  copy->target = g_build_filename(folder, file_name, nullptr);

  int in = open(copy->source, O_RDONLY | O_CLOEXEC);
  if (in < 0) {
    g_task_return_new_error(task, G_IO_ERROR, g_io_error_from_errno(errno), "%s",
                            g_strerror(errno));
    return;
  }
  int out = open(copy->target, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
  if (out < 0) {
    int saved = errno;
    close(in);
    g_task_return_new_error(task, G_IO_ERROR, g_io_error_from_errno(saved), "%s",
                            g_strerror(saved));
    return;
  }
  constexpr gsize kBuffer = 1 << 16;
  g_autofree char* buffer = static_cast<char*>(g_malloc(kBuffer));
  gint64 total = 0;
  gint64 reported = 0;
  int failure = 0;
  while (true) {
    if (cancelled.load()) {
      copy->was_cancelled = TRUE;
      break;
    }
    ssize_t n = read(in, buffer, kBuffer);
    if (n < 0 && errno == EINTR) continue;
    if (n < 0) {
      failure = errno;
      break;
    }
    if (n == 0) break;
    ssize_t written = 0;
    while (written < n) {
      ssize_t w = write(out, buffer + written, n - written);
      if (w < 0 && errno == EINTR) continue;
      if (w < 0) {
        failure = errno;
        break;
      }
      written += w;
    }
    if (failure != 0) break;
    total += n;
    gint64 now = g_get_monotonic_time();
    if (now - reported >= kReportUs) {
      reported = now;
      report(total);
    }
  }
  close(in);
  if (close(out) != 0 && failure == 0) failure = errno;
  if (copy->was_cancelled || failure != 0) {
    unlink(copy->target);
    if (copy->was_cancelled) {
      g_task_return_boolean(task, FALSE);
    } else {
      g_task_return_new_error(task, G_IO_ERROR, g_io_error_from_errno(failure), "%s",
                              g_strerror(failure));
    }
    return;
  }
  report(total);
  copy->bytes = total;
  g_task_return_boolean(task, TRUE);
}

void copy_done_cb(GObject*, GAsyncResult* result, gpointer user_data) {
  FlMethodCall* call = FL_METHOD_CALL(user_data);
  Copy* copy = static_cast<Copy*>(g_task_get_task_data(G_TASK(result)));
  g_autoptr(GError) error = nullptr;
  gboolean done = g_task_propagate_boolean(G_TASK(result), &error);
  if (error != nullptr) {
    fl_method_call_respond_error(call, "copy_failed", error->message, nullptr, nullptr);
  } else if (!done || copy->was_cancelled) {
    fl_method_call_respond_error(call, "cancelled", "the copy was cancelled", nullptr,
                                 nullptr);
  } else {
    g_autoptr(FlValue) answer = fl_value_new_map();
    fl_value_set_string_take(answer, "path", fl_value_new_string(copy->target));
    fl_value_set_string_take(answer, "bytes", fl_value_new_int(copy->bytes));
    fl_method_call_respond_success(call, answer, nullptr);
  }
  g_object_unref(call);
}

void copy_package(FlMethodCall* call) {
  const gchar* uri = uri_of(call);
  gchar* source = uri != nullptr ? path_of(uri) : nullptr;
  if (source == nullptr) {
    fl_method_call_respond_error(call, "copy_failed", "the call has no file", nullptr,
                                 nullptr);
    return;
  }
  cancelled.store(false);
  Copy* copy = g_new0(Copy, 1);
  copy->source = source;
  g_autoptr(GTask) task = g_task_new(nullptr, nullptr, copy_done_cb, g_object_ref(call));
  g_task_set_task_data(task, copy, copy_free);
  g_task_run_in_thread(task, copy_thread);
}

// A file descriptor of the file, with no copy: Rust reads the file where it is
// (`celaut_import_package_fd`) and closes the descriptor.
void open_package(FlMethodCall* call) {
  const gchar* uri = uri_of(call);
  g_autofree gchar* path = uri != nullptr ? path_of(uri) : nullptr;
  if (path == nullptr) {
    fl_method_call_respond_error(call, "open_failed", "the call has no file", nullptr,
                                 nullptr);
    return;
  }
  int fd = open(path, O_RDONLY | O_CLOEXEC);
  struct stat st;
  if (fd < 0 || fstat(fd, &st) != 0) {
    int saved = errno;
    if (fd >= 0) close(fd);
    fl_method_call_respond_error(call, "open_failed", g_strerror(saved), nullptr, nullptr);
    return;
  }
  g_autoptr(FlValue) answer = fl_value_new_map();
  fl_value_set_string_take(answer, "fd", fl_value_new_int(fd));
  fl_value_set_string_take(answer, "bytes", fl_value_new_int(st.st_size));
  fl_method_call_respond_success(call, answer, nullptr);
}

void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  if (g_strcmp0(method, "pickPackage") == 0) {
    pick(call);
  } else if (g_strcmp0(method, "copyPackage") == 0) {
    copy_package(call);
  } else if (g_strcmp0(method, "openPackage") == 0) {
    open_package(call);
  } else if (g_strcmp0(method, "cancelCopy") == 0) {
    cancelled.store(true);
    respond_null(call);
  } else if (g_strcmp0(method, "isMetered") == 0) {
    GNetworkMonitor* monitor = g_network_monitor_get_default();
    g_autoptr(FlValue) result =
        fl_value_new_bool(monitor != nullptr && g_network_monitor_get_network_metered(monitor));
    fl_method_call_respond_success(call, result, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

}  // namespace

FlValue* package_describe(const gchar* path) {
  struct stat st;
  gint64 bytes = stat(path, &st) == 0 ? st.st_size : -1;
  g_autofree gchar* name = g_path_get_basename(path);
  FlValue* item = fl_value_new_map();
  fl_value_set_string_take(item, "uri", fl_value_new_string(path));
  fl_value_set_string_take(item, "name", fl_value_new_string(name));
  fl_value_set_string_take(item, "bytes", fl_value_new_int(bytes));
  return item;
}

void package_channel_register(FlBinaryMessenger* messenger, GtkWindow* window) {
  parent_window = window;
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_clear_object(&channel);
  channel = fl_method_channel_new(messenger, "org.celaut.superapp/package",
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr, nullptr);
}
