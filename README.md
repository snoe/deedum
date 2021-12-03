# deedum

A [Project Gemini](https://gemini.circumlunar.space/) browser.

Should be in app/play stores soon!

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
