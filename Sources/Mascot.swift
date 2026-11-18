import AppKit
import SwiftUI

/// มาสคอต “พูดดิวะ” — ก้อนกลมสีขาวตัวเบิ้ม ตาเม็ดยาดำ มือกลม ๆ ชูขึ้น (มินิมอล ไม่มีอิโมจิ)
/// ตามองตามเมาส์ · กะพริบตา · ยิ่งจิ้มยิ่งโมโห ตัวค่อย ๆ เปลี่ยนจากขาว → ส้ม → แดง แล้วค่อยใจเย็นลง
/// ปิดรับเสียงแล้วหลับ
struct MascotView: View {
    var sleeping: Bool
    var onPoke: () -> Void = {}
    /// ตัดตัวทิ้งใต้เส้นนี้ (พิกัด y ในกรอบมาสคอต) = ขอบบนของการ์ด
    var clipY: CGFloat? = nil
    /// สำหรับพรีวิว: บังคับระดับความโมโห
    var debugRage: Double? = nil

    /// ระดับที่เริ่มชูมือ / ระดับที่ชูนิ้วกลาง + เซ็นเซอร์
    static let fistFrom = 0.2, fingerFrom = 0.85

    /// กรอบของมาสคอต และจุดกึ่งกลางตัวในกรอบ (ใช้วางตำแหน่งจากภายนอก)
    static let frameSize = CGSize(width: 290, height: 230)
    static let bodyCenter = CGPoint(x: 175, y: 128)
    static let bodyDiameter: CGFloat = 176

    @State private var rage: Double = 0          // 0 = ใจเย็น … 1 = เดือดสุด
    @State private var rageAt = Date()
    @State private var pokedAt = Date.distantPast
    @State private var hovering = false
    @State private var blinkSeed = Double.random(in: 0...10)
    @State private var frameInWindow: CGRect = .zero
    @State private var windowVisible = true
    // คำพูด — เก็บไว้ในตัวมาสคอตเอง จิ้มแล้ววาดใหม่แค่มาสคอต ไม่ลากทั้งหน้าตั้งค่า
    @State private var line: String?
    /// ตัวช่วยให้ปากขยับลื่น (อัปเดตทุกเฟรม ไม่ทำให้หน้าจอวาดใหม่เอง)
    @State private var mouth = MouthSmoother()
    @State private var lineID = 0
    @State private var pokeTimes: [Date] = []
    @ObservedObject private var voice = VoiceActivity.shared

    private let ink = Color(red: 0.07, green: 0.07, blue: 0.08)

