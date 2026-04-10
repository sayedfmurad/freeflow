import Foundation

enum DictationShortcutAction {
    case start(RecordingTriggerMode)
    case stop
    case switchedToToggle
}

final class DictationShortcutSessionController {
    private(set) var activeMode: RecordingTriggerMode?
    private(set) var activeShortcutID: UUID?
    private(set) var toggleStopArmed = false

    func handle(event: ShortcutEvent, shortcuts: [DictationShortcut], isTranscribing: Bool) -> DictationShortcutAction? {
        switch event {
        case .activated(let id):
            guard let shortcut = shortcuts.first(where: { $0.id == id }) else { return nil }
            
            if activeShortcutID == nil {
                guard !isTranscribing else { return nil }
                activeShortcutID = id
                activeMode = shortcut.mode
                toggleStopArmed = false
                return .start(shortcut.mode)
            } else if activeShortcutID != id {
                // Switching shortcuts while one is already active (e.g. latching)
                if shortcut.mode == .toggle {
                    activeShortcutID = id
                    activeMode = .toggle
                    toggleStopArmed = false
                    return .switchedToToggle
                }
                return nil
            }
            return nil

        case .deactivated(let id):
            guard let activeID = activeShortcutID, activeID == id else { return nil }
            
            switch activeMode {
            case .hold:
                reset()
                return .stop
            case .toggle:
                toggleStopArmed = true
                return nil
            case .none:
                return nil
            }
        }
    }

    func beginManual(mode: RecordingTriggerMode) {
        activeMode = mode
        toggleStopArmed = false
    }

    func forceToggleMode() {
        activeMode = .toggle
        toggleStopArmed = false
    }

    func reset() {
        activeMode = nil
        activeShortcutID = nil
        toggleStopArmed = false
    }
}
