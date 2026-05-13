# Implementation Prompt: Cleaning Lock macOS App

You are working in the actual project Codex chat for a native macOS app.

Read and follow `PRD.md` as the source of truth before implementing. If `BRAIN.md` is present, use it for collaboration and explanation style, but treat `PRD.md` as the product requirements.

## Goal

Build a native macOS SwiftUI app called **Cleaning Lock**.

The app temporarily blocks keyboard, mouse, and trackpad input so the user can physically clean their Mac without shutting it down.

The app must feel safe, simple, and native to macOS.

## Product Scope

Implement v1 only.

Core behavior:

- user opens the app
- app checks Accessibility permission
- app refuses to start lock mode without permission
- user clicks Start Cleaning Mode
- app shows a 3-second pre-lock countdown
- app starts cleaning mode
- keyboard, mouse, trackpad movement, clicks, drags, and scroll are blocked
- app shows a 3-minute countdown timer
- app automatically unlocks after 3 minutes
- app unlocks early when both Command keys are held together for 3 seconds
- app stops blocking input on quit, error, or event tap failure

## Non-Goals

Do not implement:

- file cleanup
- storage scanning
- duplicate detection
- cache cleaning
- app uninstaller features
- backend services
- cloud sync
- user accounts
- analytics
- menu bar-only mode
- login item behavior
- auto-start at login
- complex settings
- custom themes
- destructive file actions

Do not delete, move, scan, or modify user files.

## Recommended Stack

Use:

- Swift
- SwiftUI
- native macOS APIs
- Accessibility permission checks
- CoreGraphics / Quartz event tap APIs for input interception

Do not use Electron, React, Tauri, or a backend unless the existing project already clearly requires a different approach.

## UI Direction

Create a simple one-window macOS utility UI inspired by macOS System Settings.

Use native SwiftUI styling and macOS material/glass effects where appropriate.

Design priorities:

1. safety
2. clarity
3. native macOS feel
4. simple polish
5. decoration last

Required UI states:

- permission needed
- ready
- pre-lock countdown
- cleaning active
- error

Ready state should show:

- app name
- short explanation
- duration: 3 minutes
- early unlock instruction: hold both Command keys for 3 seconds
- Start Cleaning Mode button

Active state should show:

- Cleaning Mode Active
- large remaining countdown timer
- early unlock instruction
- calm, minimal visual styling

Permission state should show:

- why Accessibility permission is needed
- Open System Settings action
- Check Again action

## Suggested Architecture

Prefer a small, clear architecture:

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

- rendering current app state
- showing buttons
- showing permission UI
- showing countdown/timer text

Do not put low-level event tap logic directly in the view.

### CleaningLockViewModel

Responsible for:

- permission state
- app state transitions
- 3-second pre-lock countdown
- 3-minute active countdown
- calling `InputLockService`
- responding to early unlock callbacks
- responding to lock failures

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

- checking/requesting Accessibility permission where appropriate
- creating the global event tap
- blocking keyboard events
- blocking mouse events
- blocking trackpad-related events
- detecting both Command keys
- notifying the ViewModel when both Command keys are held for 3 seconds
- stopping/removing the event tap safely
- handling event tap disabled/failure cases

The event callback must remain lightweight and defensive.

## Input Locking Requirements

Use a global event tap capable of suppressing relevant input events.

During active cleaning mode, block:

- normal keyboard input
- mouse clicks
- trackpad clicks
- mouse movement where possible
- trackpad movement where possible
- scroll events
- drag events

While blocking input, still inspect modifier-key events so the app can detect early unlock.

Early unlock rule:

```txt
If both Command keys are held together for 3 seconds, stop cleaning mode.
If either Command key is released before 3 seconds, reset the hold timer.
```

Important:

- inspect Command-key state before suppressing the event
- do not allow Command-key events to trigger normal system behavior during cleaning mode
- do not rely only on the manual unlock gesture because the 3-minute timer must always exist

## Safety Requirements

The app must fail open, not fail locked.

Implement these safety behaviors:

- never start input blocking without explicit user action
- never start input blocking without Accessibility permission
- always auto-unlock after 3 minutes
- release the event tap when cleaning mode ends
- release/disable event tap when the app quits
- handle event tap creation failure by returning to a safe ready/error state
- handle event tap disabled by macOS by stopping cleaning mode
- make `startLock()` idempotent
- make `stopLock()` idempotent
- avoid duplicate event taps
- avoid heavy work inside the event callback

Do not claim that power button, Touch ID, or every hardware/system-level shortcut can be blocked.

## Implementation Order

Work in this order:

1. Inspect the existing project structure.
2. Identify whether this is already a SwiftUI macOS project.
3. If no app exists yet, create the minimal native macOS SwiftUI app structure appropriate for the workspace.
4. Build the one-window UI and app states first, without input blocking.
5. Add the 3-second pre-lock countdown.
6. Add the 3-minute active countdown.
7. Add Accessibility permission detection and permission UI.
8. Add Open System Settings and Check Again actions.
9. Implement both-Command key detection before fully blocking keyboard input.
10. Add the event tap service.
11. Block mouse/trackpad events first.
12. Add normal keyboard blocking while preserving both-Command unlock detection.
13. Add automatic unlock after 3 minutes.
14. Add cleanup on quit/error/event tap failure.
15. Run available builds/tests/checks.
16. Manually summarize verification status and any limitations.

## Verification Steps

Verify as much as possible locally.

At minimum, check:

- app builds successfully
- app launches successfully if launch is possible
- UI shows permission-needed state when Accessibility permission is missing
- Start Cleaning Mode cannot start without permission
- Open System Settings action is wired
- Check Again action is wired
- Start Cleaning Mode begins a 3-second countdown
- active state shows 3-minute countdown
- app returns to ready state after timer ends
- both-Command early unlock logic is implemented
- event tap is stopped when cleaning mode ends
- event tap cleanup is called on app quit
- event tap creation failure returns to safe state
- no file cleanup or destructive behavior exists

If a behavior requires manual macOS permission testing and cannot be fully verified automatically, say that clearly.

## Final Response Requirements

After implementation, provide:

- concise summary of what changed
- files changed
- how to run the app
- what was verified
- what still needs manual testing
- any known macOS permission limitations
- a beginner-friendly explanation of how the app works
- a git diff summary request/result if available

Keep the explanation beginner-friendly but technically honest.

## Important Product Reminder

This is not a disk cleanup app.

This is a physical cleaning-mode utility:

```txt
temporarily block input
show clear timer
unlock automatically
allow both-Command early unlock
stay safe
```

Prioritize safety and reliability over extra features.
