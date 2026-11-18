import AppKit

/// ฟังปุ่มลัดทั้งระบบ — กด / ปล่อย
///
/// • ปุ่ม modifier ปุ่มเดียว (เช่น ⌥ ขวา): ฟังแค่ flagsChanged ซึ่งเกิดไม่บ่อย
/// • ปุ่มผสม (เช่น ⌥ Space): ใช้ระบบ hotkey ของ macOS — ไม่ต้องฟังคีย์บอร์ดเองเลย
/// การฟังทุกการกดแป้น (keyDown — ไว้จับ esc / กดคู่ปุ่มอื่น) เปิดเฉพาะตอนกำลังอัดเสียง
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// มีปุ่มอื่นถูกกดระหว่างกดค้างปุ่ม modifier (ผู้ใช้น่าจะกำลังใช้คีย์ลัดอื่น)
    var onOtherKey: (() -> Void)?
    var onEscape: (() -> Void)?

    var shortcut: Shortcut = .default {
        didSet { if oldValue != shortcut { start() } }
    }

    /// ระบบไม่ยอมให้ใช้ปุ่มผสมนี้ (มีแอปอื่นจองไว้)
    private(set) var registrationFailed = false {
        didSet { HotkeyMonitor.lastRegistrationFailed = registrationFailed }
    }
    /// ให้หน้าตั้งค่าอ่านได้ว่าปุ่มลัดล่าสุดใช้ได้ไหม
    static var lastRegistrationFailed = false

    private var flagMonitors: [Any] = []
    private var keyMonitors: [Any] = []
    private let carbon = CarbonHotKey()
    private(set) var isDown = false

    init() {
        carbon.onPress = { [weak self] in
            guard let self, !self.isDown else { return } // กันปุ่มเด้งซ้ำตอนกดค้าง
            self.isDown = true
            self.onPress?()
        }
        carbon.onRelease = { [weak self] in
            guard let self, self.isDown else { return }
            self.isDown = false
            self.onRelease?()
        }
    }

    func start() {
        stopListening()
        registrationFailed = false
        switch shortcut.kind {
        case .modifier:
            if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
                self?.handleFlags(e)
            }) { flagMonitors.append(m) }
            if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
                self?.handleFlags(e); return e
            }) { flagMonitors.append(m) }
        case .combo:
            registrationFailed = !carbon.register(keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers)
            if registrationFailed { Log.write("hotkey register failed: \(shortcut.title)") }
        }
    }

    /// หยุดชั่วคราว (เช่น ระหว่างผู้ใช้กำลังตั้งปุ่มลัดใหม่)
    func stopListening() {
        (flagMonitors + keyMonitors).forEach { NSEvent.removeMonitor($0) }
        flagMonitors.removeAll()
        keyMonitors.removeAll()
        carbon.unregister()
        isDown = false
    }

    /// เปิด/ปิดการฟังทุกการกดแป้น — เปิดเฉพาะช่วงกำลังอัดเสียง
    func watchKeys(_ on: Bool) {
        if on {
            guard keyMonitors.isEmpty else { return }
            if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
                self?.handleKeyDown(e)
            }) { keyMonitors.append(m) }
            if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
                self?.handleKeyDown(e); return e
            }) { keyMonitors.append(m) }
        } else {
            keyMonitors.forEach { NSEvent.removeMonitor($0) }
            keyMonitors.removeAll()
        }
    }

    private func handleFlags(_ e: NSEvent) {
        guard let hk = shortcut.hotkey, e.keyCode == hk.keyCode else { return }
        let pressed = (e.modifierFlags.rawValue & hk.deviceMask) != 0
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
        // ปุ่มผสมมีปุ่มอื่นอยู่ในตัวอยู่แล้ว — เช็กเฉพาะแบบปุ่ม modifier เดียว
        if isDown, shortcut.kind == .modifier, !e.isARepeat { onOtherKey?() }
    }
}
