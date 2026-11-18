import AppKit
import SwiftUI

/// ส้มไมค์ → แดงดุ บนดำถ่าน
enum Brand {
    static let orange = NSColor(srgbRed: 1.00, green: 0.42, blue: 0.12, alpha: 1)   // #FF6B1F
    static let red = NSColor(srgbRed: 1.00, green: 0.18, blue: 0.18, alpha: 1)      // #FF2D2D
    static let amber = NSColor(srgbRed: 1.00, green: 0.60, blue: 0.12, alpha: 1)    // #FF9A1F

    static var swiftOrange: Color { Color(nsColor: orange) }
    static var swiftRed: Color { Color(nsColor: red) }
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)       // พื้นหลังหลัก
    static let panel = Color(red: 0.12, green: 0.12, blue: 0.14)     // การ์ด
    static let line = Color.white.opacity(0.08)
    static let muted = Color.white.opacity(0.55)

    /// ฟอนต์ประจำแอป: Anuphan (Cadson Demak, SIL OFL 1.1) — ฝังมากับแอปใน Resources/Fonts
    /// ไม่มีน้ำหนัก Black/Heavy จึงใช้ Bold แทน
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black, .heavy, .bold: name = "Anuphan-Bold"
        case .semibold: name = "Anuphan-SemiBold"
        case .medium: name = "Anuphan-Medium"
        case .light, .thin, .ultraLight: name = "Anuphan-Light"
        default: name = "Anuphan-Regular"
        }
        return .custom(name, size: size)
    }

    static func nsFont(_ size: CGFloat, bold: Bool = false) -> NSFont {
        NSFont(name: bold ? "Anuphan-SemiBold" : "Anuphan-Regular", size: size) ?? .systemFont(ofSize: size)
    }

    /// ไล่สีส้ม → แดง ใช้กับปุ่มหลักและหัวข้อ
    static var hot: LinearGradient {
        LinearGradient(colors: [Color(nsColor: amber), Color(nsColor: red)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// ปุ่มที่ใช้กดค้างเพื่อพูด
enum Hotkey: String, CaseIterable {
    case rightOption, rightCommand, rightControl, rightShift
    case leftOption, leftCommand, leftControl, leftShift
    case fn

    static let `default` = Hotkey.rightOption

    /// ปุ่มนี้ใช้คู่กับคีย์ลัดอื่นบ่อย (กดคู่ปุ่มอื่นแล้วจะยกเลิกการอัดเอง)
    var isCommonlyUsed: Bool { [.leftOption, .leftCommand, .leftControl, .leftShift, .rightShift].contains(self) }

    var keyCode: UInt16 {
        switch self {
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        case .rightShift: 60
        case .leftOption: 58
        case .leftCommand: 55
        case .leftControl: 59
        case .leftShift: 56
        case .fn: 63
        }
    }

    /// device-dependent modifier bit (แยกซ้าย/ขวา)
    var deviceMask: UInt {
        switch self {
        case .rightOption: 0x40
        case .rightCommand: 0x10
        case .rightControl: 0x2000
        case .rightShift: 0x04
        case .leftOption: 0x20
        case .leftCommand: 0x08
        case .leftControl: 0x01
        case .leftShift: 0x02
        case .fn: NSEvent.ModifierFlags.function.rawValue
        }
    }

    static func from(keyCode: UInt16) -> Hotkey? {
        allCases.first { $0.keyCode == keyCode }
    }

    private var symbol: String {
        switch self {
        case .rightOption, .leftOption: "⌥"
        case .rightCommand, .leftCommand: "⌘"
        case .rightControl, .leftControl: "⌃"
        case .rightShift, .leftShift: "⇧"
        case .fn: "fn"
        }
    }

    private var name: String {
        switch self {
        case .rightOption, .leftOption: "Option"
        case .rightCommand, .leftCommand: "Command"
        case .rightControl, .leftControl: "Control"
        case .rightShift, .leftShift: "Shift"
        case .fn: ""
        }
    }

    private var side: String {
        switch self {
        case .rightOption, .rightCommand, .rightControl, .rightShift: "ขวา"
        case .leftOption, .leftCommand, .leftControl, .leftShift: "ซ้าย"
        case .fn: ""
        }
    }

    var title: String { self == .fn ? "fn (ปุ่มลูกโลก)" : "\(symbol) \(name) \(side)" }
    var short: String { self == .fn ? "fn" : "\(symbol) \(side)" }
}

/// ระหว่างผู้ใช้กำลังตั้งปุ่มลัดใหม่ ห้ามเริ่มอัดเสียง
enum HotkeyCapture {
    static var active = false
}

enum Language: String, CaseIterable {
    case thai = "th-TH"
    case english = "en-US"

    var title: String {
        switch self {
        case .thai: "ภาษาไทย"
        case .english: "English"
        }
    }
}

enum Engine: String, CaseIterable {
    case gemini, apple

    var title: String {
        switch self {
        case .gemini: "Gemini Live — เร็ว เข้าใจ “เอาใหม่” สั่งแปลได้"
        case .apple: "Apple — ไม่ต้องใช้ key (พื้นฐาน)"
        }
    }
}

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var engine: Engine {
        get { Engine(rawValue: d.string(forKey: "engine") ?? "") ?? .gemini }
        set { d.set(newValue.rawValue, forKey: "engine") }
    }

    var geminiModel: GeminiModel {
        get { GeminiModel(rawValue: d.string(forKey: "geminiModel") ?? "") ?? .flashLite }
        set { d.set(newValue.rawValue, forKey: "geminiModel") }
    }

    /// อ่านจากไฟล์ครั้งเดียวแล้วจำไว้
    private var cachedKey: String??
    var geminiKey: String? {
        get {
            if let c = cachedKey { return c }
            let k = SecretStore.get("gemini-api-key")
            cachedKey = .some(k)
            return k
        }
        set {
            let v = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            SecretStore.set(v, for: "gemini-api-key")
            cachedKey = .some((v?.isEmpty ?? true) ? nil : v)
        }
    }

    var hasGeminiKey: Bool {
        if CommandLine.arguments.contains("--pretend-no-key") { return false } // สำหรับถ่ายภาพหน้าจอ
        return !(geminiKey ?? "").isEmpty
    }

    /// ปุ่มลัด (ปุ่มเดียวหรือปุ่มผสม) — ย้ายค่ามาจากแบบเก่า “hotkey” อัตโนมัติ
    var shortcut: Shortcut {
        get {
            if let data = d.data(forKey: "shortcut"), let sc = try? JSONDecoder().decode(Shortcut.self, from: data) { return sc }
            if let old = Hotkey(rawValue: d.string(forKey: "hotkey") ?? "") { return .modifier(old) }
            return .default
        }
        set {
            d.set(try? JSONEncoder().encode(newValue), forKey: "shortcut")
            NotificationCenter.default.post(name: Settings.changed, object: nil)
        }
    }

    /// วิธีกด 2 สวิตช์: กดค้างแล้วพูด / แตะเพื่อพูดยาว (เปิดทั้งคู่ได้ ต้องเปิดอย่างน้อย 1)
    var holdEnabled: Bool {
        get { d.object(forKey: "modeHold") as? Bool ?? true }
        set {
            d.set(newValue, forKey: "modeHold")
            if !newValue && !tapEnabled { d.set(true, forKey: "modeTap") }
            NotificationCenter.default.post(name: Settings.changed, object: nil)
        }
    }

    var tapEnabled: Bool {
        get { d.object(forKey: "modeTap") as? Bool ?? true }
        set {
            d.set(newValue, forKey: "modeTap")
            if !newValue && !holdEnabled { d.set(true, forKey: "modeHold") }
            NotificationCenter.default.post(name: Settings.changed, object: nil)
        }
    }

    /// รวม 2 สวิตช์เป็นโหมดเดียวให้ตัวจัดการปุ่มใช้
    var triggerMode: TriggerMode {
        switch (holdEnabled, tapEnabled) {
        case (true, true): return .both
        case (true, false): return .hold
        default: return .toggle
        }
    }


    var language: Language {
        get { Language(rawValue: d.string(forKey: "language") ?? "") ?? .thai }
        set { d.set(newValue.rawValue, forKey: "language") }
    }

    var playSounds: Bool {
        get { d.object(forKey: "playSounds") as? Bool ?? true }
        set { d.set(newValue, forKey: "playSounds") }
    }

    static let changed = Notification.Name("PoodDiWaSettingsChanged")

    /// สวิตช์หลัก: ปิด = ไม่รับเสียงเลย (ปุ่มลัดไม่ทำงาน)
    var enabled: Bool {
        get { d.object(forKey: "enabled") as? Bool ?? true }
        set {
            d.set(newValue, forKey: "enabled")
            NotificationCenter.default.post(name: Settings.changed, object: nil)
        }
    }

    /// คำศัพท์เฉพาะ (ชื่อคน แบรนด์ ศัพท์เทคนิค) — คั่นด้วยจุลภาคหรือขึ้นบรรทัดใหม่
    var vocabularyText: String {
        get { d.string(forKey: "vocabulary") ?? "" }
        set { d.set(newValue, forKey: "vocabulary") }
    }

    var vocabulary: [String] {
        var seen = Set<String>()
        return vocabularyText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(500)
            .map { $0 }
    }

    /// โชว์คำที่พูดสด ๆ ในแถบตอนพูด (ปิดไว้ก่อน ให้แถบเล็กที่สุด)
    var showLiveText: Bool {
        get { d.object(forKey: "showLiveText") as? Bool ?? false }
        set { d.set(newValue, forKey: "showLiveText") }
    }

    var keepInClipboard: Bool {
        get { d.object(forKey: "keepInClipboard") as? Bool ?? false }
        set { d.set(newValue, forKey: "keepInClipboard") }
    }
}
