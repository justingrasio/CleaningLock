# PRD: Cleaning Lock macOS App

## 1. Product Summary

Cleaning Lock is a native macOS utility app that temporarily blocks normal keyboard, mouse, and trackpad input so the user can physically clean their Mac without shutting it down.

The app is designed for a simple use case:

> "I want to clean my Mac keyboard, trackpad, or mouse area without accidentally typing, clicking, dragging, or triggering shortcuts."

This app is not a storage cleaner or file cleanup tool. It does not delete, move, scan, or modify user files.

## 2. Problem Statement

Mac users often need to clean their keyboard, trackpad, or mouse while the computer is still on.

Without a cleaning mode, touching the device may accidentally:

- type text
- click buttons
- drag windows
- trigger shortcuts
- scroll pages
- open apps
- modify work unintentionally

The common workaround is shutting down or locking the Mac, but this is inconvenient.

Cleaning Lock solves this by temporarily suppressing accidental input while keeping the Mac awake and visible.

## 3. Target User

### Primary User

A Mac user who wants to clean their keyboard, trackpad, mouse, or palm rest area without shutting down the Mac.

### User Skill Level

The app should be understandable by general macOS users, including non-technical users.

The user should not need to understand system APIs, permissions, event taps, or development concepts.

## 4. Product Goals

The app should:

- provide a simple cleaning mode
- temporarily block keyboard input
- temporarily block normal mouse and trackpad input where macOS allows
- automatically unlock after 3 minutes
- allow early unlock by holding both Command keys for 3 seconds
- use a simple native macOS-style interface
- clearly explain what will happen before locking input
- feel safe, calm, and trustworthy

## 5. Non-Goals

For v1, the app should not include:

- file cleanup
- storage scanning
- duplicate file detection
- cache cleaning
- app uninstaller features
- backend services
- cloud sync
- user accounts
- analytics
- menu bar-only mode
- login item behavior
- automatic launch at startup
- complex onboarding
- advanced settings
- custom themes
- destructive file actions

The app should not promise that every hardware-level button or system-level shortcut can be blocked.

## 6. Core User Flow

1. User opens the app.
2. App checks whether Accessibility permission is granted.
3. If permission is missing, app shows a permission-needed screen.
4. User can open macOS System Settings from the app.
5. User grants Accessibility permission.
6. User returns to the app and checks permission again.
7. App shows the ready state.
8. User clicks "Start Cleaning Mode."
9. App shows a 3-second countdown before locking.
10. Cleaning mode starts.
11. App blocks normal keyboard, mouse, and trackpad input where macOS allows.
12. App shows a 3-minute countdown.
13. User may unlock early by holding both Command keys for 3 seconds.
14. If the user does nothing, the app automatically unlocks after 3 minutes.
15. App stops blocking input.
16. App returns to the ready state.

## 7. Functional Requirements

### App Foundation

**FR1.** The app must be built as a native macOS app.

**FR2.** The recommended implementation stack is Swift + SwiftUI.

**FR3.** The app should have one main window for v1.

**FR4.** The app should not require a backend or network access.

### Accessibility Permission

**FR5.** The app must check whether macOS Accessibility permission is granted.

**FR6.** The app must not start cleaning mode if Accessibility permission is missing.

**FR7.** The app must show a clear permission-needed state when permission is missing.

**FR8.** The app should provide an action to open the relevant macOS System Settings permission page.

**FR9.** The app should provide a "Check Again" action after the user grants permission.

### Cleaning Mode Start

**FR10.** The app must start cleaning mode only after explicit user action.

**FR11.** The app must show a 3-second countdown before input locking begins.

**FR12.** The countdown should clearly tell the user that cleaning mode is about to start.

**FR13.** The countdown should remind the user that input unlocks automatically after 3 minutes.

**FR14.** The countdown should remind the user that holding both Command keys for 3 seconds unlocks early.

### Input Blocking

**FR15.** During cleaning mode, the app must block normal keyboard input.

**FR16.** During cleaning mode, the app must block mouse clicks.

**FR17.** During cleaning mode, the app must block trackpad clicks.

**FR18.** During cleaning mode, the app must block mouse and trackpad movement where possible.

**FR19.** During cleaning mode, the app must block scroll events.

**FR20.** During cleaning mode, the app must block drag events.

**FR21.** The app should use a macOS global event tap to intercept and suppress input events.

**FR22.** The event handler must remain lightweight and defensive.

**FR22a.** The app should not claim to reliably block macOS system-level trackpad gestures such as Mission Control, App Exposé, Launchpad, or desktop switching if those gestures are handled outside the app's CGEvent tap.

### Automatic Unlock

**FR23.** Cleaning mode must automatically unlock after 3 minutes.

