import AppKit
import SwiftUI

// MARK: - หน้าต่างหลัก: แถบซ้าย (หน้าแรก / ประวัติ / ตั้งค่า) + เนื้อหา

enum Page: String, CaseIterable {
    case home, history, settings

    var title: String {
        switch self {
        case .home: "หน้าแรก"
        case .history: "ประวัติ"
        case .settings: "ตั้งค่า"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .history: "clock.arrow.circlepath"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct MainView: View {
    @ObservedObject var state: PermissionState
    @State private var page: Page = Page(rawValue: MainView.argValue("--page") ?? "") ?? .home
    @State private var showSetup = !Permissions.allGranted && !CommandLine.arguments.contains("--no-setup")

    /// สำหรับนักพัฒนา: เปิดหน้าที่ต้องการตรง ๆ (ไว้ถ่ายภาพหน้าจอ)
    static func argValue(_ flag: String) -> String? {
        guard let i = CommandLine.arguments.firstIndex(of: flag), i + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[i + 1]
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Sidebar(state: state, page: $page)
                    .frame(width: 210)
                Rectangle().fill(Brand.line).frame(width: 1)
                Group {
                    switch page {
                    case .home: HomePage(state: state, openSetup: { showSetup = true }, openSettings: { page = .settings })
                    case .history: HistoryPage(state: state)
                    case .settings: SettingsPage(state: state, openSetup: { showSetup = true })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showSetup {
                SetupWizard(state: state) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSetup = false
                        page = .home
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 760, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        .background(
            ZStack {
                Brand.ink
                RadialGradient(colors: [Color(nsColor: Brand.orange).opacity(0.18), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 460)
            }
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - แถบซ้าย

private struct Sidebar: View {
    @ObservedObject var state: PermissionState
    @Binding var page: Page

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-6))
                Text("พูดดิวะ!")
                    .font(Brand.font(21, .bold))
                    .foregroundStyle(Brand.hot)
            }
            .padding(.horizontal, 6)
            .padding(.top, 44)
            .padding(.bottom, 18)

            ForEach(Page.allCases, id: \.self) { p in
                Button { page = p } label: {
                    HStack(spacing: 10) {
                        Image(systemName: p.icon)
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 18)
                        Text(p.title).font(Brand.font(14, .semibold))
                        Spacer()
                        if p == .settings && !state.all {
                            Circle().fill(Color(nsColor: Brand.amber)).frame(width: 7, height: 7)
                                .help("ยังตั้งค่าไม่ครบ")
                        }
                    }
                    .foregroundColor(page == p ? .white : .white.opacity(0.62))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(page == p ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.clear)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            PowerSwitch(state: state)
                .padding(.bottom, 4)
            HStack {
                CreditsButton()
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power").font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(GhostButtonStyle())
                .help("ออกจากโปรแกรม (ปุ่มลัดจะใช้ไม่ได้จนกว่าจะเปิดใหม่)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 16)
        .background(Color.black.opacity(0.22))
    }
}

/// สวิตช์ใหญ่ เปิด/ปิดการรับเสียง
struct PowerSwitch: View {
    @ObservedObject var state: PermissionState

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { state.setEnabled(!state.enabled) }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.enabled ? "เปิดรับเสียง" : "ปิดอยู่")
                        .font(Brand.font(13, .bold))
                        .foregroundColor(.white.opacity(state.enabled ? 1 : 0.6))
                    Text(state.enabled ? "ปุ่มลัดพร้อมใช้" : "ปุ่มลัดไม่ทำงาน")
                        .font(Brand.font(10.5)).foregroundColor(Brand.muted)
                }
                Spacer(minLength: 4)
                ZStack(alignment: state.enabled ? .trailing : .leading) {
                    Capsule()
                        .fill(state.enabled ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.white.opacity(0.12)))
                        .frame(width: 48, height: 28)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .overlay(Image(systemName: state.enabled ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(state.enabled ? Color(nsColor: Brand.red) : .gray))
                        .padding(3)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("เปิด/ปิดการรับเสียงทั้งหมด")
    }
}

// MARK: - หน้าแรก: มาสคอต + สถานะ + ลองพูด + สถิติ

private struct HomePage: View {
    @ObservedObject var state: PermissionState
    var openSetup: () -> Void
    var openSettings: () -> Void
    @State private var practice = ""
    @FocusState private var practiceFocused: Bool

    /// ระยะจากบนสุดของหน้าถึงขอบบนการ์ดสถานะ — มาสคอตยืนหลังการ์ดนี้
    private let cardTop: CGFloat = 178

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // มาสคอตตัวเบิ้มยืนหลังการ์ดสถานะ (การ์ดบังครึ่งล่าง)
                let bodyX = geo.size.width - 24 - 190
                let bodyY = cardTop - 10
                MascotView(sleeping: !state.enabled,
                           clipY: cardTop - (bodyY - MascotView.bodyCenter.y))
                    .position(x: bodyX - MascotView.bodyCenter.x + MascotView.frameSize.width / 2,
                              y: bodyY - MascotView.bodyCenter.y + MascotView.frameSize.height / 2)
                    .help("จิ้มดูดิ")

                VStack(alignment: .leading, spacing: 14) {
                    // หัว: ทักทาย
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting).font(Brand.font(26, .bold)).foregroundColor(.white)
                        Text(Stats.mascotComment)
                            .font(Brand.font(13, .medium)).foregroundColor(Brand.muted)
                            .frame(maxWidth: geo.size.width - 300, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 50)
                    .frame(height: cardTop - 14, alignment: .topLeading)

                    statusCard
                    practiceCard
                    statsRow
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "อรุณสวัสดิ์!"
        case 12..<17: return "บ่ายนี้พูดอะไรดี?"
        case 17..<22: return "เย็นแล้ว พูดต่อ!"
        default: return "ดึกแล้วนะ พูดเบา ๆ"
        }
    }

    // การ์ดสถานะ: พร้อมใช้ / ยังตั้งค่าไม่ครบ
    private var statusCard: some View {
        HStack(spacing: 14) {
            if !state.all {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(nsColor: Brand.amber))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ยังตั้งค่าไม่ครบ").font(Brand.font(15, .bold)).foregroundColor(.white)
                    Text("อีกนิดเดียวก็พูดได้แล้ว").font(Brand.font(12)).foregroundColor(Brand.muted)
                }
                Spacer()
                Button("ตั้งค่าให้เสร็จ", action: openSetup).buttonStyle(HotButtonStyle())
            } else if !state.enabled {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.white.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ปิดรับเสียงอยู่").font(Brand.font(15, .bold)).foregroundColor(.white)
                    Text("เปิดสวิตช์ด้านซ้ายล่างเมื่อพร้อมพูด").font(Brand.font(12)).foregroundColor(Brand.muted)
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(red: 0.35, green: 0.9, blue: 0.5)).frame(width: 8, height: 8)
                        Text("พร้อมใช้ในทุกแอป").font(Brand.font(15, .bold)).foregroundColor(.white)
                    }
                    HStack(spacing: 6) {
                        Text("กด").font(Brand.font(13)).foregroundColor(Brand.muted)
                        KeyCap(text: state.shortcut.title)
                        Text({
                            switch state.triggerMode {
                            case .both: return "ค้างแล้วพูด หรือแตะทีเดียวพูดยาว"
                            case .hold: return "ค้างไว้แล้วพูด ปล่อยแล้วพิมพ์ให้"
                            case .toggle: return "แล้วพูด กดอีกทีเมื่อพูดจบ"
                            }
                        }())
                        .font(Brand.font(13)).foregroundColor(Brand.muted)
                    }
                }
                Spacer()
                Button("เปลี่ยนปุ่ม", action: openSettings).buttonStyle(GhostButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Brand.line))
    }

    // ช่องลองพูด — กดปุ่มลัดตอนช่องนี้โฟกัสอยู่ ข้อความจะมาลงที่นี่
    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ลองพูดตรงนี้").font(Brand.font(14, .bold)).foregroundColor(.white)
                Text("คลิกในช่อง แล้วกด \(state.shortcut.short) พูดได้เลย")
                    .font(Brand.font(11.5)).foregroundColor(Brand.muted)
                Spacer()
                if !practice.isEmpty {
                    Button("ล้าง") { practice = "" }.buttonStyle(GhostButtonStyle())
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $practice)
                    .font(Brand.font(14))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .focused($practiceFocused)
                    .padding(8)
                if practice.isEmpty {
                    Text("ลองพูดว่า “พรุ่งนี้ประชุมบ่ายสอง เอาใหม่ บ่ายสาม” แล้วดูว่ามันแก้ให้เอง")
                        .font(Brand.font(13)).foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 80, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(practiceFocused ? Color(nsColor: Brand.orange).opacity(0.7) : Brand.line, lineWidth: 1.5))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Brand.line))
    }

    // สถิติ 3 ช่อง
    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: "\(state.today.words)", unit: "คำ", label: "พูดวันนี้", icon: "text.bubble.fill")
            statTile(value: formatMinutes(Stats.savedMinutes(state.today)), unit: "", label: "ประหยัดเวลาพิมพ์วันนี้", icon: "bolt.fill")
            statTile(value: "\(state.streak)", unit: "วัน", label: "ใช้ติดต่อกัน", icon: "flame.fill")
        }
    }

    private func statTile(value: String, unit: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Brand.hot)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(Brand.font(26, .bold)).foregroundColor(.white)
                if !unit.isEmpty { Text(unit).font(Brand.font(13, .semibold)).foregroundColor(Brand.muted) }
            }
            Text(label).font(Brand.font(11.5)).foregroundColor(Brand.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Brand.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Brand.line))
    }

    private func formatMinutes(_ m: Double) -> String {
        if m < 1 { return m <= 0 ? "0 นาที" : "<1 นาที" }
        if m < 60 { return "\(Int(m.rounded())) นาที" }
        return String(format: "%.1f ชม.", m / 60)
    }
}

// MARK: - ตัวควบคุมหน้าต่าง

final class OnboardingWindowController: NSObject, NSWindowDelegate {
    /// หน้าต่างที่เปิดอยู่ (มาสคอตใช้คำนวณทิศสายตา)
    static weak var currentWindow: NSWindow?
    private var window: NSWindow?
    private var state: PermissionState?

    func show() {
        // ระหว่างเปิดหน้าต่าง ให้มีไอคอนใน Dock และ ⌘Tab ได้ จะได้ไม่หลงหาย
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
        let controller = NSHostingController(rootView: MainView(state: st))
        controller.sizingOptions = [.minSize]
        let w = NSWindow(contentViewController: controller)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.setContentSize(NSSize(width: 960, height: 700))
        w.setFrameAutosaveName("PoodDiWaMain")
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
        // ปล่อยทุกอย่างของหน้าต่างทันที — ปิดแล้วไม่เหลือแอนิเมชัน/ตัวจับเวลา/เคอร์เซอร์กะพริบค้างเบื้องหลัง
        state?.stop()
        if let w = window {
            w.makeFirstResponder(nil)
            DispatchQueue.main.async { w.contentViewController = nil }
        }
        window = nil
        state = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