    var body: some View {
        // หน้าต่างเปิดอยู่ = เน้นลื่น: ชี้เมาส์/โดนจิ้ม/กำลังพูด เต็มเฟรมเรตจอ · นิ่ง ๆ 30 fps
        // หน้าต่างถูกบัง/ย่อ/ปิด = หยุดวาดเลย
        let lively = hovering || voice.listening || line != nil || mouth.presence > 0.02 || Date().timeIntervalSince(rageAt) < 4.5
        TimelineView(.animation(minimumInterval: lively ? nil : 1.0 / 30, paused: !windowVisible)) { tl in
            figure(now: tl.date.timeIntervalSinceReferenceDate,
                   poke: tl.date.timeIntervalSince(pokedAt),
                   anger: debugRage ?? currentRage(at: tl.date))
        }
        .frame(width: Self.frameSize.width, height: Self.frameSize.height)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            let now = Date()
            rage = min(1, currentRage(at: now) + 0.25) // จิ้มรัว 4 ที = เดือดสุด
            rageAt = now
            pokedAt = now
            say(at: now)
            onPoke()
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { frameInWindow = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { frameInWindow = $0 }
        })
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { n in
            guard let w = n.object as? NSWindow, w === OnboardingWindowController.currentWindow else { return }
            windowVisible = w.occlusionState.contains(.visible)
        }
    }

    /// โมโหค่อย ๆ หายไป ~3 วินาทีจากเต็ม
    private func currentRage(at date: Date) -> Double {
        max(0, rage - date.timeIntervalSince(rageAt) * 0.33)
    }

    /// ระดับปากตอนมาสคอตพูดเอง — ขยับเป็นจังหวะพยางค์
    /// ระดับปากตอนมาสคอตพูดเอง — คลื่นเรียบ (ไม่มีมุมหักตอนหุบ) จังหวะพยางค์ + ขึ้นลงตามวลี
    static func chatLevel(_ now: TimeInterval) -> CGFloat {
        let syllable: Double = 0.5 - 0.5 * cos(now * 12)
        let phrase: Double = 0.6 + 0.4 * sin(now * 3.3)
        return CGFloat(0.15 + 0.7 * syllable * phrase)
    }

    private func say(at now: Date) {
        pokeTimes = pokeTimes.filter { now.timeIntervalSince($0) < 3 } + [now]
        let pool = sleeping ? MascotLines.asleep : pokeTimes.count >= 3 ? MascotLines.angry : MascotLines.awake
        var next = pool.randomElement()!
        if next == line, pool.count > 1 { next = pool.filter { $0 != next }.randomElement()! }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            line = next
            lineID += 1
        }
        let id = lineID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard id == lineID else { return }
            withAnimation(.easeOut(duration: 0.2)) { line = nil }
        }
    }

    /// สีตัว: ขาว → ส้ม → แดง ตามความโมโห (หลับ = เทาอ่อน)
    private func bodyColor(_ r: Double) -> Color {
        if sleeping { return Color(white: 0.78) }
        let white = (1.0, 1.0, 1.0), orange = (1.0, 0.56, 0.22), red = (1.0, 0.17, 0.17)
        let (a, b, t) = r < 0.5 ? (white, orange, r * 2) : (orange, red, (r - 0.5) * 2)
        return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }

    private func figure(now: TimeInterval, poke: TimeInterval, anger: Double) -> some View {
        let c = Self.bodyCenter
        let d = Self.bodyDiameter
        let decay = max(0, 1 - poke / 0.8)
        // เด้งตอนโดนจิ้ม / หายใจ / สั่นตามความโมโห
        let squash = 1 + 0.07 * decay * sin(poke * 24) + (sleeping ? 0.015 : 0.008) * sin(now * 2.2)
        let shake = (3 * decay + 2.2 * anger) * sin(now * 58)
        let blink = !sleeping && fmod(now + blinkSeed, 4.3) < 0.12
        let look = sleeping ? CGVector.zero : lookDirection()
        let color = bodyColor(anger)
        let fistBob = sleeping ? 0 : (6 * decay + 3 * anger) * sin(now * 30) + (hovering ? 2 * sin(now * 12) : 1.5 * sin(now * 2.6))
        let zPhase = fmod(now, 2.4) / 2.4

        return ZStack(alignment: .topLeading) {
            // แขน + มือ: ปกติซ่อนหลังการ์ด → เริ่มโมโหยกขึ้นแค่ระดับหัว → เดือดสุดชูนิ้วกลาง (ทับโมเสก)
            let t = sleeping ? 0 : min(1, max(0, (anger - Self.fistFrom) / 0.25))
            let raise = t * t * (3 - 2 * t)
            let finger = !sleeping && anger >= Self.fingerFrom
            // ท่า “ข้างแก้ม”: ไหล่ต่ำชิดขอบการ์ด แขนตรงเฉียงขึ้น มือระดับตาชิดหน้า
            let shoulder = CGPoint(x: c.x - 60, y: c.y + 6)               // ตัวบังโคนแขน
            let down = CGPoint(x: c.x - 96, y: c.y + 70)                  // ใต้ขอบการ์ด = มองไม่เห็น
            let up = CGPoint(x: c.x - 104, y: c.y - 24 + fistBob)
            let hand = CGPoint(x: down.x + (up.x - down.x) * raise, y: down.y + (up.y - down.y) * raise)
            Arm(from: shoulder, to: hand, bend: 4)
                .stroke(color, style: StrokeStyle(lineWidth: 17, lineCap: .round))

            // ตัว
            Circle()
                .fill(color)
                .frame(width: d, height: d)
                .scaleEffect(x: 1 / squash, y: squash, anchor: .bottom)
                .position(x: c.x, y: c.y)

            // มือ — อยู่ชั้นหน้าตัว (เงาบาง ๆ แยกมือออกจากตัวที่สีเดียวกัน)
            Group {
                if finger {
                    MosaicFinger(color: color, now: now)
                        .position(x: hand.x, y: hand.y - 26)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 42, height: 42)
                        .position(x: hand.x, y: hand.y)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 3, x: 1, y: 2)

            // ตาแคปซูลตั้งตรง (โมโหแล้วค่อยเอียงเข้าหากัน) · ตอนพูดขยับขึ้นให้ที่ปาก
            // “พูด” = ผู้ใช้กำลังพูด (ปากตามเสียงจริง) หรือมาสคอตกำลังพูดตอบตอนโดนจิ้ม (ปากขยับเอง)
            let listening = voice.listening && !sleeping
            let chatting = line != nil && !sleeping && !listening
            let talking = listening || chatting
            // ไหลทุกเฟรมเหมือนลูกตา: ค่าความดังเข้ามาเป็นก้อน ๆ แต่ปากค่อย ๆ ไหลตาม (อ้าเร็ว หุบช้ากว่านิด)
            let target: CGFloat = listening ? min(1, voice.level * 1.35) : chatting ? Self.chatLevel(now) : 0
            let m = mouth.step(now: now, level: target, present: talking)
            let p = m.presence // 0 = ไม่พูด … 1 = กำลังพูด (ใช้ค่อย ๆ ขยับตาขึ้นและโผล่ปาก)
            let eyeH: CGFloat = (42 - 14 * anger) + (30 - (42 - 14 * anger)) * p
            HStack(spacing: 26) {
                eye(blink: blink, tilt: 20 * anger, height: eyeH)
                eye(blink: blink, tilt: -20 * anger, height: eyeH)
            }
            .position(x: c.x - 10 + look.dx * 14, y: c.y - 26 - 20 * p + look.dy * 10 - (squash - 1) * 60)

            // ปากวงกลมสีเดียว (#5C0D17) ไม่มีขอบ — โตตามความดังเสียง
            if p > 0.02 {
                let lv = m.level
                let d = (12 + lv * 22) * p
                Ellipse()
                    .fill(Color(red: 0x5C / 255.0, green: 0x0D / 255.0, blue: 0x17 / 255.0))
                    .frame(width: d * (1 - lv * 0.12), height: d)
                    .position(x: c.x - 10 + look.dx * 6, y: c.y - 11)
            }

            // เดือดสุด: แถบดำเซ็นเซอร์คำสบถที่ปาก
            if !sleeping && anger >= Self.fingerFrom {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(Color.black)
                    Text("#@$%&!")
                        .font(Brand.font(11, .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(x: sin(now * 40) * 1.2)
                }
                .frame(width: 96, height: 19)
                .rotationEffect(.degrees(-4))
                .position(x: c.x - 10, y: line != nil || voice.listening ? c.y - 11 : c.y + 1) // ทับปากพอดี
            }

            if sleeping {
                Text("z")
                    .font(Brand.font(16 + zPhase * 10, .bold))
                    .foregroundColor(.white.opacity(1 - zPhase * 0.85))
                    .position(x: c.x + 70 + zPhase * 16, y: c.y - 84 - zPhase * 22)
            }

            if let line {
                Text(line)
                    .font(Brand.font(13, .bold))
                    .foregroundColor(ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.white))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .fixedSize()
                    .position(x: c.x - 112, y: c.y - 112)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .offset(x: shake)
        .frame(width: Self.frameSize.width, height: Self.frameSize.height, alignment: .topLeading)
        .drawingGroup() // รวมเป็นภาพเดียวบน GPU — ถูกกว่าวาดทีละชิ้น
        // ตัดส่วนที่อยู่ใต้ขอบการ์ด — ตัวจะไม่โผล่ในช่องว่างระหว่างการ์ด
        .mask(alignment: .top) {
            // กว้างเกินกรอบไว้ — ตัดแค่ขอบล่าง ไม่ให้ข้อความที่ยื่นออกซ้าย/ขวาโดนหั่น
            Rectangle().frame(width: 2000, height: clipY ?? Self.frameSize.height)
        }
    }

    @ViewBuilder
    private func eye(blink: Bool, tilt: Double, height: CGFloat) -> some View {
        if sleeping {
            Capsule().fill(ink).frame(width: 24, height: 6)
        } else {
            Capsule().fill(ink)
                .frame(width: 19, height: height)
                .scaleEffect(y: blink ? 0.1 : 1)
                .rotationEffect(.degrees(tilt))
        }
    }

    /// ทิศจากหัวไปหาเมาส์ (-1...1)
    private func lookDirection() -> CGVector {
        guard let win = OnboardingWindowController.currentWindow else { return .zero }
        let mouse = NSEvent.mouseLocation
        // พิกัด .global ของ SwiftUI = มุมซ้ายบนของเนื้อหาหน้าต่าง
        let hx = frameInWindow.minX + Self.bodyCenter.x
        let hy = frameInWindow.minY + Self.bodyCenter.y - 26
        let dx = mouse.x - (win.frame.minX + hx)
        let dy = -(mouse.y - (win.frame.maxY - hy))
        let len = max(1, sqrt(dx * dx + dy * dy))
        let reach = min(1, len / 220)
        return CGVector(dx: dx / len * reach, dy: dy / len * reach)
    }
}

/// ทำให้ปากไหลลื่น — เก็บค่าที่แสดงอยู่ แล้วไหลเข้าหาเป้าหมายทุกเฟรมแบบ exponential
/// (เป็น class: แก้ค่าได้ระหว่างวาดโดยไม่สั่งให้วาดใหม่)
final class MouthSmoother {
    private(set) var level: CGFloat = 0
    private(set) var presence: CGFloat = 0
    private var last: TimeInterval = 0

    func step(now: TimeInterval, level target: CGFloat, present: Bool) -> (level: CGFloat, presence: CGFloat) {
        let dt = last == 0 ? 1.0 / 60 : min(0.1, max(0, now - last))
        last = now
        let rate: CGFloat = target > level ? 26 : 11       // อ้าเร็ว หุบช้ากว่า
        level += (target - level) * (1 - exp(-rate * CGFloat(dt)))
        let pTarget: CGFloat = present ? 1 : 0
        presence += (pTarget - presence) * (1 - exp(-14 * CGFloat(dt)))
        return (level, presence)
    }
}

/// สถานะเสียงตอนกำลังพูด — ให้มาสคอตขยับปากตาม (ค่า level ไม่ประกาศการเปลี่ยน เลยไม่ทำให้หน้าจอวาดใหม่เอง)
final class VoiceActivity: ObservableObject {
    static let shared = VoiceActivity()
    @Published var listening = false
    /// ระดับเสียง 0…1 (มาสคอตอ่านทุกเฟรมเอง)
    var level: CGFloat = 0
}

enum MascotLines {
    static let awake = ["พูดดิวะ!", "พิมพ์ทำไม พูดเลย!", "กด ⌥ ขวาค้างดิ!", "จิ้มหาเรื่องเหรอ?", "มาดิ พร้อมฟังแล้ว!",
                        "เมื่อยมือก็พูดสิวะ", "อย่ามาจิ้ม!", "มีอะไรว่ามา!"]
    static let angry = ["บอกว่าอย่าจิ้ม!", "เดือดแล้วนะ!", "พอได้แล้วโว้ย!", "จะเอาเรื่องใช่มั้ย!", "ปี๊บ! ปี๊บ!"]
    static let asleep = ["ปิดอยู่… ฝันดี", "zzz… เปิดสวิตช์ก่อน", "ง่วง… ปลุกที่สวิตช์ข้าง ๆ"]
}

/// แขนจากไหล่ถึงมือ (bend = ความโค้ง)
struct Arm: Shape {
    var from: CGPoint
    var to: CGPoint
    var bend: CGFloat = 4
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: from)
        p.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2 - bend, y: (from.y + to.y) / 2 + bend * 0.6))
        return p
    }
}

