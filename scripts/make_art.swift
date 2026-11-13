// สร้างไอคอนแอป + ภาพพื้นหลัง DMG ของพูดดิวะ
// ใช้: swift scripts/make_art.swift <output-dir>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/art"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func render(width: Int, height: Int, _ draw: (CGContext) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// แบรนด์: ส้มไมค์ → แดงดุ บนดำถ่าน
let hotTop = rgb(0xFF9A1F)
let hotBottom = rgb(0xFF2D2D)
let inkTop = rgb(0x2B2B31)
let inkBottom = rgb(0x0D0D0F)
let shade = rgb(0x8E0F12)

func linear(_ ctx: CGContext, _ colors: [NSColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: colors.map { $0.cgColor } as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [])
}

/// ฟองคำพูดแบบ “ตะโกน” (หยักเหมือนการ์ตูน BAM!) พร้อมหางแหลม
func burstPath(center c: CGPoint, outer: CGFloat, inner: CGFloat, points: Int, rotation: CGFloat) -> CGPath {
    let p = CGMutablePath()
    // ความยาวแฉกไม่เท่ากัน ให้ดูมีพลัง ไม่แข็งทื่อ
    let jitter: [CGFloat] = [1.0, 0.9, 1.06, 0.94, 1.0, 0.88, 1.04, 0.96, 1.0, 0.9, 1.08, 0.93, 0.98]
    for i in 0..<(points * 2) {
        let a = rotation + CGFloat(i) * .pi / CGFloat(points)
        let r = i % 2 == 0 ? outer * jitter[(i / 2) % jitter.count] : inner
        let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    // หางแหลมชี้ลงซ้าย
    p.move(to: CGPoint(x: c.x - 150, y: c.y - 170))
    p.addLine(to: CGPoint(x: c.x - 330, y: c.y - 360))
    p.addLine(to: CGPoint(x: c.x - 30, y: c.y - 230))
    p.closeSubpath()
    return p
}

func drawIcon(_ ctx: CGContext, size s: CGFloat) {
    let k = s / 1024
    ctx.scaleBy(x: k, y: k)

    // พื้นดำถ่าน
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(tilePath); ctx.setFillColor(inkBottom.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    linear(ctx, [inkTop, inkBottom], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    // เรืองแสงส้มด้านหลังฟอง
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [rgb(0xFF5A1F, 0.45).cgColor, rgb(0xFF5A1F, 0).cgColor] as CFArray, locations: nil)!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 540, y: 560), startRadius: 0,
                           endCenter: CGPoint(x: 540, y: 560), endRadius: 470, options: [])
    ctx.restoreGState()

    let center = CGPoint(x: 530, y: 548)
    let burst = burstPath(center: center, outer: 318, inner: 246, points: 13, rotation: 0.21)

    // เงาทึบเยื้อง (สไตล์คอมิก)
    ctx.saveGState()
    ctx.translateBy(x: 18, y: -20)
    ctx.addPath(burst); ctx.setFillColor(shade.cgColor); ctx.fillPath()
    ctx.restoreGState()

    // ตัวฟองไล่สีส้ม → แดง
    ctx.saveGState()
    ctx.addPath(burst); ctx.clip()
    linear(ctx, [hotTop, hotBottom], from: CGPoint(x: 400, y: 880), to: CGPoint(x: 640, y: 200))
    ctx.restoreGState()

    // คลื่นเสียงสีขาว — แท่งกลางสูงสุด เอียงนิด ๆ ให้ดูขี้เล่น
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: -0.10)
    let heights: [CGFloat] = [120, 230, 330, 210, 110]
    let barW: CGFloat = 56, gap: CGFloat = 30
    let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    var x = -total / 2
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 0, color: shade.withAlphaComponent(0.55).cgColor)
    ctx.setFillColor(NSColor.white.cgColor)
    for h in heights {
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: -h / 2, width: barW, height: h),
                           cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil))
        x += barW + gap
    }
    ctx.fillPath()
    ctx.restoreGState()
}

// ---------- ไอคอนทุกขนาด ----------
let iconset = "\(outDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let data = render(width: px, height: px) { drawIcon($0, size: CGFloat(px)) }
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
}
try! render(width: 1024, height: 1024) { drawIcon($0, size: 1024) }
    .write(to: URL(fileURLWithPath: "\(outDir)/icon-1024.png"))

// ---------- พื้นหลัง DMG (660x420 pt) — โทนสว่าง เพราะชื่อไอคอนใน Finder เป็นตัวดำ ----------
func drawDMG(_ ctx: CGContext, scale: CGFloat) {
    ctx.scaleBy(x: scale, y: scale)
    let W: CGFloat = 660, H: CGFloat = 420
    linear(ctx, [rgb(0xFFF4EA), rgb(0xFFE3D3)], from: CGPoint(x: 0, y: H), to: CGPoint(x: 0, y: 0))

    // แถบดำด้านบน
    ctx.setFillColor(rgb(0x141417).cgColor)
    ctx.fill(CGRect(x: 0, y: H - 112, width: W, height: 112))

    func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
        let attr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                   .foregroundColor: color]
        let str = NSAttributedString(string: s, attributes: attr)
        str.draw(at: CGPoint(x: (W - str.size().width) / 2, y: y))
    }
    text("พูดดิวะ!", size: 30, weight: .black, color: rgb(0xFF6A1F), y: H - 62)
    text("ลากไปใส่ Applications แล้วเลิกพิมพ์ได้เลย", size: 13, weight: .semibold, color: rgb(0xFFFFFF, 0.8), y: H - 92)

    // ลูกศรหนา ๆ ส้ม-แดง
    let ay = H - 225
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 262, y: ay + 9)); arrow.addLine(to: CGPoint(x: 372, y: ay + 9))
    arrow.addLine(to: CGPoint(x: 372, y: ay + 26)); arrow.addLine(to: CGPoint(x: 402, y: ay))
    arrow.addLine(to: CGPoint(x: 372, y: ay - 26)); arrow.addLine(to: CGPoint(x: 372, y: ay - 9))
    arrow.addLine(to: CGPoint(x: 262, y: ay - 9)); arrow.closeSubpath()
    ctx.saveGState()
    ctx.translateBy(x: 4, y: -4)
    ctx.addPath(arrow); ctx.setFillColor(shade.withAlphaComponent(0.35).cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(arrow); ctx.clip()
    linear(ctx, [hotTop, hotBottom], from: CGPoint(x: 262, y: ay), to: CGPoint(x: 402, y: ay))
    ctx.restoreGState()

    text("เปิดครั้งแรกไม่ได้? System Settings → Privacy & Security → กด “Open Anyway”",
         size: 11.5, weight: .medium, color: rgb(0x6B4A3A), y: 30)
}
try! render(width: 660, height: 420) { drawDMG($0, scale: 1) }.write(to: URL(fileURLWithPath: "\(outDir)/dmg-bg.png"))
try! render(width: 1320, height: 840) { drawDMG($0, scale: 2) }.write(to: URL(fileURLWithPath: "\(outDir)/dmg-bg@2x.png"))
print("ok → \(outDir)")
