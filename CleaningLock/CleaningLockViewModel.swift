//
//  CleaningLockViewModel.swift
//  CleaningLock
//
//  Created by Jeremia Justin Grasio on 13/05/26.
//

import Foundation
import Combine

@MainActor
final class CleaningLockViewModel: ObservableObject {
    enum CleaningDuration: Int, CaseIterable, Identifiable {
        case thirtySeconds = 30
        case oneMinute = 60
        case ninetySeconds = 90
        case twoMinutes = 120
        case threeMinutes = 180

        var id: Int { rawValue }

        var seconds: Int { rawValue }

        var label: String {
            switch self {
            case .thirtySeconds:
                "30s"
            case .oneMinute:
                "1m"
            case .ninetySeconds:
                "1.5m"
            case .twoMinutes:
                "2m"
            case .threeMinutes:
                "3m"
            }
        }

        var description: String {
            switch self {
            case .thirtySeconds:
                "30 seconds"
            case .oneMinute:
                "1 minute"
            case .ninetySeconds:
                "1.5 minutes"
            case .twoMinutes:
                "2 minutes"
            case .threeMinutes:
                "3 minutes"
            }
        }
    }

    enum State: Equatable {
        case permissionNeeded
        case ready
        case arming(secondsRemaining: Int)
        case active(secondsRemaining: Int)
        case error(message: String)
    }

    @Published private(set) var state: State = .permissionNeeded
    @Published private(set) var permissionDiagnostics: PermissionDiagnostics
    @Published private(set) var commandKeyDebugState: CommandKeyDebugState
    @Published private(set) var isUITestModeEnabled = false
    @Published var selectedCleaningDuration: CleaningDuration = .oneMinute
    @Published var blocksKeyboard = true
    @Published var blocksPointer = true

    private let inputLockService: InputLockServicing
    private var armingTask: Task<Void, Never>?
    private var activeTimerTask: Task<Void, Never>?
    private var commandHoldTimer: Timer?
    private var commandHoldStartedAt: Date?

    private let armingDuration = 3
    private let commandHoldDuration: TimeInterval = 3

    init(inputLockService: InputLockServicing? = nil) {
        self.inputLockService = inputLockService ?? InputLockService.shared
        self.permissionDiagnostics = self.inputLockService.permissionDiagnostics
        self.commandKeyDebugState = self.inputLockService.commandKeyDebugState

        self.inputLockService.onEarlyUnlock = { [weak self] in
            Task { @MainActor in
                self?.finishCleaningMode(reason: "input service early unlock", cancelActiveTimer: true)
            }
        }

        self.inputLockService.onLockInterrupted = { [weak self] in
            Task { @MainActor in
                self?.handleLockInterrupted()
            }
        }

        self.inputLockService.onCommandKeyDebugStateChanged = { [weak self] debugState in
            Task { @MainActor in
                self?.handleCommandKeyDebugStateChanged(debugState)
            }
        }
    }

    deinit {
        armingTask?.cancel()
        activeTimerTask?.cancel()
        commandHoldTimer?.invalidate()
        inputLockService.stopLock()
    }

    func refreshPermission() {
        updatePermissionDiagnostics()

        guard inputLockService.isAccessibilityPermissionGranted else {
            if isUITestModeEnabled {
                state = .ready
                return
            }

            cancelTimers()
            inputLockService.stopLock()
            commandKeyDebugState = inputLockService.commandKeyDebugState
            state = .permissionNeeded
            return
        }

        if case .permissionNeeded = state {
            state = .ready
        } else if case .error = state {
            state = .ready
        }
    }

    func checkPermissionAgain() {
        inputLockService.requestAccessibilityPermission(prompt: true)
        refreshPermission()
    }

    func openSystemSettings() {
        inputLockService.requestAccessibilityPermission(prompt: true)
        updatePermissionDiagnostics()
        inputLockService.openAccessibilitySettings()
    }

    func enableUITestMode() {
        isUITestModeEnabled = true
        state = .ready
    }

    func startCleaningMode() {
        guard inputLockService.isAccessibilityPermissionGranted || isUITestModeEnabled else {
            state = .permissionNeeded
            return
        }

        cancelTimers()
        state = .arming(secondsRemaining: armingDuration)

        armingTask = Task { [weak self] in
            guard let self else { return }

            for seconds in stride(from: armingDuration, through: 1, by: -1) {
                await MainActor.run {
                    self.state = .arming(secondsRemaining: seconds)
                }
                try? await Task.sleep(for: .seconds(1))

                if Task.isCancelled {
                    return
                }
            }

            await MainActor.run {
                self.activateCleaningMode()
            }
        }
    }

    func stopCleaningMode() {
        cancelTimers()
        inputLockService.stopLock()
        commandKeyDebugState = inputLockService.commandKeyDebugState

        if inputLockService.isAccessibilityPermissionGranted {
            state = .ready
        } else {
            state = .permissionNeeded
        }
    }

