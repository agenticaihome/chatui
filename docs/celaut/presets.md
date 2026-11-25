# Presets: the wheel of the pencil button (2026-11-19)

Josemi asked for it on 2026-11-19: keep it simple, change only the pencil button of the
list of chats (the one that opens the skills, now the objectives), and give it a wheel with a few services that
are already configured, with their environment variables. A preset comes from an instance
that exists: its info page has "Pin as preset" ("Anclar como preconfigurado").

Nothing else of the home screen changes: the same bottom bar, the same pencil button, the
same screen of objectives.

## 1. What a preset is

A preset is:

- the service, by its hash (the service id);
- the environment variables that its instance was started with (section 3);
- a name: the name of the instance by default, which the user can change;
- an icon: the robot of the instance that it came from (`RobotAvatar`, from the instance id).

There are 8 presets at most. Only this phone has them: the node gets nothing, as for the
groups of the chats. Code: `ServicePresets` and `ServicePreset` in
`app/lib/celaut/service_presets.dart`.

## 2. Pin as preset

The info page of an instance (`InstanceInfoScreen`), running, hibernated or stopped, has
"Pin as preset" under its details, with one line that says what it does: "Start a new
instance of this service with the same settings from the ✏ button of Chats".

The button asks for the name (the name of the instance is filled in) and says, before the
user pins it:

- that a tap on the preset starts a new instance of the service with the same variables, and
  that the user still sees the cost and confirms it;
- how many secret values the launch will ask for again (section 3), if any;
- that the launch asks for the variables, if the app does not know the ones of this instance
  (an instance started before this version, or on another phone).

Once pinned, the page shows "Pinned to the ✏ button as "<name>"" and Unpin. A full wheel
says so and asks nothing: the user removes a preset first (a long press on it, section 4).

Deleting a stopped instance does not remove a preset pinned from it.

## 3. The variables, and the secrets

No instance kept its variables before: the start request goes to the node and the app kept
nothing. Now each launch of Run (the objectives, the files of the phone, a preset) keeps what
was given to each declared variable, by the instance id, so that the instance can be pinned
later. A pin copies that list.

For each declared variable the app keeps one of four things:

| What the user gave at the launch | What is kept | At the next launch from the preset |
|---|---|---|
| A variable of the container | Its name only. The value stays in the container, in the encrypted Celaut database | The same variable of the container. If it is not there any more, the question asks |
| A typed value, saved in the container ("Save it in my variables") | The name that it was saved under | As above |
| A typed value that is **not** sensitive | The value | The same value |
| A typed value marked as **sensitive**, not saved | Nothing: only "ask" | The question asks for it again |
| Skipped | "skip" | Skipped |

So a secret is never in the preferences of the app (SharedPreferences, plain text). A
sensitive value is either in the container, which is already the protected store of the app
for values, or the user types it again. That follows the choice of the user at the launch:
a secret that the user did not want to save is not saved by a preset either.

A typed value that the user did not mark as sensitive is kept as text, as the app already
treats such a value as not a credential ([env-variables.md](env-variables.md), section 3.2).

The data: one JSON text in SharedPreferences, key `celaut_presets_v1`, with the presets and
the variables of the last 200 launches. A stored text is not trusted when it is read: a
service id that is not 64 hexadecimal characters, a name or a value that the node would
refuse, are left out.

## 4. The wheel

The pencil button of Chats (`PresetWheelButton`, `app/lib/ui/celaut/preset_wheel.dart`):

- **No preset:** it is the button of before. A tap opens "New conversation" (the objectives).
- **With presets:** a tap opens the wheel over the list, which goes dark. The wheel has
  "Objectives" (the first slot, above the button) and the presets, in the order that they were
  pinned. The slots are on rings of a quarter of a circle, up and to the left of the button
  (to the right in a layout from right to left): 3 on the first ring, 4 on the second, the
  rest on the third. On a phone on its side the rings come closer.
  - A tap on Objectives opens "New conversation", as the button did.
  - A tap on a preset starts it (section 5).
  - A long press on a preset opens a sheet: Rename, Remove from the wheel.
  - The button turns into Close. Close, a tap outside the wheel, Back and Esc close it.
- **Press and slide:** a slide from the button, or a long press on it, opens the wheel at
  once. The slot under the finger grows and gets the colour of the theme, with a small
  vibration; letting go on it chooses it. Letting go elsewhere after a slide closes the wheel;
  a long press without a slide leaves the wheel open, for taps.

The wheel is a route of its own (a popup), so the screen reader reads only the wheel, and
Back closes it. Each slot is a button: "Start <name>", or "Objectives: choose a new service",
with the long press (and a custom action "Rename or remove") on the presets. The button has
the hint "Opens your presets. Slide to one and let go to start it." Nothing needs a slide.
The colours come from the theme (light and dark); the slots come out of the button unless
the system asks for less motion.

## 5. A launch from a preset

A preset starts by the steps of Run on an objective (`RunServiceSection`, with `preset`), over
the list (the page of the launch is transparent and shows only its dialogs and the rocket):

1. "Run <name>?" with the node, the start cost and the least time. The confirmation of the
   payment is never skipped.
2. The wallet: the PIN or the fingerprint if it is locked.
3. The quotes, then the check of the interface of the service, as for any launch.
4. The questions about the variables, filled from the preset (`EnvQuestionsScreen` with
   `initial`). They open on the first variable without a value, or on the review if all
   have one. The review is the one of every launch: the warnings of section 3.2 of
   env-variables.md, and Deny first when a sensitive value can leave the node. A tap on a
   row of the review changes that value.
5. The start, back to the list, and into the conversation. The new instance gets the name of
   the preset.

Cancel at any step closes the page of the launch: the list is as before. A failed launch
shows its sheet, as for any launch.

## 6. Open items

- The least time and "until I stop it" are not kept in the preset: the confirmation asks
  each time (with the last least time that the user chose, as today).
- A preset keeps the service id. A new version of the service is a new id, so the preset
  keeps starting the old one until the user pins an instance of the new one.
- The order of the wheel is the order of the pins. There is no drag to reorder.
