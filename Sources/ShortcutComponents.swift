import SwiftUI
import AppKit

struct DictationShortcutEditor: View {
    @EnvironmentObject var appState: AppState

    let showsIntroText: Bool
    let onCaptureStateChange: ((Bool) -> Void)?

    @State private var activeCaptureRole: ShortcutRole?
    @State private var holdValidationMessage: String?
    @State private var toggleValidationMessage: String?

    init(showsIntroText: Bool = true, onCaptureStateChange: ((Bool) -> Void)? = nil) {
        self.showsIntroText = showsIntroText
        self.onCaptureStateChange = onCaptureStateChange
    }

    @State private var capturingShortcutID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsIntroText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dictation Shortcuts")
                        .font(.headline)
                    Text("Add shortcuts to trigger dictation. You can set different languages and modes for each key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                ForEach($appState.dictationShortcuts) { $shortcut in
                    DictationShortcutRow(
                        shortcut: $shortcut,
                        isCapturing: Binding(
                            get: { capturingShortcutID == shortcut.id },
                            set: { capturingShortcutID = $0 ? shortcut.id : nil }
                        ),
                        onDelete: {
                            if appState.dictationShortcuts.count > 1 {
                                appState.dictationShortcuts.removeAll { $0.id == shortcut.id }
                            }
                        }
                    )
                }

                Button(action: {
                    appState.dictationShortcuts.append(DictationShortcut(
                        binding: .disabled,
                        mode: .hold,
                        language: nil
                    ))
                }) {
                    Label("Add Shortcut", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 8)
            }

            if appState.usesFnShortcut {
                Text("Tip: If Fn opens the Emoji picker, go to System Settings > Keyboard and change \"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
            }
        }
        .onChange(of: capturingShortcutID) { id in
            onCaptureStateChange?(id != nil)
        }
        .onDisappear {
            onCaptureStateChange?(false)
        }
    }
}

struct DictationShortcutRow: View {
    @Binding var shortcut: DictationShortcut
    @Binding var isCapturing: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Mode", selection: $shortcut.mode) {
                    Text("Hold to Talk").tag(RecordingTriggerMode.hold)
                    Text("Tap to Toggle").tag(RecordingTriggerMode.toggle)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)

                Spacer()

                Picker("Language", selection: $shortcut.language) {
                    Text("Auto-detect").tag(String?.none)
                    Divider()
                    Text("English").tag(String?.some("en"))
                    Text("German").tag(String?.some("de"))
                    Text("Arabic").tag(String?.some("ar"))
                }
                .labelStyle(.titleOnly)
                .frame(width: 120)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }

            ShortcutCaptureRow(
                savedBinding: shortcut.binding.isDisabled ? nil : shortcut.binding,
                isSelected: !shortcut.binding.isDisabled,
                isCapturing: $isCapturing,
                onSelectSaved: { shortcut.binding = $0 },
                onCapture: { shortcut.binding = $0 }
            )
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}


private struct ShortcutPresetRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutCaptureRow: View {
    let savedBinding: ShortcutBinding?
    let isSelected: Bool
    @Binding var isCapturing: Bool
    let onSelectSaved: (ShortcutBinding) -> Void
    let onCapture: (ShortcutBinding) -> Void

    @State private var localKeyMonitor: Any?
    @State private var localFlagsMonitor: Any?
    @State private var pressedModifierKeyCodes: Set<UInt16> = []
    @State private var currentBinding: ShortcutBinding?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    if let savedBinding {
                        onSelectSaved(savedBinding)
                    } else if !isCapturing {
                        startCapture()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : (savedBinding == nil ? "plus.circle" : "circle"))
                            .foregroundStyle(isSelected ? .blue : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayedBindingName)
                                .font(displayedBindingUsesMonospace ? .system(.body, design: .monospaced).weight(.semibold) : .body)
                                .foregroundStyle(.primary)
                            Text(displayedBindingSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isCapturing)

                Button(isCapturing ? "Done" : "Record…") {
                    if isCapturing {
                        finishCapture()
                    } else {
                        startCapture()
                    }
                }
                .buttonStyle(.bordered)

                if isCapturing {
                    Button("Cancel") {
                        cancelCapture()
                    }
                    .buttonStyle(.plain)
                }
            }

            if isCapturing {
                Label(
                    currentBinding == nil
                        ? "Press and hold the shortcut you want."
                        : "Press Esc or Enter to save.",
                    systemImage: "keyboard"
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .onDisappear {
            stopCapture(clearCaptureState: true)
        }
    }

    private func startCapture() {
        stopCapture(clearCaptureState: false)
        isCapturing = true
        pressedModifierKeyCodes.removeAll()
        currentBinding = nil

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if ShortcutBinding.modifierKeyCodes.contains(event.keyCode) {
                if pressedModifierKeyCodes.contains(event.keyCode) {
                    pressedModifierKeyCodes.remove(event.keyCode)
                } else {
                    pressedModifierKeyCodes.insert(event.keyCode)
                }
            }

            if let binding = ShortcutBinding.fromModifierKeyCode(
                event.keyCode,
                pressedModifierKeyCodes: pressedModifierKeyCodes,
                allowBareModifier: true
            ) {
                currentBinding = binding
            }
            return nil
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isReturnKey = event.keyCode == 36 || event.keyCode == 76
            let hasPendingCapture = currentBinding != nil

            if isReturnKey && hasPendingCapture {
                finishCapture()
                return nil
            }
            if event.keyCode == 53 && hasPendingCapture {
                finishCapture()
                return nil
            }

            guard !ShortcutBinding.modifierKeyCodes.contains(event.keyCode) else {
                return nil
            }

            guard let binding = ShortcutBinding.from(event: event) else {
                return nil
            }

            currentBinding = binding
            return nil
        }
    }

    private func finishCapture() {
        guard let currentBinding else {
            cancelCapture()
            return
        }
        onCapture(currentBinding)
        stopCapture(clearCaptureState: true)
    }

    private func cancelCapture() {
        stopCapture(clearCaptureState: true)
    }

    private func stopCapture(clearCaptureState: Bool) {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
        pressedModifierKeyCodes.removeAll()
        currentBinding = nil
        if clearCaptureState {
            isCapturing = false
        }
    }

    private var displayedBindingName: String {
        if let currentBinding {
            currentBinding.displayName
        } else if let savedBinding {
            savedBinding.displayName
        } else {
            "Custom Shortcut"
        }
    }

    private var displayedBindingSubtitle: String {
        if isCapturing {
            return currentBinding == nil ? "Recording shortcut…" : "Recorded shortcut"
        }
        return savedBinding == nil ? "Record any key combo." : "Saved custom shortcut"
    }

    private var displayedBindingUsesMonospace: Bool {
        currentBinding != nil || savedBinding != nil
    }
}
