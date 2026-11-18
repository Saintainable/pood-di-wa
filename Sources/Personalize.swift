import AppKit

// MARK: - คำย่อของฉัน (พูดคำสั้น → ได้ข้อความยาว)

struct Snippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var trigger: String
    var text: String
}

enum Snippets {
    private static let key = "snippets"

    static var all: [Snippet] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Snippet].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [Snippet]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
        NotificationCenter.default.post(name: Settings.changed, object: nil)
    }

    /// ตัดช่องว่าง/เครื่องหมาย เพื่อเทียบคำพูดกับคำย่อแบบไม่สนวรรค
    private static func normalize(_ s: String) -> String {
        s.lowercased().unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.punctuationCharacters.contains($0) }
            .map(String.init).joined()
    }

    /// พูดคำย่อทั้งประโยค → แทนทั้งหมด · พูดคำย่อกลางประโยค → แทนเฉพาะคำนั้น
    static func apply(_ text: String) -> String {
        let list = all.filter { !$0.trigger.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !list.isEmpty else { return text }
        let n = normalize(text)
        if let hit = list.first(where: { normalize($0.trigger) == n }) { return hit.text }
        var out = text
        for s in list.sorted(by: { $0.trigger.count > $1.trigger.count }) where s.trigger.count >= 3 {
            // เว้นวรรครอบข้อความที่แทรก จะได้ไม่ติดคำข้าง ๆ
            out = out.replacingOccurrences(of: s.trigger, with: " \(s.text) ", options: .caseInsensitive)
        }
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - โทนตามแอป

enum Tone: String, CaseIterable, Codable {
    case asSpoken, casual, polite, formal

    var title: String {
        switch self {
        case .asSpoken: "ตามที่พูด"
        case .casual: "กันเอง"
        case .polite: "สุภาพ"
        case .formal: "ทางการ"
        }
    }

    /// คำอธิบายให้ AI (ภาษาอังกฤษ)
    func instruction(particle: String) -> String? {
        let p = particle.isEmpty ? "" : " When a polite particle fits, use \"\(particle)\"."
        switch self {
        case .asSpoken: return nil
        case .casual: return "Rewrite in a casual, friendly chat tone (Thai: กันเอง, no stiff formality, polite particles optional). Keep the meaning."
        case .polite: return "Rewrite in a polite, warm tone suitable for colleagues or customers (Thai: สุภาพ).\(p) Keep the meaning."
        case .formal: return "Rewrite in a formal, professional written tone suitable for email or documents (Thai: ภาษาทางการ/ภาษาเขียน).\(p) Keep the meaning."
        }
    }
}

struct AppToneRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var appName: String
    var bundleID: String
    var tone: Tone
}

enum AppTones {
    private static let key = "appTones"

    static var rules: [AppToneRule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([AppToneRule].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [AppToneRule]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
        NotificationCenter.default.post(name: Settings.changed, object: nil)
    }

    static func tone(for bundleID: String?) -> Tone {
        guard let id = bundleID else { return .asSpoken }
        return rules.first(where: { $0.bundleID == id })?.tone ?? .asSpoken
    }

    /// คำลงท้ายสุภาพของผู้ใช้ (ครับ / ค่ะ / ว่าง = ไม่เติม)
    static var particle: String {
        get { UserDefaults.standard.string(forKey: "politeParticle") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "politeParticle")
            NotificationCenter.default.post(name: Settings.changed, object: nil)
        }
    }

    /// แอปที่เปิดอยู่ตอนนี้ (ไว้ให้เลือกตั้งโทน)
    static func runningApps() -> [(name: String, bundleID: String)] {
        let own = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let id = app.bundleIdentifier, id != own, let name = app.localizedName, seen.insert(id).inserted else { return nil }
                return (name, id)
            }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }
}

// MARK: - สถิติแบบขี้เล่น

struct DayStat: Codable {
    var words = 0
    var dictations = 0
    var speakingSeconds: Double = 0
}

enum Stats {
    private static let key = "stats"
    /// ความเร็วพิมพ์เฉลี่ย (คำ/นาที) ไว้คำนวณเวลาที่ประหยัดได้
    static let typingWPM = 40.0

