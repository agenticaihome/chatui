# superapp
Celaut, an Android application to use Celaut services without intermediaries - Celaut node implementation

## Linux (Ubuntu 24.04 or later)

Each release has a `.deb` for `amd64` and one for `arm64`, with their SHA-256 in `SHA256SUMS`.
Download the file for your computer (`dpkg --print-architecture` says which), check it, and
install it:

```sh
sha256sum --check --ignore-missing SHA256SUMS
sudo apt install ./superapp-<version>-linux-<arch>.deb
```

Then open Celaut from the applications, or run `superapp`. The app does not update itself on
Linux: install the `.deb` of the new release the same way. To remove it: `sudo apt remove superapp`.
See `docs/linux.md` for what is different on Linux and how to build the `.deb`.

## Licence

GPL-3.0-only. See `LICENSE` and `NOTICE.md` (it also keeps the MIT notice of Argus, from which Celaut is forked).
