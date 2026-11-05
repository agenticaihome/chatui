# Environment variables of a service (2026-10-22)

Josemi asked for two things: a container of environment variables in the app, and a
question to the user, one variable at a time, when a service that declares variables is
launched. This note is the design, and the code follows it (section 5 has the files). It
follows [ui.md](ui.md) (section "Run a service") and [package.md](package.md).

## 1. What the protocol gives

- A service declares its variables in `Service.Container.environment_variables`: a list of
  name and `DataFormat` (tags, prose, formal). The proto says that senders do not set it
  yet, so a service in the wild may use variables and not declare them. Then the app has
  nothing to ask, and the launch is as it is today (the open item in section 7).
- The caller gives values in `Configuration.environment_variables`: name and bytes. A
  variable that is not in the list is absent for the service. The node gives a variable to
  the process only if its name is a C identifier and its value has no NUL byte.
  `__nodo_instance_name` is reserved: the node removes it and uses its value as the name of
  the instance.
- A network domain of the service can have `${NAME}` as a value. If `NAME` is absent, the
  node does not resolve that domain at the start (the instance can ask for it later). So
  skipping a variable is valid, and it can have an effect that the user does not see.

`configuration()` (`celaut_service.rs`) fills only `initial_mu`, and a quote uses only it.
`start_configuration()` adds the variables, and only a start calls it.

## 2. The container

A list of named values that the user keeps in the app and uses in any launch.

- **Entry:** `name`, `value` (UTF-8 text), time of the last change. Names are unique, and
  follow the rule of the node: a C identifier (`[A-Za-z_][A-Za-z0-9_]*`), not
  `__nodo_instance_name`. A value has no NUL byte. Limits: 256 entries, 8 KiB for a value.
- **Where:** in the Celaut database, a new list `env_variables` in `CelautData`
  (`rust/crates/celaut-client/src/db.rs`), with `#[serde(default)]` so that a database of
  an earlier version opens with an empty list (the same test as for `packages`). The
  database is encrypted with the key of the Keystore, so a value is as safe as an instance
  token. There is no other copy, and no value goes to a log, an event, or the text of an
  error.
- **Screen:** Settings, Compute section, "Environment variables" (`EnvVariablesScreen`). It
  lists the names with dots in place of the values. Add, edit (the eye in the form shows the
  value), delete (with a confirmation). A name that exists cannot be added twice: the form
  says so, and the row is the way to edit it. The screen checks the rules of a name and a
  value (`env_store.dart`) before it calls Rust, so each reason has its own text.
- **Rust API** (`wallet-ffi/src/api/celaut_env.rs`):

| Function | What it does |
|---|---|
| `celaut_env_names()` | The names and times, never the values |
| `celaut_env_get(name)` | One value, for the eye and for the edit form |
| `celaut_env_set(name, value)` | Adds or replaces; refuses a bad name or value, with the reason |
| `celaut_env_delete(name)` | Removes one |

## 3. The question at a launch

The question exists only if the declaration has at least one variable. For each variable,
in the order of the declaration, a page shows "Variable 2 of 3":

- the name, and the prose of its format (the tags if there is no prose);
- three choices:
  1. **Choose from my variables.** A list of the container. The entries with the same name
     as the variable come first, but any entry can be chosen. The values are not shown.
     With an empty container the list says where to add variables (Settings, Environment variables).
  2. **Type a value.** A text field for UTF-8 text. An empty text is not accepted: the user
     skips the variable instead, because "absent" and "empty" are different for a service.
  3. **Skip.** The variable is not in the configuration.
- Back goes to the earlier variable. Cancel on any page ends the launch, with nothing sent.

The last page lists each variable and where its value comes from ("my variable DB_PASSWORD",
"typed", "skipped"), never the value, with **Run** and Back. The page says that the node
that starts the service reads the values.

The formats are shown, not checked: the app cannot read a `formal` that it does not know,
so any choice is accepted if the value is valid text for the node. A declaration for binary
data cannot be filled. The user can skip it.

Typed values are not saved, unless the user says so. A switch "Save in my variables" with a
name saves the value in the container (decided 2026-11-01, as for the chat: the switch "Sensitive"
of the question becomes the sensitive mark of the new entry). The same question appears in the
chat for a service that asks for a secret (`chat.md`, section 5.6).

### 3.1 Where a service can send what it is given (2026-10-26)

