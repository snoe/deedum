# deedum

A browser for the gemini protocol.

A [Project Gemini](https://gemini.circumlunar.space/) browser.

Gemini is a new, collaboratively designed internet protocol, which explores the space in between gopher and the web, striving to address (perceived) limitations of one while avoiding the (undeniable) pitfalls of the other.

On android fdroid, play store, builds for ios.

## Project update 2025-07-31

While I still use this version everyday to read geminispace, I understand that there is some bitrot here. Keeping flutter for the project up to date completely sapped my motivation to maintain this project.

Checkout https://github.com/jchaves/deedum who has been active in pushing this code base forward.

## Development

Build should just require installing [flutter](https://flutter.dev/), connecting an android phone over usb (with developer mode turned on):

```
flutter build apk --debug
flutter install
```

I haven't been able to get ios building yet because of xcode / macos version restrictions.


Shoutout to the great client tests here:
gemini://egsam.glv.one (http://github.com/pitr/egsam)

### Test server

It is useful to have a server to test against.
You can run `./server server-files/test.gmi` with pass phrase `test` to spinup a single file `ncat` server (make sure you have it installed).

## Release

You need the signing secrets in the environment (`KEY_JKS`, `KEY_PASSWORD`, `KEY_ALIAS`, `ALIAS_PASSWORD`):

```
source Envfile
./release
```
