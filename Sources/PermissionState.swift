import AppKit
import SwiftUI
import Combine

final class PermissionState: ObservableObject {
    @Published var mic = Permissions.micGranted
    @Published var speech = Permissions.speechGranted
    @Published var accessibility = Permissions.accessibilityGranted
    @Published var hotkey = Settings.shared.hotkey
    @Published var engine = Settings.shared.engine
    @Published var model = Settings.shared.geminiModel
    @Published var hasKey = Settings.shared.hasGeminiKey
    @Published var showLiveText = Settings.shared.showLiveText
    @Published var enabled = Settings.shared.enabled
    @Published var vocab: [String] = Settings.shared.vocabulary
    @Published var history: [HistoryItem] = History.items
    @Published var keyStatus: String = ""
    @Published var keyOK: Bool? = nil
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refresh() }
        if hasKey { keyStatus = "บันทึก key ไว้แล้ว" }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        mic = Permissions.micGranted
        speech = Permissions.speechGranted
        accessibility = Permissions.accessibilityGranted
        hotkey = Settings.shared.hotkey
        engine = Settings.shared.engine
        hasKey = Settings.shared.hasGeminiKey
        showLiveText = Settings.shared.showLiveText
        if enabled != Settings.shared.enabled { enabled = Settings.shared.enabled }
        let h = History.items
        if h != history { history = h }
    }

    func setEnabled(_ on: Bool) {
        Settings.shared.enabled = on
        enabled = on
    }

    /// เพิ่มคำ (วางหลายคำคั่นด้วย , หรือขึ้นบรรทัดใหม่ได้) — คืนจำนวนที่เพิ่มจริง
    @discardableResult
    func addVocab(_ input: String) -> Int {
        let new = input.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var list = vocab
        var added = 0
        for w in new where !list.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
            list.insert(w, at: 0) // คำใหม่อยู่หน้าสุด
            added += 1
        }
        if added > 0 { setVocabList(list) }
        return added
    }

    func removeVocab(_ word: String) {
        setVocabList(vocab.filter { $0 != word })
    }

    func setVocabList(_ list: [String]) {
        Settings.shared.vocabularyText = list.joined(separator: "\n")
        vocab = Settings.shared.vocabulary
    }

    func setShowLiveText(_ on: Bool) {
        Settings.shared.showLiveText = on
        showLiveText = on
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

    func setEngine(_ e: Engine) {
        Settings.shared.engine = e
        engine = e
    }

    func setModel(_ m: GeminiModel) {
        Settings.shared.geminiModel = m
        model = m
    }

    var all: Bool { Permissions.allGranted }
}
