import AppKit

/// ประวัติข้อความที่พูดล่าสุด (เก็บ 20 รายการในเครื่อง) เผื่อพิมพ์ผิดช่องจะได้ก๊อปกลับมาใช้
struct HistoryItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var date: Date
    var app: String?
}

enum History {
    static let limit = 20
    private static let key = "history"

    static var items: [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return [] }
        return list
    }

    static func add(_ text: String, app: String?) {
        var list = items
        list.insert(HistoryItem(text: text, date: Date(), app: app), at: 0)
        save(Array(list.prefix(limit)))
    }

    static func clear() { save([]) }

    static func copy(_ item: HistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }

    private static func save(_ list: [HistoryItem]) {
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
        NotificationCenter.default.post(name: Settings.changed, object: nil)
    }

    static func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "เมื่อกี้" }
        if s < 3600 { return "\(s / 60) นาทีก่อน" }
        if s < 86_400 { return "\(s / 3600) ชม.ก่อน" }
        return "\(s / 86_400) วันก่อน"
    }
}
