import AppKit
import SwiftUI

/// มาสคอต “พูดดิวะ” — ก้อนกลมสีขาวตัวเบิ้ม ตาเม็ดยาดำ มือกลม ๆ ชูขึ้น (มินิมอล ไม่มีอิโมจิ)
/// ตามองตามเมาส์ · กะพริบตา · ยิ่งจิ้มยิ่งโมโห ตัวค่อย ๆ เปลี่ยนจากขาว → ส้ม → แดง แล้วค่อยใจเย็นลง
/// ปิดรับเสียงแล้วหลับ
struct MascotView: View {
    var sleeping: Bool
    var onPoke: () -> Void
    var line: String? = nil

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

    private let ink = Color(red: 0.07, green: 0.07, blue: 0.08)

    var body: some View {
        TimelineView(.animation) { tl in
            figure(now: tl.date.timeIntervalSinceReferenceDate,
                   poke: tl.date.timeIntervalSince(pokedAt),
                   anger: currentRage(at: tl.date))
        }
        .frame(width: Self.frameSize.width, height: Self.frameSize.height)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            let now = Date()
            rage = min(1, currentRage(at: now) + 0.34)
            rageAt = now
            pokedAt = now
            onPoke()
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { frameInWindow = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { frameInWindow = $0 }
        })
    }

    /// โมโหค่อย ๆ หายไป ~3 วินาทีจากเต็ม
    private func currentRage(at date: Date) -> Double {
        max(0, rage - date.timeIntervalSince(rageAt) * 0.33)
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
            // มือกลม ๆ ชูขึ้น (หลับ = ลดลงข้างตัว)
            Circle()
                .fill(color)
                .frame(width: 46, height: 46)
                .position(x: sleeping ? c.x - 96 : c.x - 112, y: sleeping ? c.y + 30 : c.y - 70 + fistBob)

            // ตัว
            Circle()
                .fill(color)
                .frame(width: d, height: d)
                .scaleEffect(x: 1 / squash, y: squash, anchor: .bottom)
                .position(x: c.x, y: c.y)

            // ตา
            HStack(spacing: 24) {
                eye(blink: blink, tilt: 12 + 18 * anger, height: 42 - 14 * anger)
                eye(blink: blink, tilt: -(12 + 18 * anger), height: 42 - 14 * anger)
            }
            .position(x: c.x - 10 + look.dx * 14, y: c.y - 26 + look.dy * 10 - (squash - 1) * 60)

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

enum MascotLines {
    static let awake = ["พูดดิวะ!", "พิมพ์ทำไม พูดเลย!", "กด ⌥ ขวาค้างดิ!", "จิ้มหาเรื่องเหรอ?", "มาดิ พร้อมฟังแล้ว!",
                        "เมื่อยมือก็พูดสิวะ", "อย่ามาจิ้ม!", "มีอะไรว่ามา!"]
    static let angry = ["บอกว่าอย่าจิ้ม!", "เดือดแล้วนะ!", "พอได้แล้วโว้ย!", "จะเอาเรื่องใช่มั้ย!"]
    static let asleep = ["ปิดอยู่… ฝันดี", "zzz… เปิดสวิตช์ก่อน", "ง่วง… ปลุกที่สวิตช์ข้าง ๆ"]
}