A value that the user gives is read by the node, and by the service. If the service declares
networks, it can send the value to the peers of those networks. The app cannot see what a
service does with a value, but it knows where the service may connect, from `Service.network`
(`app/lib/celaut/egress.dart`, `egressOf`; the first version is from PR #50). The rule of a tag
is the rule of the node (nodo `network_policy.direct_egress_reason`):

| Tag | Where the traffic goes | Kind |
|---|---|---|
| `*` | Every address | Egress |
| `pow:` and a chain (`pow:ergo`) | The peers of that chain | Egress |
| Lower case, with a dot (`api.example.com`) | That host | Egress |
| Any other tag (`postgres`) | The instances on the same node that answer it | On the node |

The tags of one network are names of one domain: a network with one tag of egress is egress.
A node operator can also give a tag addresses of its own (seeds); the app cannot see that, so
such a tag shows as "on the node".

A variable that a network parameter takes by `${NAME}` (section 1) shows one more line on its
question: "This variable sets where the service connects", because its value chooses the
destination.

### 3.2 Sensitive values, trusted nodes and the review (2026-10-26)

Josemi asked for three things (his notes "advertencias sobre variables de entorno"):

1. Warn before environment variables (possible credentials) go to a service that exposes them
   to networks, and name the networks. For egress the warning is larger and red, and **Deny**
   is the default.
2. Warn when the variables go to a node that is not fully trusted. The user marks the nodes
   that are fully trusted (own, family, friends, company).
3. The user marks which variables are sensitive. A variable that is not sensitive is not a
   credential, and **none** of these warnings applies to it.

**Sensitive.** Each variable of the container has a mark (`EnvRecord.sensitive`):

- A new variable of the container is sensitive. The form (Settings, Compute, Environment
  variables) has a switch, and the lock of each row changes the mark. A variable of an earlier
  version is sensitive: the user saved it to keep it.
- A typed value is not sensitive. Its question has a switch "Sensitive", off.
- Choice to review: the container is the place for the secrets that the user keeps, so a
  value from it is sensitive unless the user says no. A typed value is often a mode or a name
  (`MODE=fast`), so it warns only if the user says yes. The opposite default for typed values
  is one line in `_EnvQuestionsScreenState`.

**Trusted.** Each node has a mark (`NodeRecord.trusted`, `celaut_set_node_trusted`), off for a
new node and for a node of an earlier version. The switch "Fully trusted" is on the card of
the node, in Compute, Nodes. A removed node keeps its mark.

**Which nodes read the values.** The values go only with a start request (section 4), but
every node that gets one reads them, also if it refuses the start. So the nodes are all the
nodes of the quotes that `launchService` can ask to start, best first: not the ones where the
credit is less than the price (`envTargetNodes`, `wouldAskToStart`).

**The review.** If at least one given value is sensitive, the review page (section 3) shows
one card, with one part for each condition that applies:

| Condition | Part | Colour | Buttons |
|---|---|---|---|
| A network of egress | "Your sensitive values can leave the node", with the exits (`any address` for `*`) | Red card | **Deny** (filled, focused) cancels the launch; "Send the values and run" (red text) |
| A network on the node | "The service shares networks on the node", with the networks | Text colour, grey border | Run |
| A node that can start the service and is not trusted | "Nodes that you do not fully trust", with their addresses | Text colour, grey border | Run |

Only egress is red: the accent of the Celaut palettes is close to red, so the other parts use the colour of the text. The parts are on one page: there is no chain of dialogs. With egress, the other parts are red
too, and the buttons are the ones of egress. Deny sends nothing: the launch ends as Cancel
does. With no sensitive value, the review is as before, with no card. Each row of the review
says "Sensitive" after the source of a sensitive value.

What this does not do: it does not stop the user, it does not know what a host or a node does
with a value, and it does not read the networks of a service that does not declare them. A
service may also give a value to a workload that it starts. The warning is a place to stop and
think, not a guarantee.

## 4. Order in the launch, and who sees the values

A quote asks every node. A value must not go to nodes that only price the service. So:

1. The quote goes with `initial_mu` only, as now. The price does not depend on the values
   (the node charges a balance, not a variable).
2. **The service is read.** From the loaded file if the service is in the library; if not,
   with `GetService` from the best node of the quotes (`GetService` needs a client id, which
   the app has for a node that quoted). New call: `celaut_service_info(service_id, node)`,
   which gives what the service says about itself, the declared variables among it (name,
   tags and prose). No declaration means no question and no change to the flow. The same read
   checks the interface of the service for the chat convention
   ([service-info.md](service-info.md)).

   The declaration is after the filesystem of the container in the Service, and the
   filesystem can be hundreds of megabytes (`claude-code.bee` has 536 MB), so the Service is
   not decoded as a message. `celaut-client/src/service_info.rs` walks its protobuf fields as
   a stream and skips the filesystem; [service-info.md](service-info.md) says how. From a node
   the app asks the node to skip the block of the filesystem, so the read is small; a node that
   does not skip is stopped after 128 MiB, and the service counts as one that cannot be read: the app asks
   the user to run it anyway or to cancel. A service that the user loaded as a file is always
   read from the file.
3. The questions of section 3.
4. `launchService` starts the service on the nodes in order, and **only a start request
   carries the values**. A node that refuses the start has read them. That is the same
   trust as the node that runs the service, and the final page says it.

`launchService` and `celaut_start_service` take a new `environment`, a list of choices:
`{name, container: String?, text: String?}`. Rust resolves a choice of the container, so
the values of the container do not go through Dart. `configuration()` takes the resolved
pairs, as `BytesKeyValue` entries with the bytes of the text, and leaves the list empty when
there are none, so a service with no variables sends the same message as today.

The app does not keep the values after the start: the instance record has no environment.
The node holds them in the file `/__config__` of the instance (`ConfigurationFile`).

## 5. Where the code goes

| Change | File |
|---|---|
| `EnvRecord`, `CelautData.env_variables`, `set_env` | `rust/crates/celaut-client/src/db.rs` |
| Name and value rules (used by set and by start) | `rust/crates/celaut-client/src/env.rs` |
| Read `Container.environment_variables` as a stream | `rust/crates/celaut-client/src/service_info.rs` |
| `celaut_env_*`, `EnvChoice` | `rust/crates/wallet-ffi/src/api/celaut_env.rs` |
| `celaut_service_info` (the declaration is a part of it) | `rust/crates/wallet-ffi/src/api/celaut_service_info.rs` |
| `start_configuration`, the `environment` of `celaut_start_service` | `rust/crates/wallet-ffi/src/api/celaut_service.rs` |
| The question between quote and start (`EnvironmentStep`, `LaunchCancelled`) | `app/lib/celaut/launcher.dart`, `app/lib/ui/celaut/run_service_section.dart` |
| The container (`EnvStore`, the rules of a name and a value) | `app/lib/celaut/env_store.dart` |
| `EnvVariablesScreen`, `EnvQuestionsScreen` | `app/lib/ui/celaut/env_variables_screen.dart`, `env_questions_screen.dart` |
| The exits of a service (`egressOf`), the nodes that read the values (`envTargetNodes`), the warnings (`EnvWarnings`) | `app/lib/celaut/egress.dart` |
| `EnvRecord.sensitive`, `NodeRecord.trusted` | `rust/crates/celaut-client/src/db.rs` |
| `celaut_env_set(name, value, sensitive)`, `celaut_env_set_sensitive` | `rust/crates/wallet-ffi/src/api/celaut_env.rs` |
| `KnownNodeView.trusted`, `celaut_set_node_trusted`; the switch on the node card | `rust/crates/wallet-ffi/src/api/celaut_home.rs`, `app/lib/ui/celaut/known_nodes_screen.dart` |
| The switch "Save in my variables" of a typed value (`EnvTyped.save`), and the questions for one secret of the chat (`EnvQuestionsPurpose.chat`) | `app/lib/ui/celaut/env_questions_screen.dart` |
| Strings in English and Spanish | `app/lib/l10n/app_en.arb`, `app_es.arb` (`celautEnv*`) |

A launch from the screen "Celaut service" of the Compute section has no question: it starts
with no variables, as before.

## 6. Checks

The checks are in `celaut-client` (`env.rs`, `db.rs`, `service_info.rs`), `wallet-ffi`
(`celaut_env.rs`, `celaut_service.rs`) and `app/test` (`celaut_env_test.dart`,
`celaut_launcher_test.dart`, `celaut_run_section_test.dart`):

- Names: `1A`, `A-B`, a name with a space, `__nodo_instance_name`, an empty name; a value
  with NUL; the limits of entries and size.
- An old database has an empty container; a new one keeps it after a restart; the file with
  the values is unreadable without the key (the existing test, with an entry).
- `configuration(None, [])` equals `Configuration::default()`; with choices, the pairs are in
  the order of the declaration; a skipped variable is absent, not empty.
- A quote request never has `environment_variables`; only a start request has them.
- Cancel on a question sends no request. The values are not in an error message or a log.
- Section 3.2: an old variable is sensitive and an old node is not trusted; a value that is not
  sensitive gives no warning, also with egress and an untrusted node; egress is a red card and
  Deny is the filled, focused button and gives null; a network on the node is a normal
  warning that names it; a trusted node gets no node warning; all the conditions are one page
  (`celaut_egress_test.dart`, `celaut_env_test.dart`, `celaut_known_nodes_test.dart`,
  `celaut_run_section_test.dart`).
- The declaration is read after a filesystem of 300 000 bytes, with chunks of 1 byte to 1 MiB
  and a block marker in the middle; a cut service, a false length and a group wire type are
  errors, not panics. `CELAUT_TEST_BEE=<file> cargo test -p celaut-client --lib real_package --
  --ignored --nocapture` reads a real package.

## 7. Open items

- Sharing a variable by QR code: [env-share.md](env-share.md).

- **Declarations are rare today.** The proto says that senders do not set
  `Container.environment_variables` yet, so a service in the wild does not declare variables
  and the questions do not appear. `claude-code.bee` is one of them. An alternative is a free
  list: the user adds NAME=value for any service from the launch page. Josemi decides if it is
  wanted before the services declare their variables.
- Do the eye and the edit of a value need the unlock of the wallet (`wallet_unlock.dart`)?
  The code says no, as the database is encrypted already.
- Save a typed value into the container from the question (section 3). Decided 2026-11-01,
  built in 0.1.30 (`EnvTyped.save`, the switch `env-typed-save`).
- Section 3.2, for Josemi: the defaults (container sensitive, typed not); Deny ends the launch
  (an alternative: Deny goes back to the questions, so the user can skip the value); a tag with
  operator seeds shows as "on the node"; "Run only on trusted nodes" for a launch with
  sensitive values is not built.
- A service of more than 128 MiB that is on a node that does not skip blocks, and not in the library, cannot be read for
  its declaration. The user can load the file, or run with no variables.
