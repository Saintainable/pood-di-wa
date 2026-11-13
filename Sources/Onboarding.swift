import AppKit
import SwiftUI

// MARK: - ชิ้นส่วน UI โทน ดำถ่าน + ส้ม-แดง

/// ปุ่มหลัก: แคปซูลไล่สีส้ม → แดง กดแล้วยุบนิดนึง
struct HotButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.font(compact ? 12 : 14, .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 12 : 20)
            .padding(.vertical, compact ? 5 : 9)
            .background(Capsule().fill(Brand.hot))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18)))
            .shadow(color: Color(nsColor: Brand.red).opacity(configuration.isPressed ? 0.1 : 0.35), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// ปุ่มรอง: ตัวหนังสือเทา ไม่มีพื้น
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.font(12, .semibold))
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.4 : 0.6))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.05)))
    }
}

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(Brand.font(11, .black))
                .tracking(1.2)
                .foregroundColor(Color(nsColor: Brand.orange))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Brand.line))
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(Brand.font(15, .bold))
                .foregroundColor(granted ? .white.opacity(0.5) : .white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(granted ? AnyShapeStyle(Color.white.opacity(0.06)) : AnyShapeStyle(Brand.hot)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Brand.font(13, .bold)).foregroundColor(.white)
                Text(detail).font(Brand.font(11)).foregroundColor(Brand.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted {
                Label("เรียบร้อย", systemImage: "checkmark")
                    .font(Brand.font(11, .heavy))
                    .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.5))
            } else {
                Button("อนุญาต", action: action).buttonStyle(HotButtonStyle(compact: true))
            }
        }
    }
}

private struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Brand.font(12, .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18)))
            .shadow(color: .black.opacity(0.5), radius: 0, y: 2)
    }
}

/// สวิตช์ 2 ทางแบบแคปซูล (แทน segmented control สีน้ำเงินของระบบ)
private struct Toggle2<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, label in
                Button { selection = value } label: {
                    Text(label)
                        .font(Brand.font(12, .bold))
                        .foregroundColor(.white.opacity(selection == value ? 1 : 0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selection == value ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.clear)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .overlay(Capsule().strokeBorder(Brand.line))
    }
}

/// ป้ายคำเฉพาะ — ชี้แล้วมีปุ่ม × ให้ลบ
private struct VocabChip: View {
    let word: String
    var highlight = false
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(word)
                .font(Brand.font(12, .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(Color(nsColor: Brand.red)))
                }
                .buttonStyle(.plain)
                .help("ลบคำนี้")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, hovering ? 4 : 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(hovering ? Color.white.opacity(0.16)
                                   : highlight ? Color(nsColor: Brand.orange).opacity(0.22) : Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(hovering ? 0.25 : 0.10)))
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}

/// จัดของเรียงต่อกันแล้วขึ้นบรรทัดใหม่เมื่อเต็ม (แบบตัวหนังสือ)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: maxW.isFinite ? maxW : widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > bounds.width { y += rowH + spacing; x = 0; rowH = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - หน้าตั้งค่า

struct OnboardingView: View {
    @ObservedObject var state: PermissionState
    @State private var keyText = ""
    @State private var mascotLine: String?
    @State private var lineID = 0
    @State private var copiedID: UUID?
    @State private var vocabInput = ""
    @State private var pokeTimes: [Date] = []

