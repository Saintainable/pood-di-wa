import AppKit
import SwiftUI
import ServiceManagement

// MARK: - หน้าตั้งค่า — ของที่ใช้บ่อยอยู่บน ของยากพับไว้ใน “ขั้นสูง”

struct SettingsPage: View {
    @ObservedObject var state: PermissionState
    var openSetup: () -> Void
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("ตั้งค่า").font(Brand.font(26, .bold)).foregroundColor(.white)
                    .padding(.top, 50)

                if !state.all {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Color(nsColor: Brand.amber))
                        Text("ยังตั้งค่าไม่ครบ — ให้พูดดิวะพาทำทีละขั้นได้เลย").font(Brand.font(13, .semibold)).foregroundColor(.white)
                        Spacer()
                        Button("ตั้งค่าทีละขั้น", action: openSetup).buttonStyle(HotButtonStyle(compact: true))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: Brand.amber).opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(nsColor: Brand.amber).opacity(0.35)))
                }

                shortcutCard
                languageCard
                soundCard
                toneCard
                snippetCard
                VocabularyCard(state: state)
                permissionsCard
                advancedCard
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: ปุ่มลัด

    private var shortcutCard: some View {
        Card(title: "ปุ่มลัด") {
            ShortcutRecorder(current: state.shortcut) { state.setShortcut($0) }
            if state.shortcutFailed && state.shortcut.kind == .combo {
                warn("ปุ่มนี้มีแอปอื่นจองไว้แล้ว เลือกปุ่มอื่นนะ")
            } else if let c = state.shortcut.conflict {
                warn(c)
            }
            Divider().overlay(Brand.line)
            toggleRow(icon: "hand.tap.fill", "กดค้างแล้วพูด", "ค้างไว้ระหว่างพูด ปล่อยแล้วพิมพ์ให้",
                      Binding(get: { state.holdOn }, set: { state.setHold($0) }))
            toggleRow(icon: "infinity", "แตะเพื่อพูดยาว", "แตะทีเดียวแล้วพูดได้เรื่อย ๆ แตะอีกทีเมื่อจบ",
                      Binding(get: { state.tapOn }, set: { state.setTap($0) }))
            Text("ปิดได้ทีละอัน แต่ต้องเปิดไว้อย่างน้อย 1 อัน · กด esc เพื่อยกเลิกระหว่างพูด")
                .font(Brand.font(11)).foregroundColor(Brand.muted)
        }
    }

    private func warn(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(Color(nsColor: Brand.amber))
            Text(text).font(Brand.font(11.5)).foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: ภาษาที่พูด

    private var languageCard: some View {
        Card(title: "ภาษาที่พูด") {
            Text("เลือกเฉพาะภาษาที่พูดจริง จะถอดแม่นขึ้น และไม่หลุดเป็นภาษาอื่น (สั่งแปลได้เหมือนเดิม)")
                .font(Brand.font(11.5)).foregroundColor(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8) {
                ForEach(SpokenLanguage.all) { lang in
                    let on = state.languages.contains(lang.code)
                    Button { state.toggleLanguage(lang.code) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: on ? "checkmark" : "plus")
                                .font(.system(size: 10, weight: .heavy))
                            Text(lang.name).font(Brand.font(13, .semibold))
                        }
                        .foregroundColor(on ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(on ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.white.opacity(0.07))))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(on ? 0.2 : 0.1)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(on && state.languages.count == 1 ? "ต้องเลือกไว้อย่างน้อย 1 ภาษา" : "")
                }
            }
            if state.engine == .apple {
                Text("แบบ Apple ใช้ภาษาเดียวตามที่ตั้งในขั้นสูง").font(Brand.font(11)).foregroundColor(Brand.muted)
            }
        }
    }

    // MARK: เสียง / แสดงผล

    private var soundCard: some View {
        Card(title: "เสียงและหน้าจอ") {
            toggleRow(icon: "speaker.wave.2.fill", "เสียงตอนเริ่ม / จบ", "เสียงติ๊งเบา ๆ บอกว่ากำลังฟังและพิมพ์เสร็จแล้ว",
                      Binding(get: { state.playSounds }, set: { state.setPlaySounds($0) }))
            toggleRow(icon: "text.bubble.fill", "โชว์คำที่พูดสด ๆ", "แถบด้านล่างจอยืดออก มีข้อความวิ่งระหว่างพูด",
                      Binding(get: { state.showLiveText }, set: { state.setShowLiveText($0) }))
        }
    }

    /// แถวสวิตช์ + ไอคอน (เปิด = ส้ม-แดง · ปิด = เทา)
    private func toggleRow(icon: String, _ title: String, _ detail: String, _ on: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(on.wrappedValue ? .white : .white.opacity(0.5))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(on.wrappedValue ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.white.opacity(0.07))))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Brand.font(13, .bold)).foregroundColor(.white)
                Text(detail).font(Brand.font(11)).foregroundColor(Brand.muted)
            }
            Spacer()
            Toggle("", isOn: on).toggleStyle(.switch).tint(Color(nsColor: Brand.orange)).labelsHidden()
        }
    }

    // MARK: โทนตามแอป

    private var toneCard: some View {
        Card(title: "โทนตามแอป") {
            Text("พูดแบบเดิม แต่ได้ภาษาที่เหมาะกับแอป เช่น LINE กันเอง · อีเมลทางการ (ใช้ Gemini)")
                .font(Brand.font(11.5)).foregroundColor(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text("ลงท้ายสุภาพด้วย").font(Brand.font(12.5, .semibold)).foregroundColor(.white)
                Toggle2(options: [("ครับ", "ครับ"), ("ค่ะ", "ค่ะ"), ("", "ไม่เติม")],
                        selection: Binding(get: { state.particle }, set: { state.setParticle($0) }))
                    .frame(maxWidth: 260)
            }
            ForEach(state.toneRules) { rule in
                HStack(spacing: 10) {
                    Text(rule.appName).font(Brand.font(13, .semibold)).foregroundColor(.white)
                        .frame(width: 130, alignment: .leading).lineLimit(1)
                    Toggle2(options: Tone.allCases.map { ($0, $0.title) },
                            selection: Binding(get: { rule.tone }, set: { t in
                                var list = state.toneRules
                                if let i = list.firstIndex(where: { $0.id == rule.id }) { list[i].tone = t }
                                state.saveToneRules(list)
                            }))
                    Button {
                        state.saveToneRules(state.toneRules.filter { $0.id != rule.id })
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.muted)
                    }
                    .buttonStyle(.plain)
                    .help("ลบ")
                }
            }
            Menu {
                let used = Set(state.toneRules.map(\.bundleID))
                let apps = AppTones.runningApps().filter { !used.contains($0.bundleID) }
                if apps.isEmpty { Text("เปิดแอปที่อยากตั้งก่อน แล้วกลับมาเลือก") }
                ForEach(apps, id: \.bundleID) { app in
                    Button(app.name) {
                        state.saveToneRules(state.toneRules + [AppToneRule(appName: app.name, bundleID: app.bundleID, tone: .polite)])
                    }
                }
            } label: {
                Label("เพิ่มแอป (เลือกจากแอปที่เปิดอยู่)", systemImage: "plus")
                    .font(Brand.font(12, .bold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .tint(Color(nsColor: Brand.amber))
        }
    }

    // MARK: คำย่อของฉัน

    private var snippetCard: some View {
        Card(title: "คำย่อของฉัน") {
            Text("พูดคำสั้น ๆ แล้วได้ข้อความยาว เช่น พูด “ที่อยู่ฉัน” → ได้ที่อยู่เต็ม")
                .font(Brand.font(11.5)).foregroundColor(Brand.muted)
            ForEach(state.snippets) { sn in
                SnippetRow(snippet: sn,
                           onChange: { new in
                               var list = state.snippets
                               if let i = list.firstIndex(where: { $0.id == sn.id }) { list[i] = new }
                               state.saveSnippets(list)
                           },
                           onDelete: { state.saveSnippets(state.snippets.filter { $0.id != sn.id }) })
            }
            Button {
                state.saveSnippets(state.snippets + [Snippet(trigger: "", text: "")])
            } label: {
                Label("เพิ่มคำย่อ", systemImage: "plus").font(Brand.font(12, .bold))
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    // MARK: สิทธิ์

    private var permissionsCard: some View {
        let needSpeech = state.engine == .apple
        let allPerms = state.mic && state.accessibility && (!needSpeech || state.speech)
        return Card(title: "สิทธิ์") {
            if allPerms {
                Label("ให้สิทธิ์ครบแล้ว", systemImage: "checkmark.seal.fill")
                    .font(Brand.font(13, .bold))
                    .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.5))
            } else {
                PermissionRow(icon: "mic.fill", title: "ไมโครโฟน", detail: "ไว้ฟังเสียงพูด", granted: state.mic) {
                    Permissions.requestMic { state.refresh() }
                }
                if needSpeech {
                    PermissionRow(icon: "waveform", title: "การรู้จำเสียงพูด", detail: "ให้ Apple ช่วยแปลงเสียง", granted: state.speech) {
                        Permissions.requestSpeech { state.refresh() }
                    }
                }
                PermissionRow(icon: "keyboard.fill", title: "ควบคุมคอมพิวเตอร์ (Accessibility)",
                              detail: "ไว้รู้ว่ากดปุ่มลัด และพิมพ์ลงแอปอื่นให้", granted: state.accessibility) {
                    Permissions.requestAccessibility()
                }
            }
        }
    }

    // MARK: ขั้นสูง (พับไว้)

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showAdvanced.toggle() }
            } label: {
                HStack {
                    Text("ขั้นสูง").font(Brand.font(13, .bold)).foregroundColor(.white.opacity(0.8))
                    Text("ตัวแปลงเสียง · key · รุ่น AI").font(Brand.font(11.5)).foregroundColor(Brand.muted)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(Brand.muted)
                        .rotationEffect(.degrees(showAdvanced ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAdvanced {
                AdvancedSettings(state: state)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Brand.line))
    }
}

// MARK: - ส่วนขั้นสูง

private struct AdvancedSettings: View {
    @ObservedObject var state: PermissionState
    @State private var keyText = ""
    @State private var loginOn = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ตัวแปลงเสียง").font(Brand.font(12.5, .bold)).foregroundColor(.white)
            Toggle2(options: [(Engine.gemini, "Gemini · แนะนำ"), (Engine.apple, "Apple (ไม่ต้องใช้ key)")],
                    selection: Binding(get: { state.engine }, set: { state.setEngine($0) }))
            if state.engine == .apple {
                Text("แบบ Apple ไม่ต้องใช้ key แต่ไม่เข้าใจคำสั่งเสียง ไม่แก้ข้อความที่เลือก และไม่ปรับโทน")
                    .font(Brand.font(11)).foregroundColor(Brand.muted)
            }
            KeyField(state: state, keyText: $keyText)
            HStack {
                Text("รุ่นที่ใช้เรียบเรียง").font(Brand.font(12, .semibold)).foregroundColor(Brand.muted)
                Spacer()
                Picker("", selection: Binding(get: { state.model }, set: { state.setModel($0) })) {
                    ForEach(GeminiModel.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 240)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("เก็บข้อความไว้ในคลิปบอร์ดด้วย").font(Brand.font(12.5, .semibold)).foregroundColor(.white)
                    Text("ปกติพูดดิวะคืนคลิปบอร์ดเดิมให้หลังพิมพ์").font(Brand.font(11)).foregroundColor(Brand.muted)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { state.keepInClipboard }, set: { state.setKeepInClipboard($0) }))
                    .toggleStyle(.switch).tint(Color(nsColor: Brand.orange)).labelsHidden()
            }
            HStack {
                Text("เปิดเองตอนเปิดเครื่อง").font(Brand.font(12.5, .semibold)).foregroundColor(.white)
                Spacer()
                Toggle("", isOn: Binding(get: { loginOn }, set: { on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {}
                    loginOn = SMAppService.mainApp.status == .enabled
                }))
                .toggleStyle(.switch).tint(Color(nsColor: Brand.orange)).labelsHidden()
            }
        }
    }
}

