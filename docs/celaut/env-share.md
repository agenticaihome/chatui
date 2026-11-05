# Share environment variables by QR code (2026-11-05)

Josemi asked for a way to share an environment variable between friends with a QR code.
This note is the design, and the code follows it. It adds to
[env-variables.md](env-variables.md) (the container, the questions at a launch, the
sensitive mark).

## 1. What the code holds

One variable for each code. The text of the code is JSON with a marker:

```json
{"chatui_env":1,"n":"TOKEN_DE_GITHUB","v":"ghp_...","s":true}
```

| Field | Meaning |
|---|---|
| `chatui_env` | Marker and version of the format (`1`) |
| `n` | Name of the variable |
| `v` | Value, in plain text |
| `s` | The variable is sensitive (`true`) or not (`false`) |

The reader (`EnvShare.tryParse`, `app/lib/celaut/env_share.dart`) gives null for a code that is
not of this format, that has a field of the wrong type, or that has a name or a value that the
node refuses (the rules of `env_store.dart`). The text of a code is not trusted.

A QR code of 2331 bytes is the most that the screen can show with the medium error
correction. The text of a code is limited to 2000 bytes, so a value of about 1.8 KiB is the
largest. A larger value is not shared: the dialog says so.

## 2. Security

- **No encryption.** A QR code is for two people in the same place. A key would have to
  go by the same channel, so it would protect nothing. The dialog says that whoever
  scans the code reads the value (a stronger text if the variable is sensitive).
- The value is shown only after the user taps **Share**. The code is not kept, and the
  text of the code is not given to a screen reader.
- A received value is shown hidden (eye to show it) and is saved only if the user accepts.
- A received variable does not change the sensitive mark by itself: the user sees the mark
  of the sender and can change it before saving.

## 3. The code fills a form

The code does not save anything by itself. It fills the form that the app has already, and
the user decides:

- The name of the variable (`TOKEN_DE_GITHUB`) is a suggestion. The user keeps it or changes it
  before the variable is saved. A name that exists is refused as in any form ("taken"), so the
  user chooses another name, or edits the old variable.
- The value and the mark "sensitive" of the sender are the start values of the form. The user
  can change them.

## 4. Where it is in the app

| Place | Share | Receive |
|---|---|---|
| Settings, Compute, Environment variables (`EnvVariablesScreen`) | QR icon on each row | Scan icon in the top bar: the form "Add a variable" opens filled |
| Question of a launch, the list "Choose from my variables" (`EnvQuestionsScreen`) | QR icon on each row | Button "Scan a QR code": the form "Type a value" opens filled |
| Secret requested in the chat (`EnvQuestionsPurpose.chat`) | The same list | The same button |

In the questions, the scanned value is used for the declared variable, whatever its name. The
switch **Save in my variables** is off by default, so the user can use the value once. If the
user turns it on, a field with the name to save it under appears. It starts as the name of the
code, and the user can change it (`EnvTyped.saveAs`). The sensitive warnings of
[env-variables.md](env-variables.md) (section 3.2) apply as for a typed value, with the mark
that the form shows.

## 5. Files

| Change | File |
|---|---|
| Format of the code, `EnvShare` | `app/lib/celaut/env_share.dart` |
| Share dialog, scan | `app/lib/ui/celaut/env_share_ui.dart` |
| Row action, scan, the form with `prefill` | `app/lib/ui/celaut/env_variables_screen.dart` |
| Scan button, share in the list, the name to save under (`EnvTyped.saveAs`) | `app/lib/ui/celaut/env_questions_screen.dart` |
| Strings (`celautEnvShare*`, `celautEnvScan*`, `celautEnvAskScan`) | `app/lib/l10n/app_en.arb`, `app_es.arb` |
| Tests | `app/test/celaut_env_share_test.dart` |

## 6. Open items

- A typed value that is not saved cannot be shared. The user saves it first.
- Many variables in one code are not supported. Each variable is one code.
- The screen that shows a code does not block screenshots (`FLAG_SECURE`).
