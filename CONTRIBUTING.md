# Contributing

Thanks for wanting to help. Bug reports, new scenes and fixes are all welcome.

## Getting set up

```bash
brew install xcodegen
xcodegen generate
open Groovey.xcodeproj
```

The Xcode project is generated from `project.yml` and is not committed. If you add or move files, run `xcodegen generate` again.

## Before opening a pull request

- Run the tests: `xcodebuild -project Groovey.xcodeproj -scheme Groovey -derivedDataPath build test`.
- If you changed drawing code, render the scenes with `GROOVEY_SNAPSHOT=<folder>` (see the README) and attach before and after images.
- Check CPU use while a song plays. The scene must not redraw every frame; anything that moves continuously belongs in a Core Animation layer, like the record label.

## Adding a scene

Add a case to `Theme` in `Groovey/Scene/Themes.swift` with its `SceneStyle`, and add the name to both `Localizable.strings` files. A scene that reuses the desk layout only needs colours; a different layout gets its own view, as `MinimalScene` does. If the turntable moves, update `StageLayout.label(theme:in:)` so the spinning label follows it.

## Vendored code

`Vendor/MediaRemoteAdapter` is a copy of [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) at the commit recorded in `UPSTREAM_COMMIT`, minus its self-test client. Please send fixes upstream rather than editing it here.