    private static var dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static var days: [String: DayStat] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let d = try? JSONDecoder().decode([String: DayStat].self, from: data) else { return [:] }
        return d
    }

    /// นับคำแบบเข้าใจภาษาไทย (ไทยไม่มีเว้นวรรค ใช้ตัวตัดคำของระบบ)
    static func wordCount(_ text: String) -> Int {
        var n = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in n += 1 }
        return n
    }

    static func record(_ text: String, speakingSeconds: Double) {
        var all = days
        let k = dayFormatter.string(from: Date())
        var d = all[k] ?? DayStat()
        d.words += wordCount(text)
        d.dictations += 1
        d.speakingSeconds += max(0, speakingSeconds)
        all[k] = d
        // เก็บแค่ 400 วันล่าสุด
        if all.count > 400 { for old in all.keys.sorted().prefix(all.count - 400) { all[old] = nil } }
        UserDefaults.standard.set(try? JSONEncoder().encode(all), forKey: key)
        NotificationCenter.default.post(name: Settings.changed, object: nil)
    }

    /// ครั้งแรกที่มีฟีเจอร์สถิติ: นับย้อนจากประวัติที่มีอยู่ (ไม่รู้เวลาพูด เลยนับแค่คำ)
    static func seedFromHistoryIfNeeded() {
        guard UserDefaults.standard.data(forKey: key) == nil else { return }
        let items = History.items
        guard !items.isEmpty else { return }
        var all: [String: DayStat] = [:]
        for it in items {
            let k = dayFormatter.string(from: it.date)
            var d = all[k] ?? DayStat()
            d.words += wordCount(it.text)
            d.dictations += 1
            // ประมาณเวลาพูด ~150 คำ/นาที
            d.speakingSeconds += Double(wordCount(it.text)) / 150 * 60
            all[k] = d
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(all), forKey: key)
    }

    static var today: DayStat { days[dayFormatter.string(from: Date())] ?? DayStat() }

    static var totalWords: Int { days.values.reduce(0) { $0 + $1.words } }

    /// นาทีที่ประหยัดได้เทียบกับพิมพ์เอง
    static func savedMinutes(_ d: DayStat) -> Double {
        max(0, Double(d.words) / typingWPM - d.speakingSeconds / 60)
    }

    static var totalSavedMinutes: Double { days.values.reduce(0) { $0 + savedMinutes($1) } }

    /// ใช้ติดต่อกันกี่วัน (นับวันนี้ ถ้าวันนี้ยังไม่ได้ใช้ก็นับถึงเมื่อวาน)
    static var streak: Int {
        let all = days
        let cal = Calendar(identifier: .gregorian)
        var day = Date()
        if all[dayFormatter.string(from: day)] == nil { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while all[dayFormatter.string(from: day)] != nil {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    /// คำแซว/ชมจากมาสคอตตามสถิติ
    static var mascotComment: String {
        let t = today, s = streak
        if t.dictations == 0 { return s > 0 ? "ยังไม่พูดเลยวันนี้ เดี๋ยวสถิติ \(s) วันขาดนะ!" : "วันนี้ยังไม่ได้พูดเลย ลองดิ!" }
        if t.words > 2000 { return "วันนี้พูดไป \(t.words) คำ ปากไม่เมื่อยเหรอ!" }
        if s >= 7 { return "ใช้ติดกัน \(s) วันแล้ว นิ้วได้พักเยอะเลย" }
        if t.words > 300 { return "ไปได้สวย! ประหยัดเวลาพิมพ์ไปแล้ว" }
        return "เริ่มได้ดี พูดต่อเลย!"
    }
}

// MARK: - ข้อความที่ผู้ใช้เลือกไว้ (ไว้ “พูดสั่งแก้”)

enum Selection {
    /// อ่านข้อความที่ไฮไลต์อยู่ในแอปที่ใช้งาน ผ่าน Accessibility
    /// (ใช้ได้กับแอปส่วนใหญ่ที่รายงานข้อความที่เลือก เช่น Notes, Mail, Pages, TextEdit, Safari)
    static func current() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }
        var value: AnyObject?
        // swiftlint:disable:next force_cast
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}

// MARK: - จัดรูปแบบภาษาไทย

enum ThaiText {
    /// ไม้ยมก (ๆ) เว้นวรรคทั้งหน้าและหลังตามหลักราชบัณฑิตยสถาน เช่น “เด็ก ๆ ชอบ”
    /// ยกเว้นท้ายบรรทัด หรือติดเครื่องหมายวรรคตอน ไม่ต้องเว้นหลัง
    static func fixMaiYamok(_ text: String) -> String {
        guard text.contains("ๆ") else { return text }
        var t = text
        // หน้าไม้ยมก: เว้น 1 วรรคพอดี (ยกเว้นต้นบรรทัด)
        t = t.replacingOccurrences(of: "(?<=\\S)[ \\t]*ๆ", with: " ๆ", options: .regularExpression)
        // หลังไม้ยมก: เว้น 1 วรรค ถ้าตามด้วยตัวหนังสือ (ไม่ใช่ช่องว่าง/ขึ้นบรรทัด/เครื่องหมาย)
        t = t.replacingOccurrences(of: "ๆ[ \\t]*(?=[^\\s.,!?;:)\\]}”’\"'…])", with: "ๆ ", options: .regularExpression)
        // ไม้ยมกตามด้วยเครื่องหมาย: ไม่เว้น
        t = t.replacingOccurrences(of: "ๆ[ \\t]+(?=[.,!?;:)\\]}”’\"'…])", with: "ๆ", options: .regularExpression)
        return t
    }
}

// MARK: - ภาษาที่พูด (บอก Gemini ล่วงหน้า กันเดาเป็นภาษาอื่น เช่น จีน/เวียดนาม)

struct SpokenLanguage: Identifiable, Equatable {
    let code: String     // รหัส BCP-47 ที่ Gemini Live รับ
    let name: String     // ชื่อไทย
    let english: String  // ชื่ออังกฤษ (ใส่ในคำสั่งให้ AI)
    var id: String { code }

    static let all: [SpokenLanguage] = [
        .init(code: "th-TH", name: "ไทย", english: "Thai"),
        .init(code: "en-US", name: "อังกฤษ", english: "English"),
        .init(code: "ja-JP", name: "ญี่ปุ่น", english: "Japanese"),
        .init(code: "zh-CN", name: "จีน", english: "Chinese"),
        .init(code: "ko-KR", name: "เกาหลี", english: "Korean"),
        .init(code: "vi-VN", name: "เวียดนาม", english: "Vietnamese"),
        .init(code: "lo-LA", name: "ลาว", english: "Lao"),
        .init(code: "my-MM", name: "พม่า", english: "Burmese"),
    ]

    static let defaults = ["th-TH", "en-US"]

    /// ภาษาที่ผู้ใช้เลือก (อย่างน้อย 1)
    static var selected: [String] {
        get {
            let list = UserDefaults.standard.stringArray(forKey: "spokenLanguages") ?? defaults
            let valid = list.filter { c in all.contains { $0.code == c } }
            return valid.isEmpty ? defaults : valid
        }
        set {
            UserDefaults.standard.set(newValue.isEmpty ? defaults : newValue, forKey: "spokenLanguages")
            NotificationCenter.default.post(name: Settings.changed, object: nil)
        }
    }

    static var selectedEnglishNames: [String] {
        selected.compactMap { c in all.first { $0.code == c }?.english }
    }

    /// ข้อความมีตัวอักษรของภาษาที่ผู้ใช้ไม่ได้เลือกไหม (ด่านสุดท้ายกันหลุดเป็นจีน/ญี่ปุ่น/เกาหลี/เวียดนาม)
    static func hasUnexpectedScript(_ text: String) -> Bool {
        let sel = Set(selected)
        for u in text.unicodeScalars {
            switch u.value {
            case 0x4E00...0x9FFF, 0x3400...0x4DBF:                 // อักษรจีน (คันจิ)
                if !sel.contains("zh-CN") && !sel.contains("ja-JP") { return true }
            case 0x3040...0x30FF:                                  // ฮิรางานะ/คาตาคานะ
                if !sel.contains("ja-JP") { return true }
            case 0xAC00...0xD7AF, 0x1100...0x11FF:                 // ฮันกึล
                if !sel.contains("ko-KR") { return true }
            case 0x1EA0...0x1EF9, 0x0102, 0x0103, 0x0110, 0x0111, 0x01A0, 0x01A1, 0x01AF, 0x01B0: // ตัวอักษรเวียดนาม
                if !sel.contains("vi-VN") { return true }
            case 0x0E80...0x0EFF:                                  // ลาว
                if !sel.contains("lo-LA") { return true }
            case 0x1000...0x109F:                                  // พม่า
                if !sel.contains("my-MM") { return true }
            default: break
            }
        }
        return false
    }
}