/// ช่องใส่ Gemini key (ใช้ทั้งในตั้งค่าและขั้นตอนเริ่มต้น)
struct KeyField: View {
    @ObservedObject var state: PermissionState
    @Binding var keyText: String
    var showLink = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SecureField(state.hasKey ? "•••••••• บันทึกไว้แล้ว (วางใหม่เพื่อเปลี่ยน)" : "วาง Gemini key ตรงนี้",
                            text: $keyText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Brand.line))
                    .onSubmit { save() }
                Button("บันทึก") { save() }
                    .buttonStyle(HotButtonStyle(compact: true))
                    .disabled(keyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(keyText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
            }
            HStack {
                Text(state.keyStatus)
                    .font(Brand.font(11, .bold))
                    .foregroundColor(state.keyOK == false ? Color(nsColor: Brand.red)
                                     : state.keyOK == true ? Color(red: 0.35, green: 0.9, blue: 0.5) : Brand.muted)
                Spacer()
                if showLink {
                    Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                        Text("ขอ key ฟรีที่ Google →").font(Brand.font(11, .bold))
                            .foregroundColor(Color(nsColor: Brand.amber))
                    }
                }
            }
        }
    }

    private func save() {
        state.saveKey(keyText)
        keyText = ""
    }
}

// MARK: - แถวคำย่อ (แก้ไขได้ในที่)

