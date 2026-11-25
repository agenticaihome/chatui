#include "channels.h"

#include <libsecret/secret.h>

#include <string>
#include <vector>

// `com.argus.wallet/secure_storage` on Linux (SecureStorageHandler.kt on Android). Each
// value is one item of the Secret Service (GNOME Keyring, or KWallet), in the default
// collection, with the name of the Android key as its attribute `key`. The keyring is
// locked with the password of the session, as the Keystore is locked by the phone.
//
// There is no fingerprint or screen lock to ask: `hasBiometric` is false, and
// `authenticateBiometric` gives the wrap key with no prompt, as on a phone that has
// neither. There is no FLAG_SECURE either: `setSecureFlag` answers false.
//
// libsecret blocks while it talks to the keyring (and while the keyring asks for its
// password), so the calls run on a worker thread, one at a time.

namespace {

const SecretSchema* schema() {
  static const SecretSchema value = {
      "org.celaut.superapp.Secret",
      SECRET_SCHEMA_NONE,
      {{"key", SECRET_SCHEMA_ATTRIBUTE_STRING}, {nullptr, SECRET_SCHEMA_ATTRIBUTE_STRING}},
  };
  return &value;
}

constexpr const char* kRegistry = "wallet_registry";
// The key of the Celaut database: one for the app, not one per wallet.
constexpr const char* kCelautDbKey = "celaut_db_key_v1";

GMutex worker_lock;

// What a call asks, read on the main thread (FlValue is not for other threads).
struct Request {
  std::string method;
  bool has_wallet_id = false;
  std::string wallet_id;
  bool has_value = false;
  std::string value;
  gint64 count = 0;
  gint64 until = 0;
};

// What the worker answers.
struct Reply {
  enum Kind { kNull, kBool, kString, kList, kPinGate, kError, kNotImplemented } kind = kNull;
  bool flag = false;
  std::string text;
  std::vector<std::string> list;
  gint64 count = 0;
  gint64 until = 0;
  std::string code;
};

struct Failure {
  std::string code;
  std::string message;
};

// The store, on the worker thread. Each call throws a Failure if the keyring fails.
class Store {
 public:
  bool get(const std::string& key, std::string* out) {
    GError* error = nullptr;
    gchar* value =
        secret_password_lookup_sync(schema(), nullptr, &error, "key", key.c_str(), nullptr);
    check(error);
    if (value == nullptr) return false;
    if (out != nullptr) *out = value;
    secret_password_free(value);
    return true;
  }

  bool contains(const std::string& key) { return get(key, nullptr); }

  void put(const std::string& key, const std::string& value) {
    GError* error = nullptr;
    g_autofree gchar* label = g_strdup_printf("Celaut: %s", key.c_str());
    gboolean ok = secret_password_store_sync(schema(), SECRET_COLLECTION_DEFAULT, label,
                                             value.c_str(), nullptr, &error, "key",
                                             key.c_str(), nullptr);
    check(error);
    if (!ok) throw Failure{"STORAGE_ERROR", "Failed to persist " + key};
  }

  void remove(const std::string& key) {
    GError* error = nullptr;
    // False with no error: there was nothing to remove.
    secret_password_clear_sync(schema(), nullptr, &error, "key", key.c_str(), nullptr);
    check(error);
  }

  // The wallet registry: the ids, one per line (an id is a UUID, or "legacy").
  std::vector<std::string> wallet_ids() {
    std::string raw;
    std::vector<std::string> ids;
    if (!get(kRegistry, &raw)) return ids;
    g_auto(GStrv) parts = g_strsplit(raw.c_str(), "\n", -1);
    for (gchar** part = parts; *part != nullptr; part++) {
      if (**part != '\0') ids.emplace_back(*part);
    }
    return ids;
  }

  void set_wallet_ids(const std::vector<std::string>& ids) {
    std::string raw;
    for (const auto& id : ids) {
      if (!raw.empty()) raw += '\n';
      raw += id;
    }
    put(kRegistry, raw);
  }

  void add_wallet_id(const std::string& id) {
    auto ids = wallet_ids();
    for (const auto& known : ids) {
      if (known == id) return;
    }
    ids.push_back(id);
    set_wallet_ids(ids);
  }

  void remove_wallet_id(const std::string& id) {
    auto ids = wallet_ids();
    std::vector<std::string> kept;
    for (const auto& known : ids) {
      if (known != id) kept.push_back(known);
    }
    if (kept.size() != ids.size()) set_wallet_ids(kept);
  }

