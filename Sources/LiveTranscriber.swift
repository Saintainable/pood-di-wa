import AVFoundation
import Foundation

/// ผลการถอดเสียง: smart = ข้อความเรียบร้อย (ตัด “เอาใหม่”/คำฟุ่มเฟือยแล้ว), verbatim = ตามที่พูดจริงทุกคำ (ไว้จับคำสั่ง)
struct LiveResult {
    var smart: String
    var verbatim: String
}

/// การเชื่อมต่อ Gemini Live 1 สาย (WebSocket) — ทุกอย่างทำงานบน main thread
final class LiveSession {
    enum Mode: String { case smart = "SMART", verbatim = "VERBATIM" }

    let mode: Mode
    var onPartial: ((String) -> Void)?
    var onDone: (() -> Void)?

    private var socket: URLSessionWebSocketTask?
    private(set) var ready = false
    private var outbox: [String] = []
    private var finals: [String] = []
    private var interim = ""
    private var ended = false
    private(set) var done = false
    private(set) var error: Error?
    private let startedAt = Date()

    var text: String {
        (finals + (interim.isEmpty ? [] : [interim])).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(apiKey: String, mode: Mode, vocabulary: [String] = []) {
        self.mode = mode
        var comps = URLComponents(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent")!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        let task = URLSession.shared.webSocketTask(with: comps.url!)
        socket = task
        task.resume()

        var transcription: [String: Any] = ["languageCodes": [String](), "mode": mode.rawValue]
        if !vocabulary.isEmpty { transcription["customVocabulary"] = vocabulary }
        let setup: [String: Any] = [
            "setup": [
                "model": "models/\(LiveTranscriber.model)",
                "generationConfig": ["responseModalities": ["TEXT"]],
                "inputAudioTranscription": transcription,
                "realtimeInputConfig": ["automaticActivityDetection": ["disabled": true]],
            ],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: setup), let s = String(data: data, encoding: .utf8) {
            task.send(.string(s)) { _ in }
        }
        outbox = [#"{"realtimeInput":{"activityStart":{}}}"#]
        receive(task)
    }

    func sendAudio(_ data: Data) {
        send(#"{"realtimeInput":{"audio":{"mimeType":"audio/pcm;rate=16000","data":""# + data.base64EncodedString() + #""}}}"#)
    }

    func end() {
        ended = true
        send(#"{"realtimeInput":{"activityEnd":{}}}"#)
        if error != nil { markDone() }
    }

    func close() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        onPartial = nil
        onDone = nil
    }

    private func send(_ json: String) {
        if ready { socket?.send(.string(json)) { _ in } } else { outbox.append(json) }
    }

    private func receive(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.socket === task else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let s): self.handle(Data(s.utf8))
                    case .data(let d): self.handle(d)
                    @unknown default: break
                    }
                    self.receive(task)
                case .failure(let err):
                    self.error = err
                    let reason = task.closeReason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    Log.write("live[\(self.mode.rawValue)] closed: \(err.localizedDescription) \(task.closeCode.rawValue) \(reason)")
                    if self.ended { self.markDone() }
                }
            }
        }
    }

    private func handle(_ data: Data) {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        if obj["setupComplete"] != nil {
            ready = true
            let queued = outbox
            outbox = []
            queued.forEach { q in socket?.send(.string(q)) { _ in } }
            Log.write(String(format: "live[%@] ready in %.2fs", mode.rawValue, Date().timeIntervalSince(startedAt)))
            return
        }
        guard let content = obj["serverContent"] as? [String: Any] else {
            if let err = obj["error"] { Log.write("live[\(mode.rawValue)] error: \(err)") }
            return
        }
        if let t = (content["interimInputTranscription"] as? [String: Any])?["text"] as? String {
            interim = t
            onPartial?(text)
        }
        if let t = (content["inputTranscription"] as? [String: Any])?["text"] as? String {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { finals.append(trimmed) }
            interim = ""
            onPartial?(text)
            if ended {
                // อาจมีท่อนสุดท้ายตามมาติด ๆ รอแป๊บเดียว
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.markDone() }
            }
        }
    }

    private func markDone() {
        guard !done else { return }
        done = true
        onDone?()
    }
}

/// อัดเสียงไมค์ แล้วส่งสด ๆ ไป Gemini Live (gemini-3.5-transcribe-live) 2 สายพร้อมกัน
/// พอปล่อยปุ่ม ข้อความเกือบเสร็จแล้ว จึงเร็วกว่าการส่งไฟล์ทีเดียวมาก
/// เก็บเสียง PCM ไว้ทั้งหมดด้วย เผื่อ Live ล่มจะได้ส่งแบบไฟล์แทน
final class LiveTranscriber {
    var onLevel: ((Float) -> Void)?
    var onPartial: ((String) -> Void)?