private struct SnippetRow: View {
    let snippet: Snippet
    var onChange: (Snippet) -> Void
    var onDelete: () -> Void
    @State private var trigger = ""
    @State private var text = ""

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("พูดว่า…", text: $trigger)
                .textFieldStyle(.plain)
                .font(Brand.font(12.5, .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.4)))
                .frame(width: 150)
                .onSubmit { commit() }
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundColor(Brand.muted)
                .padding(.top, 9)
            TextField("ได้ข้อความนี้", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .font(Brand.font(12.5))
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.4)))
                .onSubmit { commit() }
            Button(action: onDelete) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.muted)
            }
            .buttonStyle(.plain)
            .padding(.top, 9)
            .help("ลบ")
        }
        .onAppear { trigger = snippet.trigger; text = snippet.text }
        .onChange(of: trigger) { _ in commit() }
        .onChange(of: text) { _ in commit() }
    }

    private func commit() {
        guard trigger != snippet.trigger || text != snippet.text else { return }
        onChange(Snippet(id: snippet.id, trigger: trigger, text: text))
    }
}

// MARK: - ตั้งปุ่มลัด: ปุ่มเดียว (เช่น ⌥ ขวา) หรือปุ่มผสม (เช่น ⌥ Space)

struct ShortcutRecorder: View {
    let current: Shortcut
    let onPick: (Shortcut) -> Void
    @State private var recording = false
    @State private var monitor: Any?
    @State private var pendingModifier: Hotkey?
    @State private var hint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("ปุ่มที่ใช้พูด").font(Brand.font(13, .bold)).foregroundColor(.white)
                Spacer()
                if recording {
                    Text(hint.isEmpty ? "กดปุ่มที่ต้องการ…" : hint)
                        .font(Brand.font(12, .bold))
                        .foregroundColor(Color(nsColor: Brand.amber))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().strokeBorder(Color(nsColor: Brand.amber),
                                                           style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    Button("ยกเลิก") { stop() }.buttonStyle(GhostButtonStyle())
                } else {
                    KeyCap(text: current.title)
                    Button("เปลี่ยน") { start() }.buttonStyle(HotButtonStyle(compact: true))
                }
            }
            if recording {
                Text("ปุ่มเดียว เช่น ⌥ ขวา หรือปุ่มผสม เช่น ⌥ + Space · กด esc เพื่อยกเลิก")
                    .font(Brand.font(11)).foregroundColor(Brand.muted)
            } else if current != .default {
                Button("คืนค่าเริ่มต้น (\(Shortcut.default.short))") { onPick(.default) }
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        hint = ""
        pendingModifier = nil
        HotkeyCapture.active = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { e in
            let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if e.type == .keyDown {
                pendingModifier = nil
                let mods = Shortcut.carbonModifiers(from: flags)
                if e.keyCode == 53 && mods == 0 { stop(); return nil } // esc = ยกเลิก
                if mods == 0 && !Shortcut.isFunctionKey(e.keyCode) {
                    hint = "ต้องกดคู่กับ ⌘ ⌥ ⌃ หรือ ⇧ ด้วย"
                    return nil
                }
                onPick(Shortcut(kind: .combo, keyCode: UInt32(e.keyCode), carbonModifiers: mods,
                                keyName: Shortcut.keyName(for: e)))
                stop()
                return nil
            }
            // ปุ่ม modifier ปุ่มเดียว: กดแล้วปล่อยโดยไม่มีปุ่มอื่น = เลือกปุ่มนั้น
            if let hk = Hotkey.from(keyCode: e.keyCode) {
                let down = (e.modifierFlags.rawValue & hk.deviceMask) != 0
                if down {
                    pendingModifier = hk
                } else if pendingModifier == hk {
                    onPick(.modifier(hk))
                    stop()
                }
            }
            return e
        }
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        recording = false
        pendingModifier = nil
        // ปล่อยปุ่มก่อนค่อยเปิดให้อัดได้ จะได้ไม่เริ่มอัดทันทีที่ตั้งเสร็จ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { HotkeyCapture.active = false }
    }
}

