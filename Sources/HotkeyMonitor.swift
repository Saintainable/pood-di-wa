import AppKit

/// ฟังปุ่ม modifier ตัวเดียว (เช่น Option ขวา) ทั้งระบบ — กดค้าง / ปล่อย
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// มีปุ่มอื่นถูกกดระหว่างกดค้าง (ผู้ใช้น่าจะกำลังใช้คีย์ลัดอื่น)
    var onOtherKey: (() -> Void)?
    var onEscape: (() -> Void)?

    var hotkey: Hotkey = .rightOption {
        didSet { isDown = false }
    }

    private var monitors: [Any] = []
    private(set) var isDown = false

    func start() {
        stop()
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            self?.handleFlags(e)
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            self?.handleFlags(e); return e
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            self?.handleKeyDown(e)
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            self?.handleKeyDown(e); return e
        }) { monitors.append(m) }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        isDown = false
    }

    private func handleFlags(_ e: NSEvent) {
        guard e.keyCode == hotkey.keyCode else { return }
        let pressed = (e.modifierFlags.rawValue & hotkey.deviceMask) != 0
        if pressed && !isDown {
            isDown = true
            onPress?()
        } else if !pressed && isDown {
            isDown = false
            onRelease?()
        }
    }

    private func handleKeyDown(_ e: NSEvent) {
        if e.keyCode == 53 { // Esc
            onEscape?()
            return
        }
        if isDown { onOtherKey?() }
    }
}
