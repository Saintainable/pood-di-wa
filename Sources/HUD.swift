import AppKit
import SwiftUI
import Combine

final class HUDModel: ObservableObject {
    enum Phase: Equatable {
        case listening
        case handsFree
        case processing
        case message(String)
    }

    @Published var phase: Phase = .listening
    @Published var level: CGFloat = 0
    /// ข้อความสดระหว่างพูด — แสดงเฉพาะตอนเปิดตัวเลือก “โชว์คำที่พูด”
    @Published var text: String = ""
    @Published var showText = false
    /// แถบแสดงอยู่ไหม — ซ่อนแล้วหยุดแอนิเมชันทั้งหมด (ไม่กิน CPU ตอนอยู่เบื้องหลัง)
    @Published var visible = false
    /// กำลังพูดสั่งแก้ข้อความที่ไฮไลต์ไว้
    @Published var editing = false
    var hotkeyShort: String = "⌥ ขวา"
}

/// แถบเล็ก ๆ สีดำ มีแค่คลื่นเสียงส้ม-แดง ไม่บังจอ
struct HUDView: View {
    @ObservedObject var model: HUDModel
    private let bars = 11
    private let weights: [CGFloat] = [0.35, 0.55, 0.75, 0.9, 1.0, 0.85, 1.0, 0.9, 0.7, 0.5, 0.35]

    var body: some View {
        content
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.94)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .message(let m):
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(Brand.font(13, .bold))
                    .foregroundStyle(Brand.hot)
                Text(m)
                    .font(Brand.font(12, .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        default:
            HStack(spacing: 8) {
                indicator
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.visible)) { tl in
                    wave(t: tl.date.timeIntervalSinceReferenceDate)
                }
                .frame(width: 66, height: 20)
                if model.showText && !model.text.isEmpty {
                    Text(model.text)
                        .font(Brand.font(12.5, .semibold))
                        .foregroundColor(.white.opacity(model.phase == .processing ? 0.55 : 0.92))
                        .lineLimit(1)
                        .truncationMode(.head) // ข้อความยาว ให้เห็นท้ายประโยคล่าสุด
                        .frame(width: textWidth(model.text), alignment: .leading)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.text.isEmpty)
        }
    }

    /// จุดแดงกระพริบ = กำลังอัด, รูปกุญแจ = โหมดพูดยาว (ไม่ต้องกดค้าง)
    @ViewBuilder private var indicator: some View {
        switch model.phase {
        case .handsFree:
            Image(systemName: "lock.fill")
                .font(Brand.font(9, .bold))
                .foregroundColor(Color(nsColor: Brand.orange))
                .frame(width: 10)
        case .processing:
            Circle().fill(Color.white.opacity(0.35)).frame(width: 7, height: 7).frame(width: 10)
        case _ where model.editing:
            Image(systemName: "pencil")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(nsColor: Brand.orange))
                .frame(width: 12)
                .help("พูดสั่งแก้ข้อความที่เลือกไว้")
        default:
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.visible)) { tl in
                let pulse = 0.55 + 0.45 * abs(sin(tl.date.timeIntervalSinceReferenceDate * 3))
                Circle().fill(Color(nsColor: Brand.red)).frame(width: 7, height: 7).opacity(pulse)
            }
            .frame(width: 10)
        }
    }

    private func wave(t: Double) -> some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<bars, id: \.self) { i in
                Capsule()
                    .fill(Brand.hot)
                    .frame(width: 3.5, height: barHeight(i, t))
                    .opacity(model.phase == .processing ? 0.75 : 1)
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// ความกว้างพอดีข้อความ ไม่เกิน 340 — แถบจะได้ยืดตามจริง ไม่เต็มตลอด
    private func textWidth(_ s: String) -> CGFloat {
        let w = (s as NSString).size(withAttributes: [.font: Brand.nsFont(12.5, bold: true)]).width
        return min(340, ceil(w) + 2)
    }

    private func barHeight(_ i: Int, _ t: Double) -> CGFloat {
        if model.phase == .processing {
            // คลื่นวิ่งช้า ๆ = กำลังคิด
            return 4 + 9 * CGFloat(0.5 + 0.5 * sin(t * 7 - Double(i) * 0.6))
        }
        let wobble = CGFloat(0.7 + 0.3 * sin(t * 13 + Double(i) * 1.7))
        return 3.5 + min(1, model.level * 1.25) * 16 * weights[i] * wobble
    }
}

/// หน้าต่างลอยด้านล่างจอ ไม่แย่งโฟกัสจากแอปที่ผู้ใช้กำลังพิมพ์
final class HUDController {
    let model = HUDModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    private func makePanel() -> NSPanel {
        let host = NSHostingView(rootView: HUDView(model: model))
        let size = NSSize(width: 560, height: 64)
        host.frame = NSRect(origin: .zero, size: size)
        let p = NSPanel(contentRect: host.frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.contentView = host
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return p
    }

    func show() {
        model.visible = true
        hideWork?.cancel()
        let p = panel ?? makePanel()
        panel = p
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: vf.midX - p.frame.width / 2, y: vf.minY + 14))
        }
        if !p.isVisible {
            p.alphaValue = 0
            p.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                p.animator().alphaValue = 1
            }
        }
    }

    func hide(after delay: TimeInterval = 0) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let p = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.orderOut(nil)
                self?.model.level = 0
                self?.model.visible = false
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func flash(_ message: String) {
        model.phase = .message(message)
        show()
        hide(after: 2.5)
    }
}
