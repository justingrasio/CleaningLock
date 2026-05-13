# Cleaning Lock Development Testing

## Accessibility Permission And Stable App Identity

macOS Accessibility permission is tracked by TCC against the running app identity. Xcode debug builds often run from DerivedData, for example:

```txt
~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/CleaningLock.app
```

After rebuilds, signing or bundle location changes can make System Settings appear enabled while `AXIsProcessTrusted()` still returns `false`.

For a more stable manual test:

1. Build the app in Xcode.
2. In Finder, copy the built `CleaningLock.app` from DerivedData to `/Applications/CleaningLock.app`.
3. Launch `/Applications/CleaningLock.app` directly.
4. Grant Accessibility permission to that `/Applications` copy.
5. Reopen that same `/Applications/CleaningLock.app` for repeated input-lock tests.

During development, the app also has **UI Test Mode**. It runs the countdown and timer without installing the event tap. Real input locking still requires `AXIsProcessTrusted() == true`.
