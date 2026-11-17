#include <stdlib.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // libwallet_ffi.so is in the lib folder of the bundle, next to the executable. Without
  // this, flutter_rust_bridge first looks for it in a folder relative to the working
  // directory (../rust/crates/wallet-ffi/target/release), which another program could
  // fill. /proc/self/exe is the bundle also when /usr/bin/chatui is a link to it.
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe != nullptr) {
    g_autofree gchar* bundle = g_path_get_dirname(exe);
    g_autofree gchar* lib = g_build_filename(bundle, "lib", nullptr);
    setenv("FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR", lib, 1);
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
