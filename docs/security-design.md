# Security Layer Design

## Overview

Argus keeps signing keys in Rust. The Flutter shell stores an AES-GCM sealed
seed blob in Android Keystore (`EncryptedSharedPreferences`) or iOS Keychain.
That platform store is the confidentiality boundary.

The sealed blob is AES-256-GCM ciphertext plus nonce (`v: 2`). The wrap key that opens it
is stored in the same Keystore store (`wrap_<id>`), and the app has no PIN of its own. To
use the key the app asks the phone for a fingerprint or face, or its screen lock
(`BiometricPrompt` with `BIOMETRIC_WEAK | DEVICE_CREDENTIAL`). A phone with neither has
nothing to ask, and the wallet opens without a prompt. Do not log or export the wrap key or
the mnemonic.

A wallet made before this change has its key wrapped by a PIN (Argon2id KEK, `pin_wrap`).
The first unlock asks for that PIN one last time (with the old lockout), stores the key in
the Keystore and deletes `pin_wrap`. A wallet that already had the biometric copy of the key
opens with the phone and drops `pin_wrap` on the spot. The Rust PIN code stays only for this
migration; it can go once no wallet has a PIN wrap.

No mnemonic is persisted. Create/restore require the user to enter or confirm
the BIP-39 phrase in the UI (Dart treats that string as secret: no logging,
controllers cleared on dispose). Phrase screens set `FLAG_SECURE` / hide
captured content. The dialog with the QR code of an environment variable
holds `FLAG_SECURE` too while it is open (`PrivacyService.holdSecure`,
[env-share.md](celaut/env-share.md)). The wallet locks when the app backgrounds.

## Lifecycle

1. **Create**: BIP-39 checksum is validated. PBKDF2 produces a 64-byte seed.
   The seed is sealed with a random AES key. Ciphertext and the key go to
   Keystore. EIP-3 children `m/44'/429'/0'/0/0..32` are loaded
   into the prover.
2. **Unlock**: Flutter asks the phone for the fingerprint or screen lock, gets the
   wrap key and calls `wallet_restore`. Rust decrypts and reloads EIP-3 children.
   Only the user's action unlocks: the app opens on the wallet overview with
   nothing unlocked, opening a seed wallet asks for its key once, and a
   cancelled prompt waits for an explicit Unlock. Nothing prompts
   on launch or on resume; a biometric sheet itself pauses and resumes the
   activity, so a prompt on resume reopens the sheet it just closed.
3. **Lock**: The handle is removed from the process map and secret keys are dropped.

## Signing

`ergo-lib::Wallet::from_mnemonic` only loads the BIP-32 master key. Argus does
**not** use that. It derives EIP-3 children and `add_secret`s them. Sends
verify the sender address belongs to the handle.

## Permissions

The app asks for the Android permission `RECORD_AUDIO` for the voice message of a chat.
It asks at the first recording only, never at the start. The microphone is open only while
the user keeps a recording open in the input of a chat. The sound stays in memory (it is
not written to the storage) until the user sends the message, and the app sends it to the
chat service of that instance only. The app records nothing in the background. The other
permissions are the camera (QR scan), the biometric check, notifications (local, with no
answer text on the lock screen) and the network. See `docs/dependency-list.md`.

## What this is not

- Not a biometric wrap-vs-sign split. Keystore/Keychain encrypts the blob at rest.
- Not memory-safe against a compromised process. `ergo-lib` types are not zeroized.
- Not a substitute for the recovery phrase. If the device store is lost, the
  phrase is the only recovery path.
