import Carbon
import AppKit

public protocol HotKeyManaging: AnyObject {
    var onTrigger: (() -> Void)? { get set }
    func register(keyCode: UInt32, modifiers: UInt32)
    func unregister()
}

public final class HotKeyManager: HotKeyManaging {
    public static let shared = HotKeyManager()
    public var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    public init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                mgr.onTrigger?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )
    }

    public func register(keyCode: UInt32 = UInt32(kVK_ANSI_V), modifiers: UInt32 = UInt32(optionKey)) {
        unregister()
        let hotKeyID = EventHotKeyID(signature: OSType(0x53434C50), id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        if let hRef = handlerRef {
            RemoveEventHandler(hRef)
        }
    }
}