 private:
  static void check(GError* error) {
    if (error == nullptr) return;
    Failure failure{"STORAGE_ERROR", error->message};
    g_error_free(error);
    throw failure;
  }
};

std::string seed_key(const Request& r) {
  return r.has_wallet_id ? "seed_" + r.wallet_id : "encrypted_seed";
}

std::string wrap_key(const Request& r) {
  return r.has_wallet_id ? "wrap_" + r.wallet_id : "wrap_key";
}

std::string pin_wrap_key(const Request& r) {
  return r.has_wallet_id ? "pin_" + r.wallet_id : "pin_wrap";
}

Reply text_or_null(Store& store, const std::string& key) {
  Reply reply;
  if (store.get(key, &reply.text)) reply.kind = Reply::kString;
  return reply;
}

Reply boolean(bool value) {
  Reply reply;
  reply.kind = Reply::kBool;
  reply.flag = value;
  return reply;
}

Reply invalid(const char* message) {
  Reply reply;
  reply.kind = Reply::kError;
  reply.code = "INVALID_ARGS";
  reply.text = message;
  return reply;
}

gint64 number(Store& store, const char* key) {
  std::string raw;
  if (!store.get(key, &raw)) return 0;
  return g_ascii_strtoll(raw.c_str(), nullptr, 10);
}

Reply run(const Request& r) {
  Store store;
  const std::string& m = r.method;
  if (m == "saveEncryptedSeed") {
    if (!r.has_value || r.value.empty()) return invalid("Missing encryptedSeedJson");
    store.put(seed_key(r), r.value);
    if (r.has_wallet_id) store.add_wallet_id(r.wallet_id);
    return boolean(true);
  }
  if (m == "loadEncryptedSeed") return text_or_null(store, seed_key(r));
  if (m == "saveWrapKey") {
    if (!r.has_value || r.value.empty()) return invalid("Missing wrapKey");
    store.put(wrap_key(r), r.value);
    return boolean(true);
  }
  // No fingerprint and no screen lock to ask on the desktop: the wallet opens, as on a
  // phone that has neither (the keyring is unlocked by the session).
  if (m == "loadWrapKey" || m == "authenticateBiometric") return text_or_null(store, wrap_key(r));
  if (m == "savePinWrap") {
    if (!r.has_value || r.value.empty()) return invalid("Missing pinWrapJson");
    store.put(pin_wrap_key(r), r.value);
    return boolean(true);
  }
  if (m == "loadPinWrap") return text_or_null(store, pin_wrap_key(r));
  if (m == "deletePinWrap") {
    store.remove(pin_wrap_key(r));
    return Reply();
  }
  if (m == "deleteWrapKey") {
    store.remove(wrap_key(r));
    return Reply();
  }
  if (m == "deleteEncryptedSeed" || m == "deleteWallet") {
    if (m == "deleteWallet" && !r.has_wallet_id) return invalid("Missing walletId");
    store.remove(seed_key(r));
    store.remove(wrap_key(r));
    store.remove(pin_wrap_key(r));
    if (r.has_wallet_id) store.remove_wallet_id(r.wallet_id);
    return Reply();
  }
  if (m == "hasEncryptedSeed") {
    if (r.has_wallet_id) return boolean(store.contains(seed_key(r)));
    return boolean(store.contains("encrypted_seed") || store.contains(kRegistry));
  }
  if (m == "hasPinWrap") return boolean(store.contains(pin_wrap_key(r)));
  if (m == "hasWrapKey") return boolean(store.contains(wrap_key(r)));
  if (m == "listWalletIds") {
    Reply reply;
    reply.kind = Reply::kList;
    reply.list = store.wallet_ids();
    bool has_legacy = false;
    for (const auto& id : reply.list) has_legacy = has_legacy || id == "legacy";
    if (!has_legacy && store.contains("encrypted_seed")) reply.list.emplace_back("legacy");
    return reply;
  }
  if (m == "loadCelautDbKey") return text_or_null(store, kCelautDbKey);
  if (m == "saveCelautDbKey") {
    if (!r.has_value || r.value.empty()) return invalid("Missing key");
    store.put(kCelautDbKey, r.value);
    return Reply();
  }
  if (m == "loadPinGate") {
    Reply reply;
    reply.kind = Reply::kPinGate;
    reply.count = number(store, "pin_fail_count");
    reply.until = number(store, "pin_lock_until");
    return reply;
  }
  if (m == "savePinGate") {
    store.put("pin_fail_count", std::to_string(r.count));
    store.put("pin_lock_until", std::to_string(r.until));
    return Reply();
  }
  if (m == "migrateLegacyWallet") {
    if (!r.has_value || r.value.empty()) return invalid("Missing newWalletId");
    std::string seed, wrap, pin;
    if (!store.get("encrypted_seed", &seed)) return boolean(false);
    bool has_wrap = store.get("wrap_key", &wrap);
    bool has_pin = store.get("pin_wrap", &pin);
    store.put("seed_" + r.value, seed);
    if (has_wrap) store.put("wrap_" + r.value, wrap);
    if (has_pin) store.put("pin_" + r.value, pin);
    store.add_wallet_id(r.value);
    store.remove("encrypted_seed");
    store.remove("wrap_key");
    store.remove("pin_wrap");
    return boolean(true);
  }
  Reply reply;
  reply.kind = Reply::kNotImplemented;
  return reply;
}

void worker(GTask* task, gpointer, gpointer data, GCancellable*) {
  const Request* request = static_cast<const Request*>(data);
  Reply* reply;
  g_mutex_lock(&worker_lock);
  try {
    reply = new Reply(run(*request));
  } catch (const Failure& failure) {
    reply = new Reply();
    reply->kind = Reply::kError;
    reply->code = failure.code;
    reply->text = failure.message;
  }
  g_mutex_unlock(&worker_lock);
  g_task_return_pointer(task, reply, [](gpointer p) { delete static_cast<Reply*>(p); });
}

FlValue* value_of(const Reply& reply) {
  switch (reply.kind) {
    case Reply::kBool:
      return fl_value_new_bool(reply.flag);
    case Reply::kString:
      return fl_value_new_string(reply.text.c_str());
    case Reply::kList: {
      FlValue* list = fl_value_new_list();
      for (const auto& item : reply.list) {
        fl_value_append_take(list, fl_value_new_string(item.c_str()));
      }
      return list;
    }
    case Reply::kPinGate: {
      FlValue* map = fl_value_new_map();
      fl_value_set_string_take(map, "count", fl_value_new_int(reply.count));
      fl_value_set_string_take(map, "until", fl_value_new_int(reply.until));
      return map;
    }
    default:
      return fl_value_new_null();
  }
}

void done_cb(GObject*, GAsyncResult* result, gpointer user_data) {
  FlMethodCall* call = FL_METHOD_CALL(user_data);
  Reply* reply = static_cast<Reply*>(g_task_propagate_pointer(G_TASK(result), nullptr));
  if (reply == nullptr) {
    fl_method_call_respond_error(call, "STORAGE_ERROR", "no answer", nullptr, nullptr);
  } else if (reply->kind == Reply::kError) {
    fl_method_call_respond_error(call, reply->code.c_str(), reply->text.c_str(), nullptr,
                                 nullptr);
  } else if (reply->kind == Reply::kNotImplemented) {
    fl_method_call_respond_not_implemented(call, nullptr);
  } else {
    g_autoptr(FlValue) value = value_of(*reply);
    fl_method_call_respond_success(call, value, nullptr);
  }
  delete reply;
  g_object_unref(call);
}

bool string_arg(FlValue* args, const char* name, std::string* out) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return false;
  FlValue* value = fl_value_lookup_string(args, name);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) return false;
  *out = fl_value_get_string(value);
  return true;
}

