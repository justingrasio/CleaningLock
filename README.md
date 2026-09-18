# CleaningLock

[![Build](https://github.com/justingrasio/CleaningLock/actions/workflows/build.yml/badge.svg)](https://github.com/justingrasio/CleaningLock/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/justingrasio/CleaningLock)](https://github.com/justingrasio/CleaningLock/releases/latest)

CleaningLock is a small native macOS SwiftUI app that temporarily blocks normal keyboard, mouse, and trackpad input so you can clean your Mac safely.

It is a physical cleaning-mode utility. It is not a storage cleaner and does not scan, upload, move, delete, or modify user files.

## What It Does

- Checks for macOS Accessibility permission
- Starts cleaning mode after a short countdown
- Blocks normal keyboard input
- Blocks mouse and trackpad clicks, scrolling, dragging, and pointer movement where macOS allows
- Automatically unlocks when the timer ends
- Unlocks early when both Command keys are held together

Some macOS system-level gestures, such as Mission Control or desktop switching, may still respond because macOS can handle them outside the app's event tap.

## Download and Install

CleaningLock requires **macOS 14 Sonoma or later**.

1. Open the [latest release](https://github.com/justingrasio/CleaningLock/releases/latest).
2. Download `CleaningLock-macOS.zip` under **Assets**.
3. Open the ZIP and drag `CleaningLock.app` into your Applications folder.
4. Control-click the app, choose **Open**, then confirm **Open**.
5. When prompted, allow CleaningLock in **System Settings > Privacy & Security > Accessibility**.

The app is not currently notarized, so opening it by double-clicking may show an unidentified-developer warning. The Control-click procedure above lets you explicitly approve it. If macOS still blocks it, open **System Settings > Privacy & Security**, scroll to the security message, and click **Open Anyway**.

## Security and Privacy

CleaningLock is open source and currently not notarized by Apple.

macOS may warn that the app cannot be verified when you download a prebuilt copy. This does not mean the app is malware, but it does mean Apple has not checked this downloaded build.

CleaningLock needs Accessibility permission only to temporarily block keyboard, mouse, and trackpad input during cleaning mode.

The app does not use the network or access your files. If you do not trust a downloaded build, inspect the source and build it yourself in Xcode.

## Build From Source

1. Install Xcode from the Mac App Store.
2. Clone this repository.
3. Open `CleaningLock.xcodeproj` in Xcode 16 or later.
4. Select the `CleaningLock` scheme.
5. Build and run the app.

For stable Accessibility testing, copy the built `CleaningLock.app` to `/Applications/CleaningLock.app`, then grant Accessibility permission to that `/Applications` copy.

See `DEVELOPMENT_TESTING.md` for more details.

## Permissions

CleaningLock requires Accessibility permission because macOS only allows apps with that permission to monitor and suppress global input events.

The app uses this permission for cleaning mode only.

## License

MIT
