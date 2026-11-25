#ifndef RUNNER_CHANNELS_H_
#define RUNNER_CHANNELS_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// The Linux side of the method channels that the Android app has in Kotlin
// (app/android/app/src/main/kotlin/org/celaut/superapp). Each one keeps the name, the
// methods and the answers of its Android version, so the Dart side is the same.

// `com.argus.wallet/secure_storage` on the Secret Service (libsecret): the sealed seeds,
// their wrap keys and the key of the Celaut database (SecureStorageHandler.kt).
void secure_storage_register(FlBinaryMessenger* messenger);

// The file of the Celaut database: $XDG_DATA_HOME/org.celaut.superapp/celaut/celaut.db.
// Its folder is made if it is missing. Free it with g_free.
gchar* secure_storage_celaut_db_path();

// `org.celaut.superapp/package`: pick a `.celaut.bee` file, copy it or open it, and say if
// the network is metered (PackageHandler.kt).
void package_channel_register(FlBinaryMessenger* messenger, GtkWindow* window);

// Describes a file as the Android side does: {uri, name, bytes}. [path] is absolute.
FlValue* package_describe(const gchar* path);

// `argus/deeplink` (DeepLinkHandler.kt) and `org.celaut.superapp/incoming`
// (IncomingPackageHandler.kt).
void links_register(FlBinaryMessenger* messenger);

// The arguments of a command line (without the program): `celaut:` and `ergopay:` links,
// `.celaut.bee` files (a path or a file:// uri) and http(s) links to a service. [cwd] is
// the folder of the command line, for a relative path.
void links_handle_arguments(gchar** arguments, const gchar* cwd);

#endif  // RUNNER_CHANNELS_H_