/// นิ้วกลางแบบพิกเซล — ตั้งใจให้เป็นโมเสกเซ็นเซอร์ตั้งแต่แรก (ขี้เล่น ไม่หยาบเกิน)
struct MosaicFinger: View {
    var color: Color
    var now: TimeInterval

    // 1 = มือ, 2 = ขอบเบลอ
    private static let grid: [[Int]] = [
        [0, 0, 2, 2, 1, 2, 2, 0, 0],
        [0, 0, 2, 1, 1, 1, 2, 0, 0],
        [0, 0, 2, 1, 1, 1, 2, 0, 0],
        [0, 0, 2, 1, 1, 1, 2, 0, 0],
        [0, 2, 2, 1, 1, 1, 2, 2, 0],
        [2, 1, 1, 1, 1, 1, 1, 1, 2],
        [2, 1, 1, 1, 1, 1, 1, 1, 1],
        [2, 1, 1, 1, 1, 1, 1, 1, 1],
        [2, 1, 1, 1, 1, 1, 1, 1, 2],
        [0, 2, 1, 1, 1, 1, 1, 1, 2],
        [0, 0, 2, 1, 1, 1, 1, 2, 0],
        [0, 0, 2, 2, 1, 1, 2, 0, 0],
    ]
    private let cell: CGFloat = 7

    var body: some View {
        let frame = Int(now * 7) // กะพริบลายโมเสกเบา ๆ
        Canvas { ctx, _ in
            for (r, row) in Self.grid.enumerated() {
                for (c, v) in row.enumerated() where v > 0 {
                    let h = (r * 73 + c * 151 + (frame % 3) * 37) % 100
                    let shade = 0.78 + Double(h) / 100 * 0.3
                    let alpha = v == 2 ? 0.45 + Double(h % 30) / 100 : 1
                    let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
                    ctx.fill(Path(rect), with: .color(color.opacity(alpha)))
                    ctx.fill(Path(rect), with: .color(Color.black.opacity(max(0, 1 - shade) * 0.9)))
                }
            }
        }
        .frame(width: cell * 9, height: cell * 12)
    }
}
