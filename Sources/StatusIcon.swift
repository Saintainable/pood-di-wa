import AppKit

/// ไอคอนบนแถบเมนู — ทรงเดียวกับโลโก้แอป: ฟองคำพูดหยัก (ตะโกน) + คลื่นเสียง 5 แท่ง
/// ปกติ = ขาวดำตามธีม (template) · กำลังอัด = ส้ม→แดง · ปิดรับเสียง = จาง + ขีดฆ่า
enum StatusIcon {
    enum Mode { case idle, recording, off }

    private static var cache: [Mode: NSImage] = [:]

    static func image(_ mode: Mode) -> NSImage {
        if let img = cache[mode] { return img }
        let size = NSSize(width: 19, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(ctx, mode: mode)
            return true
        }
        img.isTemplate = mode != .recording
        img.accessibilityDescription = "พูดดิวะ"
        cache[mode] = img
        return img
    }

    /// ฟองหยัก 13 แฉก (เหมือนโลโก้) + หางแหลมชี้ลงซ้าย — พิกัดแกน y ชี้ขึ้น
    private static func burst() -> CGPath {
        let c = CGPoint(x: 10.2, y: 10.0)
        let outer: CGFloat = 8.0, inner: CGFloat = 6.6
        let jitter: [CGFloat] = [1.0, 0.92, 1.05, 0.95, 1.0, 0.9, 1.04, 0.96, 1.0, 0.92, 1.06, 0.94, 0.98]
        let p = CGMutablePath()
        let n = 13
        for i in 0..<(n * 2) {
            let a = 0.21 + CGFloat(i) * .pi / CGFloat(n)
            let r = i % 2 == 0 ? outer * jitter[(i / 2) % jitter.count] : inner
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        p.move(to: CGPoint(x: 6.4, y: 5.4))
        p.addLine(to: CGPoint(x: 1.2, y: 0.6))
        p.addLine(to: CGPoint(x: 9.4, y: 3.8))
        p.closeSubpath()
        return p
    }

    private static func bars() -> CGPath {
        let heights: [CGFloat] = [3.0, 5.4, 7.6, 5.0, 2.8]
        let w: CGFloat = 1.45, gap: CGFloat = 0.85
        let total = CGFloat(heights.count) * w + CGFloat(heights.count - 1) * gap
        var x = 10.2 - total / 2
        let cy: CGFloat = 10.0
        let p = CGMutablePath()
        for h in heights {
            p.addPath(CGPath(roundedRect: CGRect(x: x, y: cy - h / 2, width: w, height: h),
                             cornerWidth: w / 2, cornerHeight: w / 2, transform: nil))
            x += w + gap
        }
        return p
    }

    private static func draw(_ ctx: CGContext, mode: Mode) {
        switch mode {
        case .idle:
            ctx.addPath(burst()); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
            ctx.setBlendMode(.clear)
            ctx.addPath(bars()); ctx.fillPath()
        case .recording:
            ctx.saveGState()
            ctx.addPath(burst()); ctx.clip()
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [Brand.amber.cgColor, Brand.red.cgColor] as CFArray, locations: nil)!
            ctx.drawLinearGradient(g, start: CGPoint(x: 4, y: 18), end: CGPoint(x: 15, y: 0), options: [])
            ctx.restoreGState()
            ctx.addPath(bars()); ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()
        case .off:
            ctx.setAlpha(0.45)
            ctx.addPath(burst()); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
            ctx.setBlendMode(.clear)
            ctx.addPath(bars()); ctx.fillPath()
            ctx.setBlendMode(.normal)
            ctx.setAlpha(1)
            // ขีดฆ่า
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.6); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 2.5, y: 16)); ctx.addLine(to: CGPoint(x: 17, y: 2)); ctx.strokePath()
        }
    }
}