// MARK: - คำเฉพาะ (ป้ายคำ)

struct VocabularyCard: View {
    @ObservedObject var state: PermissionState
    @State private var vocabInput = ""

    var body: some View {
        let all = state.vocab
        let query = vocabInput.trimmingCharacters(in: .whitespaces)
        let shown = query.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(query) }
        let exists = all.contains { $0.caseInsensitiveCompare(query) == .orderedSame }
        return Card(title: "คำเฉพาะของฉัน") {
            Text("ชื่อคน แบรนด์ ศัพท์ที่ใช้บ่อย — ให้สะกดถูกตั้งแต่แรก")
                .font(Brand.font(11.5)).foregroundColor(Brand.muted)
            HStack(spacing: 8) {
                Image(systemName: query.isEmpty ? "plus" : "magnifyingglass")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(Brand.muted)
                TextField("พิมพ์คำแล้วกด Enter (วางหลายคำคั่นด้วย , ได้)", text: $vocabInput)
                    .textFieldStyle(.plain)
                    .font(Brand.font(12.5))
                    .foregroundColor(.white)
                    .onSubmit {
                        state.addVocab(vocabInput)
                        vocabInput = ""
                    }
                if !query.isEmpty {
                    Text(exists ? "มีแล้ว" : "Enter เพื่อเพิ่ม")
                        .font(Brand.font(10.5, .semibold))
                        .foregroundColor(exists ? Color(nsColor: Brand.amber) : Brand.muted)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Brand.line))

            if !all.isEmpty {
                ScrollView {
                    FlowLayout(spacing: 6) {
                        ForEach(shown, id: \.self) { word in
                            VocabChip(word: word, highlight: !query.isEmpty) {
                                withAnimation(.easeOut(duration: 0.15)) { state.removeVocab(word) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .fixedSize(horizontal: false, vertical: shown.count < 12)
                Text(query.isEmpty ? "\(all.count) คำ · ชี้ที่คำแล้วกด × เพื่อลบ" : "เจอ \(shown.count) จาก \(all.count) คำ")
                    .font(Brand.font(10.5, .semibold)).foregroundColor(Brand.muted)
            }
        }
    }
}
