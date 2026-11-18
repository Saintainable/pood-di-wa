import AppKit
import SwiftUI
import Combine

/// สถานะที่หน้าต่างพูดดิวะแสดง — มีชีวิตเฉพาะตอนหน้าต่างเปิด (ปิดแล้วหยุดทุกอย่าง)
final class PermissionState: ObservableObject {
    @Published var mic = Permissions.micGranted
    @Published var speech = Permissions.speechGranted
    @Published var accessibility = Permissions.accessibilityGranted
    @Published var shortcut = Settings.shared.shortcut
    @Published var triggerMode = Settings.shared.triggerMode
    @Published var holdOn = Settings.shared.holdEnabled
    @Published var tapOn = Settings.shared.tapEnabled
    @Published var shortcutFailed = HotkeyMonitor.lastRegistrationFailed
    @Published var engine = Settings.shared.engine
    @Published var model = Settings.shared.geminiModel
    @Published var hasKey = Settings.shared.hasGeminiKey
    @Published var showLiveText = Settings.shared.showLiveText
    @Published var playSounds = Settings.shared.playSounds
    @Published var keepInClipboard = Settings.shared.keepInClipboard
    @Published var enabled = Settings.shared.enabled
    @Published var vocab: [String] = Settings.shared.vocabulary
    @Published var history: [HistoryItem] = History.items
    @Published var snippets: [Snippet] = Snippets.all
    @Published var toneRules: [AppToneRule] = AppTones.rules
    @Published var particle = AppTones.particle
    @Published var languages = SpokenLanguage.selected
    @Published var today = Stats.today
    @Published var streak = Stats.streak
    @Published var totalSaved = Stats.totalSavedMinutes
    @Published var keyStatus: String = ""
    @Published var keyOK: Bool? = nil
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    init() {
        // สิทธิ์ของระบบไม่มีแจ้งเตือนตอนเปลี่ยน — เช็กทุกวินาทีขณะหน้าต่างเปิด
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refreshPermissions() }
        timer?.tolerance = 0.3
        // ค่าที่แอปเปลี่ยนเอง (ประวัติ สถิติ ปุ่มลัด) อัปเดตทันทีตอนเปลี่ยน
        observer = NotificationCenter.default.addObserver(forName: Settings.changed, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        if hasKey { keyStatus = "บันทึก key ไว้แล้ว" }
    }

    deinit { stop() }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        observer = nil
    }

    private func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<PermissionState, T>, _ v: T) {
        if self[keyPath: kp] != v { self[keyPath: kp] = v }
    }

    /// แจ้ง SwiftUI เฉพาะค่าที่เปลี่ยนจริง — ไม่ให้ทั้งหน้าวาดใหม่ทุกวินาที
    func refreshPermissions() {
        set(\.mic, Permissions.micGranted)
        set(\.speech, Permissions.speechGranted)
        set(\.accessibility, Permissions.accessibilityGranted)
        set(\.shortcutFailed, HotkeyMonitor.lastRegistrationFailed)
    }

    func refresh() {
        refreshPermissions()
        let s = Settings.shared
        set(\.shortcut, s.shortcut)
        set(\.triggerMode, s.triggerMode)
        set(\.holdOn, s.holdEnabled)
        set(\.tapOn, s.tapEnabled)
        set(\.engine, s.engine)
        set(\.hasKey, s.hasGeminiKey)
        set(\.showLiveText, s.showLiveText)
        set(\.playSounds, s.playSounds)
        set(\.keepInClipboard, s.keepInClipboard)
        set(\.enabled, s.enabled)
        set(\.history, History.items)
        set(\.snippets, Snippets.all)
        set(\.toneRules, AppTones.rules)
        set(\.particle, AppTones.particle)
        set(\.languages, SpokenLanguage.selected)
        let t = Stats.today
        if t.words != today.words || t.dictations != today.dictations { today = t }
        set(\.streak, Stats.streak)
        set(\.totalSaved, Stats.totalSavedMinutes)
    }

    var all: Bool { Permissions.allGranted }

    // MARK: ตั้งค่า

    func setEnabled(_ on: Bool) { Settings.shared.enabled = on; enabled = on }
    func setShortcut(_ sc: Shortcut) { Settings.shared.shortcut = sc; shortcut = sc }
    func setHold(_ on: Bool) { Settings.shared.holdEnabled = on; refresh() }
    func setTap(_ on: Bool) { Settings.shared.tapEnabled = on; refresh() }
    func setShowLiveText(_ on: Bool) { Settings.shared.showLiveText = on; showLiveText = on }
    func setPlaySounds(_ on: Bool) { Settings.shared.playSounds = on; playSounds = on }
    func setKeepInClipboard(_ on: Bool) { Settings.shared.keepInClipboard = on; keepInClipboard = on }
    func setEngine(_ e: Engine) { Settings.shared.engine = e; engine = e }
    func setModel(_ m: GeminiModel) { Settings.shared.geminiModel = m; model = m }
    func setParticle(_ p: String) { AppTones.particle = p; particle = p }

    /// เลือก/ไม่เลือกภาษา — ต้องเหลืออย่างน้อย 1 ภาษา
    func toggleLanguage(_ code: String) {
        var list = languages
        if let i = list.firstIndex(of: code) {
            guard list.count > 1 else { return }
            list.remove(at: i)
        } else {
            list.append(code)
        }
        SpokenLanguage.selected = list
        languages = SpokenLanguage.selected
    }

    func saveKey(_ key: String) {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        Settings.shared.geminiKey = k
        hasKey = true
        keyOK = nil
        keyStatus = "กำลังตรวจ key…"
        GeminiClient.validate(apiKey: k) { [weak self] ok in
            self?.keyOK = ok
            switch ok {
            case true?: self?.keyStatus = "key ใช้งานได้"
            case false?: self?.keyStatus = "key ไม่ถูกต้อง ลองก๊อปใหม่อีกครั้ง"
            case nil: self?.keyStatus = "บันทึกแล้ว (ตรวจออนไลน์ไม่ได้ตอนนี้)"
            }
        }
    }

    // MARK: คำเฉพาะ

    /// เพิ่มคำ (วางหลายคำคั่นด้วย , หรือขึ้นบรรทัดใหม่ได้) — คืนจำนวนที่เพิ่มจริง
    @discardableResult
    func addVocab(_ input: String) -> Int {
        let new = input.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var list = vocab
        var added = 0
        for w in new where !list.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
            list.insert(w, at: 0)
            added += 1
        }
        if added > 0 { setVocabList(list) }
        return added
    }

    func removeVocab(_ word: String) { setVocabList(vocab.filter { $0 != word }) }

    func setVocabList(_ list: [String]) {
        Settings.shared.vocabularyText = list.joined(separator: "\n")
        vocab = Settings.shared.vocabulary
    }

    // MARK: คำย่อ / โทน

    func saveSnippets(_ list: [Snippet]) { snippets = list; Snippets.save(list) }
    func saveToneRules(_ list: [AppToneRule]) { toneRules = list; AppTones.save(list) }
}