**FR24.** The 3-minute timer starts when input blocking begins, not when the pre-lock countdown begins.

**FR25.** When the timer ends, the app must stop blocking input.

**FR26.** After automatic unlock, the app must return to the ready state.

### Early Unlock

**FR27.** During cleaning mode, the app must continue detecting modifier-key state.

**FR28.** The app must unlock early when both Command keys are held together for 3 seconds.

**FR29.** The app should reset the early-unlock hold timer if either Command key is released.

**FR30.** The app should inspect Command-key state before suppressing the event.

**FR31.** Command-key events should not trigger normal system behavior while cleaning mode is active.

### Stop And Cleanup

**FR32.** The app must stop blocking input when cleaning mode ends.

**FR33.** The app must remove or disable the event tap when cleaning mode ends.

**FR34.** The app must stop blocking input if the app quits.

**FR35.** The app must return to a safe ready state if event tap creation fails.

**FR36.** The app must return to a safe ready state if the event tap is disabled by macOS.

**FR37.** Calling start or stop multiple times should not create duplicate event taps or invalid state.

## 8. UI Requirements

### UI Direction

The UI should be simple, native-feeling, and inspired by macOS Settings.

The app should use a subtle glass or material effect where appropriate.

The design should prioritize:

1. safety
2. clarity
3. native macOS feel
4. simple visual polish
5. decoration last

The app does not need a complex or highly custom design.

### Required UI States

The app should support these states:

- permission needed
- ready
- pre-lock countdown
- cleaning active
- finished / ready again
- error state if input locking fails

### Permission Needed State

The permission screen should communicate:

- Accessibility permission is required.
- The app uses this permission only to temporarily block input during cleaning mode.
- Cleaning mode cannot start until permission is granted.

Required actions:

- Open System Settings
- Check Again

### Ready State

The ready state should show:

- app name
- short description
- cleaning duration: 3 minutes
- early unlock instruction
- Start Cleaning Mode button

Suggested copy:

```txt
Cleaning Lock

Temporarily disables keyboard, mouse, and trackpad input so you can clean your Mac safely.

Duration: 3 minutes
Early unlock: hold both Command keys for 3 seconds

[Start Cleaning Mode]
```

### Countdown State

The countdown state should show:

- large countdown number
- warning that cleaning mode is about to start
- unlock reminder

Suggested copy:

```txt
Cleaning mode starts in 3...

Input will be temporarily locked.
Hold both Command keys for 3 seconds to unlock early.
```

### Active State

The active state should show:

- Cleaning Mode Active
- remaining time
- early unlock instruction
- calm visual styling

Suggested copy:

```txt
Cleaning Mode Active

02:47

Hold both Command keys for 3 seconds to unlock early.
Input unlocks automatically when the timer ends.
```

### Error State

If the app cannot start lock mode, it should show:

```txt
Cleaning mode could not start.

Please check Accessibility permission and try again.
```

The app should remain usable and should not partially lock input.

## 9. Safety Requirements

**SR1.** The app must never delete, move, scan, or modify user files.

**SR2.** The app must never start input blocking without explicit user action.

**SR3.** The app must never start input blocking without Accessibility permission.

**SR4.** The app must never depend only on a manual unlock gesture.

**SR5.** The app must always auto-unlock after 3 minutes.

**SR6.** The app must release the input lock when cleaning mode ends.

**SR7.** The app must release the input lock when the app quits.

**SR8.** The app must fail open, not fail locked.

**SR9.** If event tap setup fails, the app must return to an unlocked state.

**SR10.** If the event tap is disabled by macOS, the app must stop cleaning mode and return to a safe state.

**SR11.** The app should not claim to block hardware-level buttons such as the power button or Touch ID.

## 10. Negative Cases And Expected Handling

| Negative Case | Expected Handling |
|---|---|
| Accessibility permission is missing | Show permission UI and refuse to start cleaning mode |
| Permission is revoked while app is open | Stop/refuse cleaning mode and show permission UI |
| User starts cleaning mode accidentally | 3-second countdown gives a chance to prepare |
| User forgets unlock gesture | 3-minute timer unlocks automatically |
| Both Command unlock is not detected | 3-minute timer unlocks automatically |
| User has external keyboard with unusual Command keys | 3-minute timer unlocks automatically |
| App cannot distinguish left/right Command | Automatic timer still prevents permanent lock |
| Event tap creation fails | Show error and return to ready state |
| Event tap is disabled by macOS | Stop cleaning mode and return to safe state |
| App quits during cleaning mode | Stop input blocking before termination |
| App crashes during cleaning mode | Event tap should be removed by process termination; app should also use cleanup handlers where possible |
| Start is called multiple times | Do not create duplicate event taps |
| Stop is called multiple times | Stop safely without errors |
| User presses both Command keys accidentally while cleaning | Unlock early, which is safe |
| Some system-level shortcuts or multi-finger trackpad gestures still work | Accept limitation and do not promise complete hardware or system gesture lock |
| Mission Control / App Exposé gestures still work | Document as a macOS limitation if the gesture is not exposed through CGEventTap |
| Power button / Touch ID cannot be blocked | Accept limitation and do not claim support |

