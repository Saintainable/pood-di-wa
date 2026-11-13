import AppKit
import AVFoundation
import Speech
import ApplicationServices

enum Permissions {
    static var micGranted: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    static var speechGranted: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }
    /// การรู้จำเสียงของ Apple ต้องใช้เฉพาะตอนเลือก engine Apple
    static var allGranted: Bool {
        let s = Settings.shared
        let engineReady = s.engine == .apple ? speechGranted : s.hasGeminiKey
        return micGranted && accessibilityGranted && engineReady
    }

    static func requestMic(_ done: @escaping () -> Void = {}) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in DispatchQueue.main.async(execute: done) }
        case .authorized:
            done()
        default:
            openPrivacy("Privacy_Microphone")
            done()
        }
    }

    static func requestSpeech(_ done: @escaping () -> Void = {}) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { _ in DispatchQueue.main.async(execute: done) }
        case .authorized:
            done()
        default:
            openPrivacy("Privacy_SpeechRecognition")
            done()
        }
    }

    static func requestAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            openPrivacy("Privacy_Accessibility")
        }
    }

    static func openPrivacy(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
