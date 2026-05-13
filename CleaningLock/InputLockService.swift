//
//  InputLockService.swift
//  CleaningLock
//
//  Created by Jeremia Justin Grasio on 13/05/26.
//

import Foundation

struct PermissionDiagnostics: Equatable {
    var axIsProcessTrustedResult: Bool
    var bundleIdentifier: String
    var bundlePath: String
}

struct CommandKeyDebugState: Equatable {
    var leftCommandIsDown: Bool = false
    var rightCommandIsDown: Bool = false
}

struct InputLockConfiguration: Equatable {
    var blocksKeyboard: Bool = true
    var blocksPointer: Bool = true
}

protocol InputLockServicing: AnyObject {
    var isAccessibilityPermissionGranted: Bool { get }
    var permissionDiagnostics: PermissionDiagnostics { get }
    var commandKeyDebugState: CommandKeyDebugState { get }
    var onEarlyUnlock: (() -> Void)? { get set }
    var onLockInterrupted: (() -> Void)? { get set }
    var onCommandKeyDebugStateChanged: ((CommandKeyDebugState) -> Void)? { get set }

    @discardableResult
    func requestAccessibilityPermission(prompt: Bool) -> Bool
    func openAccessibilitySettings()
    func startLock(configuration: InputLockConfiguration) throws
    func stopLock()
}

enum InputLockError: LocalizedError {
    case accessibilityPermissionMissing
    case eventTapCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            "Accessibility permission is required before cleaning mode can start."
        case .eventTapCreationFailed:
            "The macOS input lock could not be created."
        }
    }
}

#if os(macOS)
import AppKit
import ApplicationServices

final class InputLockService: InputLockServicing {
    static let shared = InputLockService()

