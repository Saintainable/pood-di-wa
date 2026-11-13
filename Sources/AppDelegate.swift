import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum State { case idle, holding, handsFree, finishing }

    private let settings = Settings.shared
    private let hotkeys = HotkeyMonitor()
    private let speech = SpeechEngine()      // engine: Apple
    private let live = LiveTranscriber()     // engine: Gemini
    private let hud = HUDController()
    private let onboarding = OnboardingWindowController()

    private var statusItem: NSStatusItem!
    private var state: State = .idle { didSet { updateStatusIcon() } }
    private var activeEngine: Engine = .gemini
    private var pressedAt = Date()
    private var targetApp: String?
    private var lastPCM: Data?
    private var axWasGranted = false
    private var axTimer: Timer?

    /// แตะสั้นกว่านี้ = เข้าโหมดพูดยาว
    private let tapThreshold: TimeInterval = 0.35

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateStatusIcon()

        hotkeys.hotkey = settings.hotkey
        hotkeys.onPress = { [weak self] in self?.hotkeyPressed() }
        hotkeys.onRelease = { [weak self] in self?.hotkeyReleased() }
        hotkeys.onOtherKey = { [weak self] in self?.otherKeyDuringHold() }
        hotkeys.onEscape = { [weak self] in self?.cancelRecording() }
        hotkeys.start()
        NotificationCenter.default.addObserver(forName: Settings.changed, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if !self.settings.enabled { self.cancelRecording() }
            self.updateStatusIcon()
        }

        speech.onPartial = { [weak self] text in self?.hud.model.text = text }
        speech.onLevel = { [weak self] level in self?.hud.model.level = CGFloat(level) }
        live.onLevel = { [weak self] level in self?.hud.model.level = CGFloat(level) }
        live.onPartial = { [weak self] text in self?.hud.model.text = text }

        // ถ้าเพิ่งได้สิทธิ์ Accessibility ต้องติดตั้งตัวฟังปุ่มใหม่
        axWasGranted = Permissions.accessibilityGranted
        axTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = Permissions.accessibilityGranted
            if now && !self.axWasGranted { self.hotkeys.start() }
            self.axWasGranted = now
        }

        if !Permissions.allGranted {
            onboarding.show()
        }
    }

    /// ดับเบิลคลิกแอปซ้ำ (เช่นตอนไอคอนบนแถบเมนูถูกรอยบากจอบัง) → เปิดหน้าตั้งค่า
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        onboarding.show()
        return true
    }

    /// แอปแถบเมนูไม่มีเมนู Edit — ต้องใส่เองเพื่อให้ ⌘V / ⌘C / ⌘A ใช้ในช่องกรอก key ได้
    private func installEditMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "ปิดหน้าต่าง", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "ออกจากพูดดิวะ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    // MARK: - Hotkey state machine

    private func hotkeyPressed() {
        guard settings.enabled else { return }
        switch state {
        case .idle:
            pressedAt = Date()
            startRecording(handsFree: false)
        case .handsFree:
            finishRecording()
        default:
            break
        }
    }

    private func hotkeyReleased() {
        guard state == .holding else { return }
        if Date().timeIntervalSince(pressedAt) < tapThreshold {
            state = .handsFree
            hud.model.phase = .handsFree
        } else {
            finishRecording()
        }
    }

    private func otherKeyDuringHold() {
        // ผู้ใช้กด ⌥ + ปุ่มอื่น = ใช้คีย์ลัดปกติ ไม่ได้ตั้งใจพูด
        if state == .holding { cancelRecording() }
    }

    // MARK: - Recording

    private func startRecording(handsFree: Bool) {
        let engine = settings.engine
        guard Permissions.micGranted else { onboarding.show(); return }
        switch engine {
        case .apple:
            guard Permissions.speechGranted else { onboarding.show(); return }
        case .gemini:
            guard settings.hasGeminiKey else {
                hud.flash("ใส่ Gemini API key ก่อน (ฟรี)")
                onboarding.show()
                return
            }
        }

        do {
            switch engine {
            case .apple: try speech.start(language: settings.language)
            case .gemini:
                live.vocabulary = settings.vocabulary
                try live.start(apiKey: settings.geminiKey ?? "")
            }
        } catch {
            hud.flash(error.localizedDescription)
            return
        }
        activeEngine = engine
        targetApp = NSWorkspace.shared.frontmostApplication?.localizedName
        state = handsFree ? .handsFree : .holding
        hud.model.hotkeyShort = settings.hotkey.short
        hud.model.text = ""
        hud.model.showText = settings.showLiveText
        hud.model.level = 0
        hud.model.phase = handsFree ? .handsFree : .listening
        hud.show()
        playSound("Tink")
    }

    private func finishRecording() {
        guard state == .holding || state == .handsFree else { return }
        state = .finishing
        hud.model.phase = .processing
        hud.model.level = 0

        switch activeEngine {
        case .apple:
            speech.stop { [weak self] text in self?.deliver(text) }
        case .gemini:
            if live.duration < 0.4 {
                live.cancel()
                state = .idle
                hud.flash("สั้นไปหน่อย กดค้างแล้วพูดได้เลย")
                return
            }
            let releasedAt = Date()
            live.stop { [weak self] result in
                guard let self else { return }
                self.lastPCM = self.live.pcm
                switch result {
                case .success(let live):
                    Log.write(String(format: "release→text %.2fs", Date().timeIntervalSince(releasedAt)))
                    self.refineIfNeeded(live)
                case .failure(let error):
                    // Live ล่ม — ส่งแบบไฟล์แทน (ช้ากว่า แต่ได้ผล)
                    Log.write("live failed → file fallback: \(error.localizedDescription)")
                    if self.live.duration >= 0.8 {
                        self.sendFile(self.live.pcm)
                    } else {
                        self.deliver("")
                    }
                }
            }
        }
    }

    /// ถ้าพูดคำสั่ง (แปล / ทำเป็นข้อ) ค่อยส่งตัวหนังสือไปทำตามคำสั่งอีกรอบ ไม่งั้นพิมพ์เลย
    private func refineIfNeeded(_ live: LiveResult) {
        let (text, refine) = GeminiClient.decide(live, vocabulary: settings.vocabulary)
        guard refine, let key = settings.geminiKey else { deliver(text); return }
        hud.model.phase = .processing
        let started = Date()
        GeminiClient.refineFast(live, apiKey: key, model: settings.geminiModel, targetApp: targetApp) { [weak self] result in
            Log.write(String(format: "refine total %.2fs", Date().timeIntervalSince(started)))
            switch result {
            case .success(let refined): self?.deliver(refined.isEmpty ? text : refined)
            case .failure: self?.deliver(text) // เรียบเรียงไม่ได้ ก็ใช้ข้อความดิบ
            }
        }
    }

    private func sendFile(_ pcm: Data) {
        guard let key = settings.geminiKey else { state = .idle; return }
        state = .finishing
        hud.model.phase = .processing
        hud.show()
        GeminiClient.transcribe(audio: LiveTranscriber.wav(from: pcm), mimeType: "audio/wav", apiKey: key,
                                model: settings.geminiModel, targetApp: targetApp) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let text):
                self.deliver(text)
            case .failure(let error):
                self.state = .idle
                self.hud.flash(error.localizedDescription)
            }
        }
    }

    private func deliver(_ text: String) {
        state = .idle
        if text.isEmpty {
            hud.flash("ไม่ได้ยินเสียงพูด ลองใหม่อีกที")
            return
        }
        History.add(text, app: targetApp)
        if Permissions.accessibilityGranted {
            TextInserter.insert(text, keepInClipboard: settings.keepInClipboard)
            hud.hide(after: 0.15)
        } else {
            // ยังพิมพ์แทนไม่ได้ ก็ใส่คลิปบอร์ดไว้ให้วางเอง
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            hud.flash("คัดลอกแล้ว กด ⌘V เพื่อวาง (ยังไม่ได้ให้สิทธิ์ Accessibility)")
        }
        playSound("Pop")
    }

    private func cancelRecording() {
        guard state == .holding || state == .handsFree else { return }
        switch activeEngine {
        case .apple: speech.cancel()
        case .gemini: live.cancel()
        }
        state = .idle
        hud.hide()
    }

    private func playSound(_ name: String) {
        guard settings.playSounds else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: - Status bar

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let recording = state != .idle
        let name = !settings.enabled ? "mic.slash.circle" : recording ? "waveform.circle.fill" : "waveform.circle"
        var image = NSImage(systemSymbolName: name, accessibilityDescription: "พูดดิวะ")
        if recording {
            let config = NSImage.SymbolConfiguration(paletteColors: [.white, Brand.orange])
            image = image?.withSymbolConfiguration(config)
            image?.isTemplate = false
        } else {
            image?.isTemplate = true
        }
        button.image = image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let power = NSMenuItem(title: settings.enabled ? "เปิดรับเสียงอยู่ — กด \(settings.hotkey.short) ค้างแล้วพูด" : "ปิดรับเสียงอยู่",
                               action: #selector(togglePower), keyEquivalent: "")
        power.target = self
        power.state = settings.enabled ? .on : .off
        menu.addItem(power)

        if !Permissions.allGranted {
            let warn = NSMenuItem(title: "ยังตั้งค่าไม่ครบ — คลิกเพื่อตั้งค่า", action: #selector(showOnboarding), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        }

        let toggleTitle = state == .idle ? "เริ่มพูด (โหมดพูดยาว)" : "หยุดและพิมพ์"
        let toggle = NSMenuItem(title: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let recent = History.items
        if !recent.isEmpty {
            let parent = NSMenuItem(title: "พูดล่าสุด (คลิกเพื่อคัดลอก)", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for item in recent {
                let short = item.text.replacingOccurrences(of: "\n", with: " ")
                let title = short.count > 48 ? String(short.prefix(48)) + "…" : short
                let mi = NSMenuItem(title: title, action: #selector(copyHistory(_:)), keyEquivalent: "")
                mi.target = self
                mi.representedObject = item.id.uuidString
                mi.toolTip = item.text
                sub.addItem(mi)
            }
            sub.addItem(.separator())
            let clear = NSMenuItem(title: "ล้างประวัติ", action: #selector(clearHistory), keyEquivalent: "")
            clear.target = self
            sub.addItem(clear)
            parent.submenu = sub
            menu.addItem(parent)
        }

        if lastPCM != nil, settings.engine == .gemini {
            let retry = NSMenuItem(title: "ส่งเสียงล่าสุดไปแปลงอีกครั้ง", action: #selector(retryLast), keyEquivalent: "")
            retry.target = self
            retry.isEnabled = state == .idle
            menu.addItem(retry)
        }

        menu.addItem(.separator())

        menu.addItem(submenu(title: "ตัวแปลงเสียง: \(settings.engine == .gemini ? "Gemini" : "Apple")",
                             items: Engine.allCases.map { ($0.title, $0.rawValue, $0 == settings.engine) },
                             action: #selector(selectEngine(_:))))

        if settings.engine == .gemini {
            menu.addItem(submenu(title: "รุ่นที่ใช้ทำตามคำสั่ง (แปล/จัดข้อ)",
                                 items: GeminiModel.allCases.map { ($0.title, $0.rawValue, $0 == settings.geminiModel) },
                                 action: #selector(selectModel(_:))))
        } else {
            menu.addItem(submenu(title: "ภาษา: \(settings.language.title)",
                                 items: Language.allCases.map { ($0.title, $0.rawValue, $0 == settings.language) },
                                 action: #selector(selectLanguage(_:))))
        }

        menu.addItem(submenu(title: "ปุ่มลัด: \(settings.hotkey.title)",
                             items: Hotkey.allCases.map { ($0.title, $0.rawValue, $0 == settings.hotkey) },
                             action: #selector(selectHotkey(_:))))

        let sound = NSMenuItem(title: "เสียงแจ้งเตือน", action: #selector(toggleSounds), keyEquivalent: "")
        sound.target = self
        sound.state = settings.playSounds ? .on : .off
        menu.addItem(sound)

        let live = NSMenuItem(title: "โชว์คำที่พูดสด ๆ", action: #selector(toggleLiveText), keyEquivalent: "")
        live.target = self
        live.state = settings.showLiveText ? .on : .off
        menu.addItem(live)

        let clip = NSMenuItem(title: "เก็บข้อความไว้ในคลิปบอร์ดด้วย", action: #selector(toggleClipboard), keyEquivalent: "")
        clip.target = self
        clip.state = settings.keepInClipboard ? .on : .off
        menu.addItem(clip)

        let login = NSMenuItem(title: "เปิดอัตโนมัติเมื่อเปิดเครื่อง", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let help = NSMenuItem(title: "ตั้งค่า, API key และวิธีใช้…", action: #selector(showOnboarding), keyEquivalent: ",")
        help.target = self
        menu.addItem(help)

        let quit = NSMenuItem(title: "ออกจากพูดดิวะ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func submenu(title: String, items: [(String, String, Bool)], action: Selector) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (label, raw, on) in items {
            let item = NSMenuItem(title: label, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = raw
            item.state = on ? .on : .off
            sub.addItem(item)
        }
        parent.submenu = sub
        return parent
    }

    // MARK: - Menu actions

    @objc private func toggleFromMenu() {
        guard settings.enabled else { return }
        switch state {
        case .idle: startRecording(handsFree: true)
        case .holding, .handsFree: finishRecording()
        case .finishing: break
        }
    }

    @objc private func retryLast() {
        guard state == .idle, let pcm = lastPCM else { return }
        sendFile(pcm)
    }

    @objc private func selectEngine(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let e = Engine(rawValue: raw) else { return }
        settings.engine = e
        if !Permissions.allGranted { onboarding.show() }
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let m = GeminiModel(rawValue: raw) {
            settings.geminiModel = m
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let lang = Language(rawValue: raw) {
            settings.language = lang
        }
    }

    @objc private func selectHotkey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let hk = Hotkey(rawValue: raw) else { return }
        settings.hotkey = hk
        hotkeys.hotkey = hk
        if hk == .fn {
            let alert = NSAlert()
            alert.messageText = "ใช้ปุ่ม fn (ปุ่มลูกโลก)"
            alert.informativeText = "ไปที่ System Settings → Keyboard แล้วตั้ง “Press fn key to” เป็น “Do Nothing” ก่อน ไม่งั้นจะมีหน้าต่างอีโมจิหรือ Dictation ของ Apple เด้งขึ้นมาด้วย"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func toggleSounds() { settings.playSounds.toggle() }
    @objc private func toggleClipboard() { settings.keepInClipboard.toggle() }
    @objc private func toggleLiveText() { settings.showLiveText.toggle() }
    @objc private func togglePower() { settings.enabled.toggle() }
    @objc private func clearHistory() { History.clear() }

    @objc private func copyHistory(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let item = History.items.first(where: { $0.id.uuidString == id }) else { return }
        History.copy(item)
        hud.flash("คัดลอกแล้ว")
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            hud.flash("ตั้งค่าเปิดอัตโนมัติไม่สำเร็จ")
        }
    }

    @objc private func showOnboarding() { onboarding.show() }
}
