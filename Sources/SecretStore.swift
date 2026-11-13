import Foundation

/// เก็บ API key เป็นไฟล์ที่อ่านได้เฉพาะผู้ใช้คนนี้ (สิทธิ์ 600)
/// ไม่ใช้ Keychain เพราะแอปเซ็นแบบ ad-hoc — ทุกครั้งที่อัปเดต macOS จะเด้งถามรหัสผ่าน
enum SecretStore {
    private static var dir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PoodDiWa", isDirectory: true)
    }

    private static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }

    static func get(_ name: String) -> String? {
        guard let s = try? String(contentsOf: url(name), encoding: .utf8) else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static func set(_ value: String?, for name: String) {
        let fm = FileManager.default
        let file = url(name)
        guard let value, !value.isEmpty else {
            try? fm.removeItem(at: file)
            return
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        fm.createFile(atPath: file.path, contents: Data(value.utf8), attributes: [.posixPermissions: 0o600])
    }
}