    var onEarlyUnlock: (() -> Void)?
    var onLockInterrupted: (() -> Void)?
    var onCommandKeyDebugStateChanged: ((CommandKeyDebugState) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var leftCommandIsDown = false
    private var rightCommandIsDown = false
    private var lockedCursorPosition: CGPoint?
    private var isWarpingCursor = false
    private var pointerMovementEventCount = 0
    private var lastPointerMovementLogDate = Date.distantPast
    private var gestureEventCounts: [UInt32: Int] = [:]
    private var lastGestureLogDates: [UInt32: Date] = [:]
    private var configuration = InputLockConfiguration()

    var isAccessibilityPermissionGranted: Bool {
        AXIsProcessTrusted()
    }

    var permissionDiagnostics: PermissionDiagnostics {
        PermissionDiagnostics(
            axIsProcessTrustedResult: AXIsProcessTrusted(),
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "Unknown",
            bundlePath: Bundle.main.bundlePath
        )
    }

    var commandKeyDebugState: CommandKeyDebugState {
        CommandKeyDebugState(
            leftCommandIsDown: leftCommandIsDown,
            rightCommandIsDown: rightCommandIsDown
        )
    }

    private init() {}

    @discardableResult
    func requestAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        requestAccessibilityPermission(prompt: true)

        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func startLock(configuration: InputLockConfiguration) throws {
        guard isAccessibilityPermissionGranted else {
            throw InputLockError.accessibilityPermissionMissing
        }

        guard eventTap == nil else {
            return
        }

        self.configuration = configuration
        resetEarlyUnlockHold()
        lockedCursorPosition = configuration.blocksPointer ? CGEvent(source: nil)?.location : nil
        pointerMovementEventCount = 0
        lastPointerMovementLogDate = Date.distantPast
        gestureEventCounts = [:]
        lastGestureLogDates = [:]

        print("[CleaningLock] startLock configuration keyboard=\(configuration.blocksKeyboard) pointer=\(configuration.blocksPointer)")

        if let lockedCursorPosition {
            print("[CleaningLock] pointer lock position captured x=\(Int(lockedCursorPosition.x)) y=\(Int(lockedCursorPosition.y))")
        } else if configuration.blocksPointer {
            print("[CleaningLock] pointer lock position could not be captured")
        } else {
            print("[CleaningLock] pointer lock disabled by user setting")
        }

        let eventMask = Self.lockedInputEventMask(configuration: configuration)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: userInfo
        ) else {
            stopLock()
            throw InputLockError.eventTapCreationFailed
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            stopLock()
            throw InputLockError.eventTapCreationFailed
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopLock() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        lockedCursorPosition = nil
        isWarpingCursor = false
        gestureEventCounts = [:]
        lastGestureLogDates = [:]
        configuration = InputLockConfiguration()
        resetEarlyUnlockHold()
        leftCommandIsDown = false
        rightCommandIsDown = false
        publishCommandKeyDebugState()
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onLockInterrupted?()
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            updateEarlyUnlockState(for: event)
            return nil
        }

        if configuration.blocksPointer, Self.isGestureRelatedEvent(type) {
            logGestureRelatedEvent(type: type, event: event)
        }

        if Self.isPointerMovementEvent(type) {
            if configuration.blocksPointer {
                handlePointerMovementEvent(type: type, event: event)
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        if configuration.blocksPointer, Self.isPointerEvent(type) {
            return nil
        }

        if configuration.blocksKeyboard, Self.isKeyboardEvent(type) {
            return nil
        }

        if configuration.blocksPointer, Self.isGestureRelatedEvent(type) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func updateEarlyUnlockState(for event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let commandFlagIsDown = event.flags.contains(.maskCommand)
        let previousLeftCommandIsDown = leftCommandIsDown
        let previousRightCommandIsDown = rightCommandIsDown

        switch keyCode {
        case 55:
            leftCommandIsDown = commandFlagIsDown
        case 54:
            rightCommandIsDown = commandFlagIsDown
        default:
            break
        }

        if previousLeftCommandIsDown != leftCommandIsDown || previousRightCommandIsDown != rightCommandIsDown {
            print("[CleaningLock] input service flagsChanged keyCode=\(keyCode) left=\(leftCommandIsDown) right=\(rightCommandIsDown)")
        }

        publishCommandKeyDebugState()

        if !previousLeftCommandIsDown || !previousRightCommandIsDown,
           leftCommandIsDown && rightCommandIsDown {
            print("[CleaningLock] input service detected both Command keys down; publishing to ViewModel")
        }
    }

    private func handlePointerMovementEvent(type: CGEventType, event: CGEvent) {
        pointerMovementEventCount += 1

        let now = Date()
        if now.timeIntervalSince(lastPointerMovementLogDate) >= 0.5 {
            lastPointerMovementLogDate = now
            let location = event.location
            print("[CleaningLock] pointer movement event received type=\(Self.eventName(for: type)) count=\(pointerMovementEventCount) x=\(Int(location.x)) y=\(Int(location.y))")
        }

        guard let lockedCursorPosition,
              !isWarpingCursor
        else {
            return
        }

        isWarpingCursor = true
        CGWarpMouseCursorPosition(lockedCursorPosition)
        isWarpingCursor = false
    }

    private func logGestureRelatedEvent(type: CGEventType, event: CGEvent) {
        let rawValue = type.rawValue
        gestureEventCounts[rawValue, default: 0] += 1

        let now = Date()
        let lastLogDate = lastGestureLogDates[rawValue] ?? .distantPast

        guard now.timeIntervalSince(lastLogDate) >= 0.5 else {
            return
        }

        lastGestureLogDates[rawValue] = now
        let location = event.location
        let subType = event.getIntegerValueField(.eventSourceUnixProcessID)

        print("[CleaningLock] gesture/system event received type=\(Self.eventName(for: type)) raw=\(rawValue) count=\(gestureEventCounts[rawValue, default: 0]) x=\(Int(location.x)) y=\(Int(location.y)) sourcePID=\(subType)")
    }

    private func resetEarlyUnlockHold() {
        leftCommandIsDown = false
        rightCommandIsDown = false
    }

    private func publishCommandKeyDebugState() {
        let debugState = commandKeyDebugState
        DispatchQueue.main.async { [weak self] in
            self?.onCommandKeyDebugStateChanged?(debugState)
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<InputLockService>.fromOpaque(userInfo).takeUnretainedValue()
        return service.handleEvent(proxy: proxy, type: type, event: event)
    }

    private static func lockedInputEventMask(configuration: InputLockConfiguration) -> CGEventMask {
        var types: [CGEventType] = [
            .flagsChanged
        ]

        if configuration.blocksPointer {
            types.append(contentsOf: [
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel,
            .tabletPointer,
            .tabletProximity,
            appKitDefinedEventType,
            applicationDefinedEventType,
            systemDefinedEventType,
            rotateEventType,
            beginGestureEventType,
            endGestureEventType,
            gestureEventType,
            magnifyEventType,
            swipeEventType,
            smartMagnifyEventType,
            pressureEventType,
                directTouchEventType,
                changeModeEventType
            ])
        }

        if configuration.blocksKeyboard {
            types.append(contentsOf: [.keyDown, .keyUp, systemDefinedEventType])
        }

        return types.reduce(CGEventMask(0)) { mask, type in
            mask | (1 << CGEventMask(type.rawValue))
        }
    }

    private static func isKeyboardEvent(_ type: CGEventType) -> Bool {
        type == .keyDown || type == .keyUp || type == .flagsChanged || type == systemDefinedEventType
    }

    private static func isPointerEvent(_ type: CGEventType) -> Bool {
        type == .leftMouseDown
            || type == .leftMouseUp
            || type == .rightMouseDown
            || type == .rightMouseUp
            || type == .otherMouseDown
            || type == .otherMouseUp
            || type == .scrollWheel
            || type == .tabletProximity
    }

    private static func isPointerMovementEvent(_ type: CGEventType) -> Bool {
        type == .mouseMoved
            || type == .leftMouseDragged
            || type == .rightMouseDragged
            || type == .otherMouseDragged
            || type == .tabletPointer
    }

    private static func isGestureRelatedEvent(_ type: CGEventType) -> Bool {
        type == .scrollWheel
            || type == .tabletPointer
            || type == .tabletProximity
            || type == appKitDefinedEventType
            || type == systemDefinedEventType
            || type == applicationDefinedEventType
            || type == rotateEventType
            || type == beginGestureEventType
            || type == endGestureEventType
            || type == gestureEventType
            || type == magnifyEventType
            || type == swipeEventType
            || type == smartMagnifyEventType
            || type == pressureEventType
            || type == directTouchEventType
            || type == changeModeEventType
    }

    private static func eventName(for type: CGEventType) -> String {
        switch type {
        case .mouseMoved:
            "mouseMoved"
        case .leftMouseDragged:
            "leftMouseDragged"
        case .rightMouseDragged:
            "rightMouseDragged"
        case .otherMouseDragged:
            "otherMouseDragged"
        case .tabletPointer:
            "tabletPointer"
        case .tabletProximity:
            "tabletProximity"
        case .scrollWheel:
            "scrollWheel"
        case appKitDefinedEventType:
            "appKitDefined"
        case systemDefinedEventType:
            "systemDefined/NX"
        case applicationDefinedEventType:
            "applicationDefined"
        case rotateEventType:
            "rotate"
        case beginGestureEventType:
            "beginGesture"
        case endGestureEventType:
            "endGesture"
        case gestureEventType:
            "gesture"
        case magnifyEventType:
            "magnify"
        case swipeEventType:
            "swipe"
        case smartMagnifyEventType:
            "smartMagnify"
        case pressureEventType:
            "pressure"
        case directTouchEventType:
            "directTouch"
        case changeModeEventType:
            "changeMode"
        default:
            "rawValue=\(type.rawValue)"
        }
    }

    private static let appKitDefinedEventType = CGEventType(rawValue: 13)!
    private static let systemDefinedEventType = CGEventType(rawValue: 14)!
    private static let applicationDefinedEventType = CGEventType(rawValue: 15)!
    private static let rotateEventType = CGEventType(rawValue: 18)!
    private static let beginGestureEventType = CGEventType(rawValue: 19)!
    private static let endGestureEventType = CGEventType(rawValue: 20)!
    private static let gestureEventType = CGEventType(rawValue: 29)!
    private static let magnifyEventType = CGEventType(rawValue: 30)!
    private static let swipeEventType = CGEventType(rawValue: 31)!
    private static let smartMagnifyEventType = CGEventType(rawValue: 32)!
    private static let pressureEventType = CGEventType(rawValue: 34)!
    private static let directTouchEventType = CGEventType(rawValue: 37)!
    private static let changeModeEventType = CGEventType(rawValue: 38)!

    private static func isKeyDown(_ keyCode: CGKeyCode) -> Bool {
        CGEventSource.keyState(.hidSystemState, key: keyCode)
            || CGEventSource.keyState(.combinedSessionState, key: keyCode)
    }
}
#else
final class InputLockService: InputLockServicing {
    static let shared = InputLockService()

    var onEarlyUnlock: (() -> Void)?
    var onLockInterrupted: (() -> Void)?
    var onCommandKeyDebugStateChanged: ((CommandKeyDebugState) -> Void)?

    var isAccessibilityPermissionGranted: Bool { false }

    var permissionDiagnostics: PermissionDiagnostics {
        PermissionDiagnostics(
            axIsProcessTrustedResult: false,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "Unknown",
            bundlePath: Bundle.main.bundlePath
        )
    }

    var commandKeyDebugState: CommandKeyDebugState {
        CommandKeyDebugState()
    }

    private init() {}

    @discardableResult
    func requestAccessibilityPermission(prompt: Bool) -> Bool {
        false
    }

    func openAccessibilitySettings() {}

    func startLock(configuration: InputLockConfiguration) throws {
        throw InputLockError.accessibilityPermissionMissing
    }

    func stopLock() {}
}
#endif