gint64 int_arg(FlValue* args, const char* name) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return 0;
  FlValue* value = fl_value_lookup_string(args, name);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT) return 0;
  return fl_value_get_int(value);
}

void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  // Answers with no keyring.
  if (g_strcmp0(method, "hasBiometric") == 0 || g_strcmp0(method, "setSecureFlag") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
    fl_method_call_respond_success(call, result, nullptr);
    return;
  }
  if (g_strcmp0(method, "celautDbPath") == 0) {
    g_autofree gchar* path = secure_storage_celaut_db_path();
    g_autoptr(FlValue) result = fl_value_new_string(path);
    fl_method_call_respond_success(call, result, nullptr);
    return;
  }
  Request* request = new Request();
  request->method = method;
  request->has_wallet_id = string_arg(args, "walletId", &request->wallet_id);
  for (const char* name : {"encryptedSeedJson", "wrapKey", "pinWrapJson", "key", "newWalletId"}) {
    if (string_arg(args, name, &request->value)) {
      request->has_value = true;
      break;
    }
  }
  request->count = int_arg(args, "count");
  request->until = int_arg(args, "until");
  g_autoptr(GTask) task = g_task_new(nullptr, nullptr, done_cb, g_object_ref(call));
  g_task_set_task_data(task, request, [](gpointer p) { delete static_cast<Request*>(p); });
  g_task_run_in_thread(task, worker);
}

FlMethodChannel* channel = nullptr;

}  // namespace

gchar* secure_storage_celaut_db_path() {
  g_autofree gchar* folder =
      g_build_filename(g_get_user_data_dir(), APPLICATION_ID, "celaut", nullptr);
  g_mkdir_with_parents(folder, 0700);
  return g_build_filename(folder, "celaut.db", nullptr);
}

void secure_storage_register(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_clear_object(&channel);
  channel = fl_method_channel_new(messenger, "com.argus.wallet/secure_storage",
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr, nullptr);
}
