import AVFoundation
import Speech

enum SpeechError: LocalizedError {
    case unavailable
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .unavailable: "ตัวแปลงเสียงยังไม่พร้อม (เช็กอินเทอร์เน็ต)"
        case .noMicrophone: "ไม่พบไมโครโฟน"
        }
    }
}

/// อัดเสียงจากไมค์ แล้วส่งให้ SFSpeechRecognizer แปลงเป็นข้อความแบบสด
final class SpeechEngine {
    var onPartial: ((String) -> Void)?
    var onLevel: ((Float) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestText = ""
    private var finishHandler: ((String) -> Void)?
    private var session = 0
    private var tapInstalled = false

    func start(language: Language) throws {
        cancel()
        session += 1
        let mySession = session

        guard let r = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue)), r.isAvailable else {
            throw SpeechError.unavailable
        }
        recognizer = r

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        req.taskHint = .dictation
        req.contextualStrings = Settings.shared.vocabulary
        request = req
        latestText = ""

        task = r.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.session == mySession else { return }
                if let result {
                    self.latestText = result.bestTranscription.formattedString
                    self.onPartial?(self.latestText)
                    if result.isFinal { self.finish() }
                }
                if error != nil { self.finish() }
            }
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            cancel()
            throw SpeechError.noMicrophone
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            guard let data = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            if n == 0 { return }
            var sum: Float = 0
            for i in 0..<n { sum += data[i] * data[i] }
            let rms = sqrt(sum / Float(n))
            // แปลงเป็น 0...1 แบบ dB
            let db = 20 * log10(max(rms, 0.000_01))
            let level = max(0, min(1, (db + 50) / 40))
            DispatchQueue.main.async { self?.onLevel?(level) }
        }
        tapInstalled = true
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cancel()
            throw error
        }
    }

    /// หยุดอัด แล้วรอผลสุดท้าย (มี timeout กันค้าง)
    func stop(completion: @escaping (String) -> Void) {
        stopAudio()
        finishHandler = completion
        request?.endAudio()
        let mySession = session
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self, self.session == mySession else { return }
            self.finish()
        }
    }

    func cancel() {
        stopAudio()
        finishHandler = nil
        task?.cancel()
        task = nil
        request = nil
        session += 1
    }

    private func stopAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private func finish() {
        guard let handler = finishHandler else { return }
        finishHandler = nil
        let text = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        task?.cancel()
        task = nil
        request = nil
        session += 1
        handler(text)
    }
}
