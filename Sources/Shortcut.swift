import AppKit
import Carbon.HIToolbox

/// วิธีกด: กดค้างแล้วพูด / กดครั้งเดียวเริ่ม กดอีกครั้งจบ
enum TriggerMode: String, CaseIterable, Codable {
    /// ได้ทั้งสองแบบ: กดค้าง = พูดแล้วปล่อย · แตะทีเดียว = พูดยาว แตะอีกทีจบ
    case both, hold, toggle

    var title: String {
        switch self {
        case .both: "ได้ทั้งสองแบบ"
        case .hold: "กดค้างอย่างเดียว"
        case .toggle: "กดเริ่ม-จบอย่างเดียว"
        }
    }

    var detail: String {
        switch self {
        case .both: "กดค้าง = พูดรัว ๆ ปล่อยแล้วพิมพ์ · แตะทีเดียว = พูดยาวแบบไม่ต้องค้าง แตะอีกทีเมื่อจบ"
        case .hold: "ค้างไว้ระหว่างพูด ปล่อยแล้วพิมพ์ให้"
        case .toggle: "กดทีเดียวแล้วพูดยาว ๆ ได้ กดอีกทีเมื่อพูดจบ"
        }
    }
}

/// ปุ่มลัด: ปุ่ม modifier ปุ่มเดียว (เช่น ⌥ ขวา) หรือปุ่มผสม (เช่น ⌥ Space)
struct Shortcut: Codable, Equatable {
    enum Kind: String, Codable { case modifier, combo }

    var kind: Kind
    /// kind == .modifier
    var modifierKey: String?
    /// kind == .combo — รหัสปุ่ม + modifier แบบ Carbon + ชื่อปุ่มไว้แสดง
    var keyCode: UInt32 = 0
    var carbonModifiers: UInt32 = 0
    var keyName: String = ""

    static let `default` = Shortcut(kind: .modifier, modifierKey: Hotkey.rightOption.rawValue)

    static func modifier(_ h: Hotkey) -> Shortcut { Shortcut(kind: .modifier, modifierKey: h.rawValue) }

    var hotkey: Hotkey? { kind == .modifier ? Hotkey(rawValue: modifierKey ?? "") ?? .rightOption : nil }

    private var modifierSymbols: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    /// ชื่อเต็ม เช่น “⌥ Option ขวา” หรือ “⌥ Space”
    var title: String {
        switch kind {
        case .modifier: hotkey?.title ?? "⌥ Option ขวา"
        case .combo: modifierSymbols.isEmpty ? keyName : "\(modifierSymbols) \(keyName)"
        }
    }

    /// ชื่อสั้น ใช้ในข้อความแนะนำ
    var short: String {
        switch kind {
        case .modifier: hotkey?.short ?? "⌥ ขวา"
        case .combo: title
        }
    }

    /// ชนกับคีย์ลัดของระบบไหม — คืนคำอธิบายภาษาคน
    var conflict: String? {
        if kind == .modifier {
            if hotkey == .fn { return "ตั้ง System Settings → Keyboard → “Press fn key to” เป็น “Do Nothing” ก่อน" }
            if hotkey?.isCommonlyUsed == true { return "ปุ่มนี้ใช้กับคีย์ลัดอื่นบ่อย ถ้ากดคู่ปุ่มอื่น พูดดิวะจะไม่เริ่มอัด" }
            return nil
        }
        let cmd = UInt32(cmdKey), opt = UInt32(optionKey), ctl = UInt32(controlKey), sft = UInt32(shiftKey)
        let m = carbonModifiers
        switch (Int(keyCode), m) {
        case (kVK_Space, cmd): return "ชนกับ Spotlight — ไปปิดที่ System Settings → Keyboard → Keyboard Shortcuts → Spotlight หรือเลือกปุ่มอื่น"
        case (kVK_Space, ctl): return "ชนกับการสลับภาษา (Input Source) ของ Mac"
        case (kVK_Space, ctl | cmd): return "ชนกับหน้าต่างอีโมจิของ Mac"
        case (kVK_Space, opt | cmd): return "ชนกับการค้นหาใน Finder"
        case (kVK_Tab, cmd): return "ชนกับการสลับแอป (⌘ Tab)"
        case (kVK_ANSI_Q, ctl | cmd): return "ชนกับการล็อกหน้าจอ"
        case (kVK_ANSI_3, cmd | sft), (kVK_ANSI_4, cmd | sft), (kVK_ANSI_5, cmd | sft): return "ชนกับการถ่ายภาพหน้าจอ"
        default: break
        }
        let common: Set<Int> = [kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X, kVK_ANSI_Z, kVK_ANSI_A, kVK_ANSI_S,
                                kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_N, kVK_ANSI_T, kVK_ANSI_F, kVK_ANSI_P]
        if m == cmd && common.contains(Int(keyCode)) { return "ชนกับคีย์ลัดที่ทุกแอปใช้ (เช่น คัดลอก/วาง/ปิด) — เลือกปุ่มอื่นดีกว่า" }
        return nil
    }

    // MARK: แปลงจาก NSEvent ตอนผู้ใช้กดตั้งค่า

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    static func keyName(for event: NSEvent) -> String {
        let names: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab", kVK_Delete: "Delete",
            kVK_ForwardDelete: "Del", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "Home", kVK_End: "End", kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19",
        ]
        if let n = names[Int(event.keyCode)] { return n }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }

    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
         kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19].contains(Int(keyCode))
    }
}

/// คีย์ลัดแบบปุ่มผสมผ่านระบบ hotkey ของ macOS (Carbon)
/// ได้ทั้งตอนกดและตอนปล่อย · กลืนปุ่มไม่ให้หลุดไปแอปอื่น · ไม่ต้องขอสิทธิ์เพิ่ม · ไม่กินเครื่องตอนว่าง
final class CarbonHotKey {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    fileprivate static weak var current: CarbonHotKey?

    /// คืน false ถ้าระบบไม่ยอมให้ใช้ (มีแอปอื่นจองไว้แล้ว)
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            let kind = GetEventKind(event)
            if kind == UInt32(kEventHotKeyPressed) {
                CarbonHotKey.current?.onPress?()
            } else if kind == UInt32(kEventHotKeyReleased) {
                CarbonHotKey.current?.onRelease?()
            }
            return noErr
        }, specs.count, &specs, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x5044_5741), id: 1) // 'PDWA'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        CarbonHotKey.current = self
        return status == noErr
    }

    func unregister() {
        if let r = ref { UnregisterEventHotKey(r) }
        ref = nil
        if let h = handler { RemoveEventHandler(h) }
        handler = nil
    }

    deinit { unregister() }
}
