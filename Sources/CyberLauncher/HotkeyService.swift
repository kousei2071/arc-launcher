import AppKit
import Carbon

private let commandShiftLHotkeyID = EventHotKeyID(signature: OSType(0x43594c48), id: 1)

final class HotkeyService: @unchecked Sendable {
    private let callback: @MainActor () -> Void
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var localMonitor: Any?

    init(callback: @escaping @MainActor () -> Void) {
        self.callback = callback
    }

    func start() {
        installLocalMonitor()
        if registerCarbonHotkey() {
            print("  ショートカット: Carbon RegisterEventHotKey（有効）")
        } else {
            print("  ショートカット: フォーカス時のローカル監視（有効）")
            print("  ※ ⌘+Shift+L が他のアプリで使われている場合は、サービス経由のトグルを使ってください。")
        }
    }

    private func registerCarbonHotkey() -> Bool {
        let hotkeyID = commandShiftLHotkeyID
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            UInt32(cmdKey | shiftKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        guard status == noErr else {
            return false
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let handler: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            var eventID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &eventID
            )
            if eventID.id == commandShiftLHotkeyID.id {
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    service.callback()
                }
            }
            return noErr
        }
        return InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPointer, &eventHandler) == noErr
    }

    private func installLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_ANSI_L),
               event.modifierFlags.contains(.command),
               event.modifierFlags.contains(.shift) {
                Task { @MainActor in
                    self?.callback()
                }
                return nil
            }
            return event
        }
    }

    deinit {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
}
