//
//  ContentView.swift
//  CleaningLock
//
//  Created by Jeremia Justin Grasio on 13/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CleaningLockViewModel()

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView()

                Divider()

                Group {
                    switch viewModel.state {
                    case .permissionNeeded:
                        PermissionNeededView(
                            diagnostics: viewModel.permissionDiagnostics,
                            openSystemSettings: viewModel.openSystemSettings,
                            checkAgain: viewModel.checkPermissionAgain,
                            startUITestMode: viewModel.enableUITestMode
                        )
                    case .ready:
                        ReadyView(
                            isUITestModeEnabled: viewModel.isUITestModeEnabled,
                            isInputLockingEnabled: viewModel.isInputLockingEnabled,
                            selectedDuration: $viewModel.selectedCleaningDuration,
                            blocksKeyboard: $viewModel.blocksKeyboard,
                            blocksPointer: $viewModel.blocksPointer,
                            startCleaningMode: viewModel.startCleaningMode
                        )
                    case .arming(let secondsRemaining):
                        ArmingView(
                            secondsRemaining: secondsRemaining,
                            isInputLockingEnabled: viewModel.isInputLockingEnabled,
                            selectedDurationDescription: viewModel.selectedCleaningDuration.description
                        )
                    case .active(let secondsRemaining):
                        ActiveView(
                            secondsRemaining: secondsRemaining,
                            commandKeyDebugState: viewModel.commandKeyDebugState,
                            isInputLockingEnabled: viewModel.isInputLockingEnabled
                        )
                    case .error(let message):
                        ErrorStateView(message: message, tryAgain: viewModel.refreshPermission)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            }
            .frame(width: 540, height: 480)
            .background(.regularMaterial)
        }
        .onAppear(perform: viewModel.refreshPermission)
        .onDisappear(perform: viewModel.stopCleaningMode)
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("Cleaning Lock")
                    .font(.title2.weight(.semibold))
                Text("A safe cleaning mode for your Mac input devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}

private struct PermissionNeededView: View {
    let diagnostics: PermissionDiagnostics
    var openSystemSettings: () -> Void
    var checkAgain: () -> Void
    var startUITestMode: () -> Void

    var body: some View {
        StatePanel(systemImage: "hand.raised.fill", title: "Accessibility Permission Needed") {
            Text("Cleaning Lock needs Accessibility permission to temporarily block keyboard, mouse, and trackpad input during cleaning mode.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("The app uses this permission only while cleaning mode is active.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PermissionDiagnosticsView(diagnostics: diagnostics)

            HStack(spacing: 12) {
                Button("Open System Settings", action: openSystemSettings)
                    .buttonStyle(.borderedProminent)

                Button("Check Again", action: checkAgain)
                    .buttonStyle(.bordered)
            }
            .controlSize(.large)

            Button("Run UI Test Mode Without Input Locking", action: startUITestMode)
                .buttonStyle(.borderless)
                .font(.callout.weight(.medium))

            Text("UI Test Mode only tests countdowns and screen states. Keyboard, mouse, and trackpad input will not be blocked unless AXIsProcessTrusted() is true.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct PermissionDiagnosticsView: View {
    let diagnostics: PermissionDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DiagnosticRow(label: "AXIsProcessTrusted()", value: diagnostics.axIsProcessTrustedResult ? "true" : "false")
            DiagnosticRow(label: "Bundle ID", value: diagnostics.bundleIdentifier)
            DiagnosticRow(label: "Bundle path", value: diagnostics.bundlePath)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .fontWeight(.semibold)
            Text(value)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ReadyView: View {
    let isUITestModeEnabled: Bool
    let isInputLockingEnabled: Bool
    @Binding var selectedDuration: CleaningLockViewModel.CleaningDuration
    @Binding var blocksKeyboard: Bool
    @Binding var blocksPointer: Bool
    var startCleaningMode: () -> Void

    var body: some View {
        StatePanel(systemImage: "lock.open.display", title: "Ready to Clean") {
            Text(isInputLockingEnabled ? "Temporarily blocks normal keyboard, mouse, and trackpad input so you can clean your Mac safely." : "UI Test Mode is active. Countdown and timer will run, but input locking is disabled.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                DurationPickerRow(selectedDuration: $selectedDuration)
                ToggleSettingRow(icon: "keyboard", label: "Keyboard", isOn: $blocksKeyboard)
                ToggleSettingRow(icon: "cursorarrow.motionlines", label: "Mouse / Trackpad", isOn: $blocksPointer)
                InfoRow(icon: "command", label: "Early unlock", value: isInputLockingEnabled ? "Hold both Command keys for 3 seconds" : "Disabled until Accessibility is trusted")
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Button {
                startCleaningMode()
            } label: {
                Label(isUITestModeEnabled ? "Start UI Test Timer" : "Start Cleaning Mode", systemImage: isInputLockingEnabled ? "lock.fill" : "timer")
                    .frame(minWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

private struct DurationPickerRow: View {
    @Binding var selectedDuration: CleaningLockViewModel.CleaningDuration

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text("Duration")
                .foregroundStyle(.secondary)

            Spacer()

            Picker("Duration", selection: $selectedDuration) {
                ForEach(CleaningLockViewModel.CleaningDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 230)
        }
    }
}

private struct ToggleSettingRow: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Toggle(label, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .font(.callout)
    }
}

private struct ArmingView: View {
    let secondsRemaining: Int
    let isInputLockingEnabled: Bool
    let selectedDurationDescription: String

    var body: some View {
        StatePanel(systemImage: "exclamationmark.triangle.fill", title: "Cleaning mode starts in") {
            Text("\(secondsRemaining)")
                .font(.system(size: 82, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(isInputLockingEnabled ? "Input will be temporarily locked." : "UI Test Mode: input locking is disabled.")
                .foregroundStyle(.secondary)

            Text(isInputLockingEnabled ? "Hold both Command keys for 3 seconds to unlock early. Input also unlocks automatically after \(selectedDurationDescription)." : "The timer will run for \(selectedDurationDescription) without installing the event tap.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ActiveView: View {
    let secondsRemaining: Int
    let commandKeyDebugState: CommandKeyDebugState
    let isInputLockingEnabled: Bool

    var body: some View {
        VStack(spacing: 10) {
            CleaningActiveAnimation()

            Text("Cleaning Mode Active")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(Self.formattedTime(secondsRemaining))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(isInputLockingEnabled ? "Hold both Command keys for 3 seconds to unlock early." : "UI Test Mode: input locking is disabled.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Input unlocks automatically when the timer ends.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isInputLockingEnabled {
                Text("macOS system gestures such as Mission Control or App Exposé may still respond.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            CommandKeyDebugView(debugState: commandKeyDebugState)
        }
        .frame(maxWidth: 380)
    }

    private static func formattedTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct CommandKeyDebugView: View {
    let debugState: CommandKeyDebugState

    var body: some View {
        HStack(spacing: 8) {
            DebugPill(label: "Left ⌘", isActive: debugState.leftCommandIsDown)
            DebugPill(label: "Right ⌘", isActive: debugState.rightCommandIsDown)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
    }
}

private struct DebugPill: View {
    let label: String
    let isActive: Bool

    var body: some View {
        Text("\(label): \(isActive ? "held" : "not held")")
            .foregroundStyle(isActive ? .green : .secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct CleaningActiveAnimation: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
                .frame(width: 118, height: 62)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
                }

            Image(systemName: "keyboard")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .opacity(0.88)

            Capsule()
                .fill(Color.accentColor.opacity(0.28))
                .frame(width: 54, height: 5)
                .rotationEffect(.degrees(-12))
                .offset(x: isAnimating ? 34 : -34, y: isAnimating ? -16 : 16)
                .blur(radius: 0.2)

            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor.opacity(0.34))
                    .frame(width: particleSize(for: index), height: particleSize(for: index))
                    .offset(
                        x: isAnimating ? particleEndX(for: index) : particleStartX(for: index),
                        y: isAnimating ? particleEndY(for: index) : particleStartY(for: index)
                    )
                    .opacity(isAnimating ? 0.15 : 0.55)
            }
        }
        .frame(width: 132, height: 74)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func particleSize(for index: Int) -> CGFloat {
        [4, 3, 5, 3, 4, 2][index]
    }

    private func particleStartX(for index: Int) -> CGFloat {
        [-42, -22, -4, 18, 34, 48][index]
    }

    private func particleStartY(for index: Int) -> CGFloat {
        [-23, 20, -16, 24, -8, 12][index]
    }

    private func particleEndX(for index: Int) -> CGFloat {
        [-30, -34, 10, 2, 46, 30][index]
    }

    private func particleEndY(for index: Int) -> CGFloat {
        [-11, 8, -27, 12, -20, 2][index]
    }
}

private struct ErrorStateView: View {
    let message: String
    var tryAgain: () -> Void

    var body: some View {
        StatePanel(systemImage: "exclamationmark.octagon.fill", title: "Cleaning mode could not start.") {
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Please check Accessibility permission and try again.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Check Again", action: tryAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

private struct StatePanel<Content: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 62, height: 62)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)

            content
        }
        .frame(maxWidth: 380)
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