    private func activateCleaningMode() {
        guard inputLockService.isAccessibilityPermissionGranted else {
            guard isUITestModeEnabled else {
                state = .permissionNeeded
                return
            }

            state = .active(secondsRemaining: selectedCleaningDuration.seconds)
            startActiveTimer()
            return
        }

        do {
            try inputLockService.startLock(
                configuration: InputLockConfiguration(
                    blocksKeyboard: blocksKeyboard,
                    blocksPointer: blocksPointer
                )
            )
        } catch {
            inputLockService.stopLock()
            state = .error(message: error.localizedDescription)
            return
        }

        state = .active(secondsRemaining: selectedCleaningDuration.seconds)
        startActiveTimer()
    }

    private func startActiveTimer() {
        let cleaningDuration = selectedCleaningDuration.seconds
        print("[CleaningLock] startActiveTimer duration=\(cleaningDuration)")
        activeTimerTask?.cancel()

        activeTimerTask = Task { [weak self] in
            guard let self else { return }

            for secondsRemaining in stride(from: cleaningDuration, through: 0, by: -1) {
                await MainActor.run {
                    print("[CleaningLock] active timer tick secondsRemaining=\(secondsRemaining)")
                    self.state = .active(secondsRemaining: secondsRemaining)
                }

                if secondsRemaining == 0 {
                    break
                }

                try? await Task.sleep(for: .seconds(1))

                if Task.isCancelled {
                    print("[CleaningLock] active timer cancelled")
                    return
                }
            }

            await MainActor.run {
                self.finishCleaningMode(reason: "auto timer completed", cancelActiveTimer: false)
            }
        }
    }

    var isInputLockingEnabled: Bool {
        inputLockService.isAccessibilityPermissionGranted && !isUITestModeEnabled
    }

    private func finishCleaningMode(reason: String, cancelActiveTimer: Bool) {
        print("[CleaningLock] finishCleaningMode reason=\(reason), cancelActiveTimer=\(cancelActiveTimer)")
        armingTask?.cancel()
        armingTask = nil
        cancelCommandHoldTimer(reason: "finishCleaningMode")

        if cancelActiveTimer {
            activeTimerTask?.cancel()
        }
        activeTimerTask = nil

        inputLockService.stopLock()
        commandKeyDebugState = inputLockService.commandKeyDebugState
        updatePermissionDiagnostics()

        if inputLockService.isAccessibilityPermissionGranted || isUITestModeEnabled {
            state = .ready
        } else {
            state = .permissionNeeded
        }
    }

    private func handleLockInterrupted() {
        cancelTimers()
        inputLockService.stopLock()
        state = .error(message: "macOS interrupted the input lock. Cleaning mode has been stopped safely.")
    }

    private func cancelTimers() {
        armingTask?.cancel()
        armingTask = nil
        activeTimerTask?.cancel()
        activeTimerTask = nil
        cancelCommandHoldTimer(reason: "cancelTimers")
    }

    private func updatePermissionDiagnostics() {
        permissionDiagnostics = inputLockService.permissionDiagnostics
    }

    private func handleCommandKeyDebugStateChanged(_ debugState: CommandKeyDebugState) {
        let previousDebugState = commandKeyDebugState
        commandKeyDebugState = debugState

        if previousDebugState != debugState {
            print("[CleaningLock] command debug state changed left=\(debugState.leftCommandIsDown) right=\(debugState.rightCommandIsDown)")
        }

        guard case .active = state else {
            cancelCommandHoldTimer(reason: "command state changed while not active")
            return
        }

        guard debugState.leftCommandIsDown, debugState.rightCommandIsDown else {
            cancelCommandHoldTimer(reason: "one or both Command keys released left=\(debugState.leftCommandIsDown) right=\(debugState.rightCommandIsDown)")
            return
        }

        guard commandHoldTimer == nil else {
            return
        }

        print("[CleaningLock] both Command keys down; starting \(commandHoldDuration)s early unlock hold timer")
        commandHoldStartedAt = Date()

        let timer = Timer(timeInterval: commandHoldDuration, repeats: false) { [weak self] _ in
            guard let viewModel = self else { return }

            Task { @MainActor in
                viewModel.handleCommandHoldTimerFired()
            }
        }

        commandHoldTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleCommandHoldTimerFired() {
        let elapsed = commandHoldStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        print("[CleaningLock] early unlock hold timer fired elapsed=\(String(format: "%.2f", elapsed)) left=\(commandKeyDebugState.leftCommandIsDown) right=\(commandKeyDebugState.rightCommandIsDown) state=\(state)")

        commandHoldTimer?.invalidate()
        commandHoldTimer = nil
        commandHoldStartedAt = nil

        guard case .active = state else {
            print("[CleaningLock] early unlock ignored because state is not active")
            return
        }

        guard commandKeyDebugState.leftCommandIsDown, commandKeyDebugState.rightCommandIsDown else {
            print("[CleaningLock] early unlock ignored because both Command keys are not still down")
            return
        }

        print("[CleaningLock] calling finishCleaningMode(reason: both Command early unlock)")
        finishCleaningMode(reason: "both Command early unlock", cancelActiveTimer: true)
    }

    private func cancelCommandHoldTimer(reason: String) {
        guard commandHoldTimer != nil else { return }

        print("[CleaningLock] cancelling early unlock hold timer reason=\(reason)")
        commandHoldTimer?.invalidate()
        commandHoldTimer = nil
        commandHoldStartedAt = nil
    }
}
