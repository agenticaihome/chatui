#include "channels.h"

#include <string.h>

// The links and the files that the desktop gives to the app on its command line: the
// `.desktop` file runs `superapp %U` for a `celaut:` or `ergopay:` link and for a
// `.celaut.bee` file. A second `superapp` gives its command line to the app that runs
// (GApplication is unique), so a link that comes while the app is open arrives here too.

namespace {

// The longest `celaut:` link that crosses the channel, as on Android: Flutter sees that a
// longer one is too long, and refuses it.
constexpr glong kMaxCelautLink = 4096;

FlMethodChannel* deep_link_channel = nullptr;
FlMethodChannel* incoming_channel = nullptr;

// The link that waits for `getInitialLink`. Flutter asks for it once it listens, so a link
// that comes before that waits here, and a link that comes after goes through `onLink`.
gchar* initial_link = nullptr;
gboolean flutter_listens = FALSE;

// The file or the link to a service that waits until Flutter has it: `incoming` gives it
// at once if Flutter listens, and `takeIncoming` gives it after a cold start.
FlValue* pending_incoming = nullptr;

gboolean has_scheme(const gchar* text, const gchar* scheme) {
  return g_ascii_strncasecmp(text, scheme, strlen(scheme)) == 0;
}

void deep_link_call_cb(FlMethodChannel* channel, FlMethodCall* call, gpointer) {
  if (g_strcmp0(fl_method_call_get_name(call), "getInitialLink") != 0) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  flutter_listens = TRUE;
  g_autoptr(FlValue) result =
      initial_link != nullptr ? fl_value_new_string(initial_link) : fl_value_new_null();
  g_clear_pointer(&initial_link, g_free);
  fl_method_call_respond_success(call, result, nullptr);
}

void give_link(const gchar* link) {
  g_autofree gchar* text = nullptr;
  if (has_scheme(link, "celaut:") && g_utf8_strlen(link, -1) > kMaxCelautLink) {
    text = g_utf8_substring(link, 0, kMaxCelautLink + 1);
  } else {
    text = g_strdup(link);
  }
  if (!flutter_listens || deep_link_channel == nullptr) {
    g_free(initial_link);
    initial_link = g_steal_pointer(&text);
    return;
  }
  g_autoptr(FlValue) args = fl_value_new_string(text);
  fl_method_channel_invoke_method(deep_link_channel, "onLink", args, nullptr, nullptr,
                                  nullptr);
}

void incoming_call_cb(FlMethodChannel* channel, FlMethodCall* call, gpointer) {
  if (g_strcmp0(fl_method_call_get_name(call), "takeIncoming") != 0) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  g_autoptr(FlValue) result =
      pending_incoming != nullptr ? fl_value_ref(pending_incoming) : fl_value_new_null();
  g_clear_pointer(&pending_incoming, fl_value_unref);
  fl_method_call_respond_success(call, result, nullptr);
}

void incoming_answer_cb(GObject* object, GAsyncResult* result, gpointer user_data) {
  FlValue* item = static_cast<FlValue*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response = fl_method_channel_invoke_method_finish(
      FL_METHOD_CHANNEL(object), result, &error);
  // Flutter took it: it does not wait any more. Without an answer (Flutter does not listen
  // yet) it stays for `takeIncoming`.
  if (response != nullptr && FL_IS_METHOD_SUCCESS_RESPONSE(response) &&
      pending_incoming == item) {
    g_clear_pointer(&pending_incoming, fl_value_unref);
  }
  fl_value_unref(item);
}

void give_incoming(FlValue* item) {
  if (pending_incoming != nullptr) fl_value_unref(pending_incoming);
  pending_incoming = fl_value_ref(item);
  if (incoming_channel == nullptr) return;
  fl_method_channel_invoke_method(incoming_channel, "incoming", item, nullptr,
                                  incoming_answer_cb, fl_value_ref(item));
}

// The absolute path of a file argument, or null if it is not a file that exists.
gchar* file_of(const gchar* argument, const gchar* cwd) {
  g_autoptr(GFile) file = nullptr;
  if (has_scheme(argument, "file:")) {
    file = g_file_new_for_uri(argument);
  } else if (g_path_is_absolute(argument)) {
    file = g_file_new_for_path(argument);
  } else {
    file = g_file_new_for_commandline_arg_and_cwd(argument, cwd);
  }
  gchar* path = g_file_get_path(file);
  if (path == nullptr || !g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
    g_free(path);
    return nullptr;
  }
  return path;
}

}  // namespace

void links_register(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_clear_object(&deep_link_channel);
  g_clear_object(&incoming_channel);
  flutter_listens = FALSE;
  deep_link_channel =
      fl_method_channel_new(messenger, "argus/deeplink", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(deep_link_channel, deep_link_call_cb, nullptr,
                                            nullptr);
  incoming_channel = fl_method_channel_new(messenger, "org.celaut.superapp/incoming",
                                           FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(incoming_channel, incoming_call_cb, nullptr,
                                            nullptr);
}

void links_handle_arguments(gchar** arguments, const gchar* cwd) {
  for (gchar** arg = arguments; arg != nullptr && *arg != nullptr; arg++) {
    const gchar* text = *arg;
    if (*text == '\0' || !g_utf8_validate(text, -1, nullptr)) continue;
    if (has_scheme(text, "celaut:") || has_scheme(text, "ergopay:")) {
      give_link(text);
      continue;
    }
    // An http(s) link to a service (issue #135); Flutter checks it before the download.
    if (has_scheme(text, "http://") || has_scheme(text, "https://")) {
      g_autoptr(FlValue) item = fl_value_new_map();
      fl_value_set_string_take(item, "link", fl_value_new_string(text));
      give_incoming(item);
      continue;
    }
    g_autofree gchar* path = file_of(text, cwd);
    if (path == nullptr) continue;
    g_autoptr(FlValue) item = package_describe(path);
    give_incoming(item);
  }
}