## 11. Technical Architecture

Recommended v1 architecture:

```txt
CleaningLockApp
  ↓
ContentView
  ↓
CleaningLockViewModel
  ↓
InputLockService
  ↓
macOS Accessibility + CGEventTap APIs
```

### ContentView

Responsible for:

- displaying app state
- showing buttons
- showing permission UI
- showing countdown/timer text

ContentView should not directly manage low-level input locking.

### CleaningLockViewModel

Responsible for:

- app state
- permission state
- countdown before lock
- 3-minute active timer
- state transitions
- calling InputLockService

Suggested states:

```txt
permissionNeeded
ready
arming
active
error
```

### InputLockService

Responsible for:

- creating the global event tap
- blocking keyboard events
- blocking mouse events
- blocking trackpad-related events
- detecting both Command keys
- notifying the ViewModel when early unlock is triggered
- stopping/removing the event tap safely

The event callback should be small and should not contain UI logic.

## 12. Suggested Implementation Order

1. Create the native SwiftUI macOS app.
2. Build the simple one-window UI.
3. Add app states without any input blocking.
4. Add the 3-second pre-lock countdown.
5. Add the 3-minute active timer.
6. Add Accessibility permission detection.
7. Add permission-needed UI.
8. Add an action to open System Settings.
9. Implement both-Command key detection.
10. Test both-Command detection before blocking all keyboard events.
11. Add event tap creation.
12. Block mouse and trackpad clicks/movement/scroll first.
13. Add normal keyboard blocking.
14. Keep both-Command early unlock working.
15. Add event tap failure handling.
16. Add cleanup on app quit.
17. Manually test all safety cases.

## 13. Verification Checklist

The app should be manually verified with these checks:

- App launches successfully.
- UI appears in a simple macOS-style window.
- Permission-needed state appears when Accessibility permission is missing.
- Open System Settings action works.
- Check Again detects permission after it is granted.
- Start Cleaning Mode is disabled or unavailable without permission.
- Start Cleaning Mode begins a 3-second countdown.
- Cleaning mode starts after countdown.
- Keyboard input is blocked during cleaning mode.
- Mouse clicks are blocked during cleaning mode.
- Trackpad clicks are blocked during cleaning mode.
- Scrolling is blocked during cleaning mode.
- Dragging is blocked during cleaning mode.
- Pointer movement is frozen or pulled back while cleaning mode is active.
- System-level trackpad gestures such as Mission Control or App Exposé are documented as a limitation if macOS does not expose them through the event tap.
- Timer starts at 3 minutes.
- Timer visibly counts down.
- Holding both Command keys for 3 seconds unlocks early.
- Releasing one Command key before 3 seconds resets early unlock.
- App automatically unlocks after 3 minutes.
- App returns to ready state after unlock.
- Closing/quitting app stops input blocking.
- Event tap failure does not leave app in locked state.

## 14. Success Criteria

The v1 app is successful if:

- the user can start cleaning mode intentionally
- normal keyboard, mouse, and trackpad input is blocked during cleaning mode where macOS allows
- the user can clean the Mac without accidental typing/clicking
- the app unlocks automatically after 3 minutes
- the user can unlock early with both Command keys
- the app refuses unsafe operation without permission
- the app never leaves the user stuck
- the UI is simple, clear, and native-feeling

## 15. Future Ideas

Possible future improvements:

- custom cleaning duration
- menu bar mode
- keyboard shortcut to start cleaning mode
- optional sound when lock starts/ends
- optional progress ring
- onboarding screen
- app icon polish
- launch at login option
- localization
- signed/notarized app distribution
- support for alternative emergency unlock gestures
- more detailed permission guidance

These should not be required for v1.

## 16. Implementation Handoff Summary

Build a native macOS SwiftUI app called Cleaning Lock.

The app should temporarily block keyboard, mouse, and trackpad input so the user can clean their Mac without shutting it down.

The app must:

- check Accessibility permission
- refuse to start without permission
- show a simple macOS Settings-style glass/material UI
- start cleaning mode after a 3-second countdown
- block keyboard/mouse/trackpad input during cleaning mode
- show a 3-minute countdown timer
- automatically unlock after 3 minutes
- unlock early when both Command keys are held for 3 seconds
- stop input blocking on quit, error, or event tap failure
- avoid any file cleanup or destructive behavior

The implementation should prioritize safety, simplicity, and reliability over visual complexity.