    static let model = "gemini-3.5-transcribe-live"

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var tapInstalled = false
    private let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                       channels: 1, interleaved: true)!

    // แตะบน main thread เท่านั้น
    private var smart: LiveSession?
    private var verbatim: LiveSession?
    private var chunk = Data()
    private(set) var pcm = Data()
    private var stopping = false
    private var completion: ((Result<LiveResult, Error>) -> Void)?
    private var generation = 0

    var duration: TimeInterval { Double(pcm.count) / 32_000 }

    /// คำศัพท์เฉพาะที่อยากให้สะกดถูก (ส่งให้ Gemini Live ตอนเริ่ม)
    var vocabulary: [String] = []

    private func openSessions(apiKey: String) {
        generation += 1
        pcm = Data(); chunk = Data(); stopping = false
        // อย่าส่งคำเฉพาะให้สาย SMART: ทดสอบแล้วมันตัดข้อความครึ่งแรกทิ้ง (บั๊กฝั่ง Gemini)
        let s = LiveSession(apiKey: apiKey, mode: .smart)
        s.onPartial = { [weak self] t in self?.onPartial?(t) }
        smart = s
        verbatim = LiveSession(apiKey: apiKey, mode: .verbatim, vocabulary: vocabulary)
    }

    /// สำหรับทดสอบ: เชื่อมต่อโดยไม่ใช้ไมค์ แล้วป้อนเสียงเองด้วย feed()
    func startWithoutMic(apiKey: String) {
        cancel()
        openSessions(apiKey: apiKey)
    }

    func feed(_ bytes: Data) {
        pcm.append(bytes)
        chunk.append(bytes)
        if chunk.count >= 3_200 { flushChunk() } // ~100 ms
    }

    func start(apiKey: String) throws {
        cancel()
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.channelCount > 0, inFormat.sampleRate > 0,
              let conv = AVAudioConverter(from: inFormat, to: target) else { throw SpeechError.noMicrophone }
        converter = conv
        openSessions(apiKey: apiKey)

        input.installTap(onBus: 0, bufferSize: 2048, format: inFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            cancel()
            throw error
        }
    }

    /// หยุดอัด แล้วรอข้อความสุดท้าย
    func stop(completion: @escaping (Result<LiveResult, Error>) -> Void) {
        stopEngine()
        stopping = true
        self.completion = completion
        if !chunk.isEmpty { flushChunk() }
        for s in [smart, verbatim].compactMap({ $0 }) {
            s.onDone = { [weak self] in self?.checkDone() }
            s.end()
        }
        checkDone()
        let gen = generation
        // กันค้าง: ถ้า 4 วิยังไม่ครบ ใช้เท่าที่มี
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.finish()
        }
    }

    func cancel() {
        stopEngine()
        completion = nil
        generation += 1
        smart?.close(); verbatim?.close()
        smart = nil; verbatim = nil
    }

    private func checkDone() {
        guard completion != nil, let s = smart else { return }
        // ไม่ต้องรอสาย verbatim นานถ้าสาย smart เสร็จแล้ว (ให้เวลาเพิ่มอีกนิด)
        if s.done && (verbatim?.done ?? true) {
            finish()
        } else if s.done {
            let gen = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.generation == gen else { return }
                self.finish()
            }
        }
    }

    private func finish() {
        guard let done = completion else { return }
        completion = nil
        let result = LiveResult(smart: smart?.text ?? "", verbatim: verbatim?.text ?? "")
        let err = smart?.error
        Log.write(String(format: "live done %.1fs audio smart=%d%@ verbatim=%d%@", duration,
                         result.smart.count, smart?.done == true ? "" : "(timeout)",
                         result.verbatim.count, verbatim?.done == true ? "" : "(timeout)"))
        generation += 1
        smart?.close(); verbatim?.close()
        smart = nil; verbatim = nil
        if result.smart.isEmpty && result.verbatim.isEmpty {
            done(.failure(err ?? GeminiError(message: "Gemini Live ไม่ส่งข้อความกลับมา")))
        } else {
            var r = result
            if r.smart.isEmpty { r.smart = r.verbatim }
            done(.success(r))
        }
    }

    private func flushChunk() {
        smart?.sendAudio(chunk)
        verbatim?.sendAudio(chunk)
        chunk = Data()
    }

    // MARK: - Audio

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    // ทำงานบนเธรดเสียง
    private func process(_ buffer: AVAudioPCMBuffer) {
        var level: Float = 0
        if let d = buffer.floatChannelData?[0], buffer.frameLength > 0 {
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += d[i] * d[i] }
            let db = 20 * log10(max(sqrt(sum / Float(n)), 0.000_01))
            level = max(0, min(1, (db + 50) / 40))
        }
        guard let conv = converter else { return }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        conv.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard out.frameLength > 0, let ptr = out.int16ChannelData?[0] else { return }
        let bytes = Data(bytes: ptr, count: Int(out.frameLength) * 2)
        let gen = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == gen, !self.stopping else { return }
            self.onLevel?(level)
            self.feed(bytes)
        }
    }

    /// ห่อ PCM เป็นไฟล์ WAV (ใช้ตอนต้องส่งแบบไฟล์แทน)
    static func wav(from pcm: Data, sampleRate: Int = 16_000) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append(Data("RIFF".utf8)); u32(UInt32(36 + pcm.count)); d.append(Data("WAVE".utf8))
        d.append(Data("fmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        d.append(Data("data".utf8)); u32(UInt32(pcm.count)); d.append(pcm)
        return d
    }
}