    var body: some View {
        GeometryReader { geo in
            let twoCol = geo.size.width >= 740
            let colW = (geo.size.width - 44 - 14) / 2
            ZStack(alignment: .topLeading) {
                // ชั้นล่างสุด: มาสคอตตัวเบิ้ม ยืนหลังคอลัมน์ขวา — การ์ดจะทับครึ่งล่างของตัว
                if twoCol {
                    let headerBottom: CGFloat = 34 + 76          // padding บน + ความสูงหัว
                    let bodyX = 22 + colW + 14 + colW * 0.36     // กลางตัว ค่อนซ้ายของคอลัมน์ขวา
                    let bodyY = headerBottom + 12 - 10           // ตาโผล่พ้นขอบการ์ดชัด ๆ
                    MascotView(sleeping: !state.enabled, onPoke: { poke() }, line: mascotLine)
                        .position(x: bodyX - MascotView.bodyCenter.x + MascotView.frameSize.width / 2,
                                  y: bodyY - MascotView.bodyCenter.y + MascotView.frameSize.height / 2)
                        .help("จิ้มดูดิ")
                }

                VStack(spacing: 0) {
                    header
                        .frame(height: 76)
                        .padding(.horizontal, 22)
                        .padding(.top, 34)
                        .padding(.bottom, 12)

                    ScrollView {
                        Group {
                            if twoCol {
                                HStack(alignment: .top, spacing: 14) {
                                    leftColumn.frame(width: colW)
                                    rightColumn.frame(width: colW)
                                }
                            } else {
                                VStack(spacing: 14) {
                                    leftColumn
                                    rightColumn
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)
                        .frame(width: geo.size.width)
                    }

                    footer
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.25))
                }
            }
        }
        .frame(minWidth: 460, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
        .background(
            ZStack {
                Brand.ink
                RadialGradient(colors: [Color(nsColor: Brand.orange).opacity(0.22), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }

    private var leftColumn: some View {
        VStack(spacing: 14) {
            engineCard
            liveTextCard
            vocabularyCard
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 14) {
            permissionsCard
            historyCard
            howToCard
        }
    }

    // MARK: หัว: ไอคอน + ชื่อ | สวิตช์หลัก (มาสคอตอยู่ชั้นหลัง)

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 52, height: 52)
                .rotationEffect(.degrees(-6))
            VStack(alignment: .leading, spacing: 0) {
                Text("พูดดิวะ!")
                    .font(Brand.font(30, .bold))
                    .foregroundStyle(Brand.hot)
                Text(state.enabled ? "กดค้าง พูดมา ปล่อยปุ๊บ ขึ้นปั๊บ — ทุกแอป" : "ปิดรับเสียงอยู่ — ปุ่มลัดไม่ทำงาน")
                    .font(Brand.font(12.5, .medium))
                    .foregroundColor(Brand.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            powerSwitch
        }
    }

    /// สวิตช์ใหญ่ เปิด/ปิดการรับเสียง
    private var powerSwitch: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { state.setEnabled(!state.enabled) }
        } label: {
            HStack(spacing: 8) {
                Text(state.enabled ? "เปิดรับเสียง" : "ปิดอยู่")
                    .font(Brand.font(12, .heavy))
                    .foregroundColor(.white.opacity(state.enabled ? 1 : 0.6))
                ZStack(alignment: state.enabled ? .trailing : .leading) {
                    Capsule()
                        .fill(state.enabled ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.white.opacity(0.12)))
                        .frame(width: 52, height: 30)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .overlay(Image(systemName: state.enabled ? "mic.fill" : "mic.slash.fill")
                            .font(Brand.font(11, .bold))
                            .foregroundColor(state.enabled ? Color(nsColor: Brand.red) : .gray))
                        .padding(3)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .overlay(Capsule().strokeBorder(Brand.line))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("เปิด/ปิดการรับเสียงทั้งหมด")
    }

    private func poke() {
        let now = Date()
        pokeTimes = pokeTimes.filter { now.timeIntervalSince($0) < 3 } + [now]
        let pool = !state.enabled ? MascotLines.asleep : pokeTimes.count >= 3 ? MascotLines.angry : MascotLines.awake
        var line = pool.randomElement()!
        if line == mascotLine, pool.count > 1 { line = pool.filter { $0 != line }.randomElement()! }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
            mascotLine = line
            lineID += 1
        }
        let id = lineID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard id == lineID else { return }
            withAnimation(.easeOut(duration: 0.2)) { mascotLine = nil }
        }
    }

    // MARK: การ์ด

    private var engineCard: some View {
        Card(title: "ตัวแปลงเสียง") {
            Toggle2(options: [(Engine.gemini, "Gemini · แนะนำ"), (Engine.apple, "Apple  (ไม่ต้องใช้ key)")],
                    selection: Binding(get: { state.engine }, set: { state.setEngine($0) }))

            if state.engine == .gemini {
                Text("พูดผิดบอก “เอาใหม่” มันลบให้ · สั่งได้ เช่น “แปลเป็นภาษาอังกฤษ” “ทำเป็นข้อๆ”")
                    .font(Brand.font(11)).foregroundColor(Brand.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    SecureField(state.hasKey ? "•••••••• บันทึกไว้แล้ว (วางใหม่เพื่อเปลี่ยน)" : "วาง Gemini API key ตรงนี้",
                                text: $keyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
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
                    Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                        Text("ยังไม่มี key? ขอฟรีที่นี่ →").font(Brand.font(11, .heavy))
                            .foregroundColor(Color(nsColor: Brand.amber))
                    }
                }
                HStack {
                    Text("รุ่นที่ใช้ทำตามคำสั่ง").font(Brand.font(11, .semibold)).foregroundColor(Brand.muted)
                    Spacer()
                    Picker("", selection: Binding(get: { state.model }, set: { state.setModel($0) })) {
                        ForEach(GeminiModel.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
            }
        }
    }

    private var liveTextCard: some View {
        Card(title: "ตอนพูด") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("โชว์คำที่พูดสด ๆ").font(Brand.font(13, .bold)).foregroundColor(.white)
                    Text(state.showLiveText ? "แถบยืดออก มีข้อความวิ่งข้างคลื่นเสียง"
                                            : "ปิดอยู่ — แถบเล็ก มีแค่คลื่นเสียง ไม่บังจอ")
                        .font(Brand.font(11)).foregroundColor(Brand.muted)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { state.showLiveText }, set: { state.setShowLiveText($0) }))
                    .toggleStyle(.switch)
                    .tint(Color(nsColor: Brand.orange))
                    .labelsHidden()
            }
        }
    }

    private var vocabularyCard: some View {
        let all = state.vocab
        let query = vocabInput.trimmingCharacters(in: .whitespaces)
        let shown = query.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(query) }
        let exists = all.contains { $0.caseInsensitiveCompare(query) == .orderedSame }
        return Card(title: "คำเฉพาะของฉัน") {
            Text("ชื่อคน แบรนด์ ศัพท์ที่ใช้บ่อย — ให้สะกดถูกตั้งแต่แรก")
                .font(Brand.font(11)).foregroundColor(Brand.muted)

            // ช่องเดียว: พิมพ์แล้ว Enter = เพิ่ม · ระหว่างพิมพ์ = ค้นคำที่มีอยู่
            HStack(spacing: 8) {
                Image(systemName: query.isEmpty ? "plus" : "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Brand.muted)
                TextField("พิมพ์คำแล้วกด Enter (วางหลายคำคั่นด้วย , ได้)", text: $vocabInput)
                    .textFieldStyle(.plain)
                    .font(Brand.font(12.5))
                    .foregroundColor(.white)
                    .onSubmit { addVocab() }
                if !query.isEmpty {
                    Text(exists ? "มีแล้ว" : "Enter เพื่อเพิ่ม")
                        .font(Brand.font(10.5, .semibold))
                        .foregroundColor(exists ? Color(nsColor: Brand.amber) : Brand.muted)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Brand.line))

            if all.isEmpty {
                Text("ยังไม่มีคำ")
                    .font(Brand.font(11)).foregroundColor(Brand.muted)
            } else {
                // คำเยอะแค่ไหนก็ไม่ดันหน้าต่าง: สูงสุด ~5 แถว แล้วเลื่อนดูในกล่อง
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

                HStack {
                    Text(query.isEmpty ? "\(all.count) คำ · ชี้ที่คำแล้วกด × เพื่อลบ"
                                       : "เจอ \(shown.count) จาก \(all.count) คำ")
                        .font(Brand.font(10.5, .semibold)).foregroundColor(Brand.muted)
                    Spacer()
                    if all.count > 1 && query.isEmpty {
                        Button("ลบทั้งหมด") { confirmClearVocab() }
                            .buttonStyle(GhostButtonStyle())
                    }
                }
            }
        }
    }

    private func addVocab() {
        let added = state.addVocab(vocabInput)
        if added > 0 || !vocabInput.isEmpty { vocabInput = "" }
    }

    private func confirmClearVocab() {
        let alert = NSAlert()
        alert.messageText = "ลบคำเฉพาะทั้งหมด \(state.vocab.count) คำ?"
        alert.informativeText = "ลบแล้วกู้คืนไม่ได้"
        alert.addButton(withTitle: "ลบทั้งหมด")
        alert.addButton(withTitle: "ยกเลิก")
        if alert.runModal() == .alertFirstButtonReturn { state.setVocabList([]) }
    }


    @ViewBuilder private var permissionsCard: some View {
        let needSpeech = state.engine == .apple
        let allPerms = state.mic && state.accessibility && (!needSpeech || state.speech)
        Card(title: "ขอสิทธิ์หน่อย") {
            if allPerms {
                Label("ให้สิทธิ์ครบแล้ว", systemImage: "checkmark.seal.fill")
                    .font(Brand.font(13, .heavy))
                    .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.5))
            } else {
                PermissionRow(icon: "mic.fill", title: "ไมโครโฟน",
                              detail: "ไม่ให้ฟัง แล้วจะพิมพ์ให้ได้ไง", granted: state.mic) {
                    Permissions.requestMic { state.refresh() }
                }
                if needSpeech {
                    PermissionRow(icon: "waveform", title: "การรู้จำเสียงพูด",
                                  detail: "ให้ Apple ช่วยแปลงเสียง", granted: state.speech) {
                        Permissions.requestSpeech { state.refresh() }
                    }
                }
                PermissionRow(icon: "keyboard.fill", title: "Accessibility",
                              detail: "รู้ว่ากดปุ่มลัด + พิมพ์ลงแอปอื่น", granted: state.accessibility) {
                    Permissions.requestAccessibility()
                }
                if !state.accessibility {
                    Text("เปิดสวิตช์แล้วยังไม่ขึ้น? เลือก Pood Di Wa ในรายการ กด − ลบ แล้วกด “อนุญาต” ใหม่")
                        .font(Brand.font(10.5))
                        .foregroundColor(Brand.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var historyCard: some View {
        Card(title: "พูดล่าสุด") {
            if state.history.isEmpty {
                Text("ยังว่างอยู่ ลองกดค้างแล้วพูดดูสิ")
                    .font(Brand.font(11.5)).foregroundColor(Brand.muted)
            } else {
                VStack(spacing: 6) {
                    ForEach(state.history.prefix(6)) { item in
                        Button {
                            History.copy(item)
                            withAnimation { copiedID = item.id }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                if copiedID == item.id { withAnimation { copiedID = nil } }
                            }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.text)
                                    .font(Brand.font(12, .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(copiedID == item.id ? "ก๊อปแล้ว" : History.timeAgo(item.date))
                                    .font(Brand.font(10, .bold))
                                    .foregroundColor(copiedID == item.id ? Color(red: 0.35, green: 0.9, blue: 0.5) : Brand.muted)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("คลิกเพื่อคัดลอก")
                    }
                }
                HStack {
                    Text("คลิกเพื่อคัดลอก · เก็บ \(History.limit) อันล่าสุด (ดูครบในเมนูบนแถบด้านบน)")
                        .font(Brand.font(10.5)).foregroundColor(Brand.muted)
                    Spacer()
                    Button("ล้าง") { History.clear(); state.refresh() }
                        .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }

    private var howToCard: some View {
        Card(title: "ใช้ยังไง") {
            HStack(spacing: 6) {
                Text("กด"); KeyCap(text: state.hotkey.short); Text("ค้าง → พูด → ปล่อย")
            }
            HStack(spacing: 6) {
                Text("พูดยาว: แตะ"); KeyCap(text: state.hotkey.short); Text("พูดจบแตะอีกที")
            }
            HStack(spacing: 6) {
                Text("เปลี่ยนใจ:"); KeyCap(text: "esc")
            }
        }
        .font(Brand.font(12, .medium))
        .foregroundColor(.white.opacity(0.85))
    }

    private var footer: some View {
        HStack {
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("ออกจากโปรแกรม", systemImage: "power")
            }
            .buttonStyle(GhostButtonStyle())
            .help("ปิดพูดดิวะทั้งหมด (ปุ่มลัดจะใช้ไม่ได้จนกว่าจะเปิดใหม่)")
            Spacer()
        }
    }

    private func save() {
        state.saveKey(keyText)
        keyText = ""
    }
}


final class OnboardingWindowController: NSObject, NSWindowDelegate {
    /// หน้าต่างตั้งค่าที่เปิดอยู่ (มาสคอตใช้คำนวณทิศสายตา)
    static weak var currentWindow: NSWindow?
    private var window: NSWindow?
    private var state: PermissionState?

    func show() {
        // ระหว่างเปิดหน้าตั้งค่า ให้มีไอคอนใน Dock และ ⌘Tab ได้ จะได้ไม่หลงหาย
        NSApp.setActivationPolicy(.regular)
        if let w = window {
            state?.refresh()
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            return
        }
        let st = PermissionState()
        state = st
        let view = OnboardingView(state: st)
        // ผู้ใช้ลากปรับขนาดได้ — SwiftUI กำหนดแค่ขนาดเล็กสุด
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.minSize]
        let w = NSWindow(contentViewController: controller)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.setContentSize(NSSize(width: 820, height: 680))
        w.setFrameAutosaveName("PoodDiWaSettings")
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.appearance = NSAppearance(named: .darkAqua)
        w.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        window = w
        OnboardingWindowController.currentWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
    }

    /// ปิดหน้าต่าง (แอปยังทำงานอยู่เบื้องหลัง พร้อมรับปุ่มลัด)
    func close() {
        guard let w = window else { return }
        w.orderOut(nil)
        w.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        state = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
