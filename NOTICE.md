# Licence

Celaut is free software under the **GNU General Public License, version 3 only**
(`GPL-3.0-only`). The full text is in `LICENSE`.

The reason is `bee-rpc` (https://github.com/bee-rpc-protocol/bee-rpc-over-grpc-rs),
which the app links into `libwallet_ffi.so` and which is `GPL-3.0-only`. A program that
links it has to be offered under the GPL.

## Argus (MIT)

Celaut is a fork of the Argus Ergo wallet (https://github.com/arkadianet/Argus), with
its history kept. Argus declares the MIT licence (`license = "MIT"` in its Cargo
manifest, authors "arkadianet"). The code that comes from Argus stays available under
the MIT terms below. The MIT licence is compatible with the GPL, and the combined work
is distributed under the GPL.

> Permission is hereby granted, free of charge, to any person obtaining a copy of this
> software and associated documentation files (the "Software"), to deal in the Software
> without restriction, including without limitation the rights to use, copy, modify,
> merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to the following
> conditions:
>
> The above copyright notice and this permission notice shall be included in all copies
> or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
> INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
> PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
> HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
> CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
> OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The upstream repository has no `LICENSE` file, so there is no copyright line to copy.
The notice above is the MIT text that applies to the Argus code, from its authors
(arkadianet and the contributors of Argus).

## Other parts

- The fonts Playfair Display and Lato are under the SIL Open Font License 1.1. Their
  licence files are in `app/assets/fonts/`.
- Each Rust and Dart dependency keeps its own licence. See `docs/dependency-list.md`.
