import AppKit

/// พิมพ์ข้อความลงแอปที่โฟกัสอยู่ โดยวางผ่านคลิปบอร์ด (⌘V) แล้วคืนคลิปบอร์ดเดิมให้
enum TextInserter {
    static func insert(_ text: String, keepInClipboard: Bool) {
        let pb = NSPasteboard.general
        let saved: [NSPasteboardItem] = keepInClipboard ? [] : snapshot(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)
        if !keepInClipboard {
            // บอกโปรแกรมจัดการคลิปบอร์ดว่าไม่ต้องจำอันนี้
            pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        }
        let ourChange = pb.changeCount

        pressCommandV()

        guard !keepInClipboard else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // ถ้าระหว่างนั้นมีคนก๊อปอย่างอื่น ไม่ไปทับ
            guard pb.changeCount == ourChange else { return }
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
    }

    private static func snapshot(_ pb: NSPasteboard) -> [NSPasteboardItem] {
        (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func pressCommandV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
