# Rules for Claude Code in this project

## Do not format the code with `dart format`

Do not run `dart format` on a directory, on `lib` or on `test`. The project does not use the
formatter of the Dart SDK. The code has its own style (lines up to 120 characters). A run of
`dart format` changes the style of many files that you did not edit. It already happened
several times.

- Edit by hand. Keep the style of the lines around your change.
- Do not format a file that you did not edit.
- If you must check a format, run `dart format --output=none --set-exit-if-changed <file>`
  on one file that you edited. This command does not change the file.
- Do not format the generated files (`app/lib/celaut/chat/gen/`, `app/lib/l10n/app_localizations*.dart`).
  Generate them again: `protoc` with `protoc-gen-dart` for `docs/celaut/*.proto`, and
  `flutter gen-l10n` for the `.arb` files.

## Before you finish

- Run `git status` and `git diff --stat`. Only the files of your task must be in the list. If
  other files are in it, find out why. Do not leave a format change in them.
- Run `flutter analyze` and the tests of the code that you changed.
- Do not use `git checkout --` or `git restore` to remove a change that the user can need. First
  ask the user.
