#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "channels.h"
#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  // The one window of the app. A second `chatui` (a link or a file that the desktop
  // opens) gives its command line to this app, which brings the window to the front.
  GtkWindow* window;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void window_destroy_cb(GtkWidget*, MyApplication* self) { self->window = nullptr; }

static void create_window(MyApplication* self) {
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(self)));
  self->window = window;
  g_signal_connect(window, "destroy", G_CALLBACK(window_destroy_cb), self);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Chatui");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Chatui");
  }
  gtk_window_set_icon_name(window, APPLICATION_ID);

  // The app is made for a phone: a narrow window by default. The user can make it larger.
  gtk_window_set_default_size(window, 480, 860);

  g_autoptr(FlDartProject) project = fl_dart_project_new();

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(fl_view_get_engine(view));
  secure_storage_register(messenger);
  links_register(messenger);
  package_channel_register(messenger, window);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window == nullptr) {
    create_window(self);
  } else {
    gtk_window_present(self->window);
  }
}

// Implements GApplication::command_line: the command line of this app, or of a second
// `chatui` that the desktop ran for a link or a file.
static int my_application_command_line(GApplication* application,
                                       GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  gboolean first = self->window == nullptr;
  g_application_activate(application);
  gint argc = 0;
  g_auto(GStrv) argv = g_application_command_line_get_arguments(command_line, &argc);
  if (argc > 1) {
    links_handle_arguments(argv + 1, g_application_command_line_get_cwd(command_line));
  }
  if (!first && self->window != nullptr) gtk_window_present(self->window);
  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
}

static void my_application_init(MyApplication* self) { self->window = nullptr; }

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  // Unique: one app per session. A second `chatui` gives its command line to it. That
  // needs the session bus; without one (no desktop session) each `chatui` is its own app.
  GApplicationFlags flags = G_APPLICATION_HANDLES_COMMAND_LINE;
  g_autoptr(GDBusConnection) bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, nullptr);
  if (bus == nullptr) {
    flags = static_cast<GApplicationFlags>(flags | G_APPLICATION_NON_UNIQUE);
  }
  return MY_APPLICATION(g_object_new(my_application_get_type(), "application-id",
                                     APPLICATION_ID, "flags", flags, nullptr));
}
