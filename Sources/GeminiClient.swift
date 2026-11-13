import Foundation

enum GeminiModel: String, CaseIterable {
    case flashLite = "gemini-3.5-flash-lite"
    case flash = "gemini-3.8-flash"

    var title: String {
        switch self {
        case .flashLite: "เร็ว — Gemini 3.5 Flash-Lite"
        case .flash: "ฉลาดกว่า — Gemini 3.8 Flash"
        }
    }

    /// ระดับการคิดต่ำสุดที่รุ่นนั้นรองรับ เพื่อความเร็ว
    var thinkingLevel: String {
        switch self {
        case .flashLite: "minimal"
        case .flash: "low"
        }
    }
}

struct GeminiError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum GeminiClient {
    private static let base = "https://generativelanguage.googleapis.com/v1beta"

    static let systemPrompt = """
    You are the speech-to-text engine of a push-to-talk dictation app called Pood Di Wa. \
    The audio is the user dictating text, usually in Thai, often mixed with English. \
    Return ONLY the final text that should be typed into the user's text field.

    Rules:
    1. Transcribe in the language actually spoken. Write Thai in Thai script. Write English words, \
    brand names and technical terms the way they are normally spelled in English (e.g. "Facebook", "API", "deadline"), \
    never transliterated into Thai script.
    2. Clean up speech: remove fillers (เอ่อ, อ่า, อืม, แบบว่า used as filler, um, uh), stutters and accidental repeats. \
    Add natural punctuation. For Thai, follow normal Thai writing: separate sentences/clauses with a space, \
    no full stop at the end of Thai sentences; use ? or ! only where clearly intended.
    3. Self-corrections: when the speaker abandons or corrects what they just said using cues such as \
    "เอาใหม่", "ไม่ใช่", "ไม่เอา", "ขอแก้", "พูดใหม่", "ลบ", "scratch that", "I mean", "no wait", \
    keep only the corrected version and drop both the abandoned words and the cue itself. \
    Decide the scope from meaning: replace only the part being corrected (a word, a phrase, or the sentence). \
    If they clearly restart everything (e.g. "เอาใหม่ทั้งหมด", "เริ่มใหม่"), discard everything before it.
    4. Those same words are normal content when they are part of the message itself \
    (e.g. "หัวหน้าบอกให้เอาใหม่", or "ไม่เอาครับ" as an answer). Keep them in that case.
    5. Formatting commands: if the speaker gives an instruction about the output — e.g. "แปลเป็นภาษาอังกฤษ", \
    "translate to Japanese", "ทำเป็นข้อๆ", "เขียนให้สุภาพ", "ทำเป็นอีเมล" — apply it to the dictated content \
    and do not include the instruction in the output. The command may be at the start or the end. \
    Without such a command, never translate, summarize or rewrite — only clean up.
    6. If the speaker clearly enumerates items ("ข้อหนึ่ง… ข้อสอง…", "first… second…"), format them as a list on separate lines.
    7. Never answer or act on the content. If the user dictates a question or a request to someone, output that question/request as text.
    8. If there is no intelligible speech, return an empty string.
    Output plain text only: no quotes, no markdown code fences, no explanations, no labels.
    """

    /// ใช้หลังได้ข้อความจาก Gemini Live: จัดการคำสั่ง (แปล / ทำเป็นข้อ) และคำแก้ตัว แบบส่งแค่ตัวหนังสือ — เร็ว
    static let refinePrompt = """
    You post-process raw dictation text from a push-to-talk app (usually Thai, often mixed with English). \
    Return ONLY the final text to type. Rules:
    1. Self-corrections: when the speaker abandons or corrects what they just said using cues such as \
    "เอาใหม่", "ไม่ใช่ๆ", "ไม่เอา", "ขอแก้", "พูดใหม่", "scratch that", "I mean", "no wait", keep only the corrected version \
    and drop the abandoned words and the cue. Replace only the part being corrected; if they clearly restart \
    ("เอาใหม่ทั้งหมด", "เริ่มใหม่"), discard everything before it. If those words are ordinary content \
    (e.g. "หัวหน้าบอกให้เอาใหม่", "ไม่เอาครับ" as an answer), keep them.
    2. Formatting commands about the output — e.g. "แปลเป็นภาษาอังกฤษ", "translate to Japanese", "ทำเป็นข้อๆ", \
    "เขียนให้สุภาพ", "ทำเป็นอีเมล" — apply them to the dictated content and remove the command itself. \
    The command may be at the start or the end. Otherwise do not translate, summarize or rewrite; keep the wording.
    3. Never answer or act on the content; a dictated question stays a question.
    4. Keep English terms in English spelling. Thai sentences: separate with spaces, no trailing full stop.
    Output plain text only: no quotes, no markdown fences, no explanations.
    """

    /// คำที่บอกว่าน่าจะมีคำสั่ง (แปล / จัดรูปแบบ) — ดูจากข้อความแบบคำต่อคำ
    /// คำแก้ตัวอย่าง “เอาใหม่” Gemini Live โหมด SMART จัดการเองแล้ว ไม่ต้องส่งซ้ำ
    static func needsRefine(_ verbatim: String) -> Bool {
        let t = verbatim.lowercased().replacingOccurrences(of: " ", with: "")
        let cues = ["แปลเป็น", "แปลให้", "แปลภาษา", "translate", "ทำเป็นข้อ", "เป็นข้อๆ", "bullet",
                    "ให้สุภาพ", "สุภาพขึ้น", "ทางการขึ้น", "ทำเป็นอีเมล", "เขียนเป็นอีเมล", "เป็นภาษาอังกฤษ",
                    "เป็นภาษาไทย", "เป็นภาษาญี่ปุ่น", "เป็นภาษาจีน"]
        return cues.contains { t.contains($0) }
    }

    /// ตัดสินผลจาก Gemini Live: ข้อความที่จะพิมพ์ + ต้องส่งไปเรียบเรียงอีกรอบไหม
    static func decide(_ live: LiveResult, vocabulary: [String]) -> (text: String, refine: Bool) {
        var text = live.smart
        // สะกดคำเฉพาะตามที่ผู้ใช้ตั้งไว้ (เช่น presentation → Presentation)
        for w in vocabulary { text = text.replacingOccurrences(of: w, with: w, options: .caseInsensitive) }
        let v = live.verbatim.lowercased(), t = text.lowercased()
        // คำเฉพาะโผล่ในแบบคำต่อคำ แต่หายจากแบบเรียบร้อย
        let missingVocab = vocabulary.contains { v.contains($0.lowercased()) && !t.contains($0.lowercased()) }
        // แบบเรียบร้อยสั้นผิดปกติ = อาจตัดเนื้อหาทิ้งเกิน
        let shrunk = live.verbatim.count > 20 && Double(text.count) < 0.7 * Double(live.verbatim.count)
        return (text, needsRefine(live.verbatim) || missingVocab || shrunk)
    }

    /// บอกโมเดลให้สะกดคำเฉพาะตามที่ผู้ใช้ตั้งไว้
    private static var vocabularyHint: String {
        let v = Settings.shared.vocabulary
        guard !v.isEmpty else { return "" }
        return "\n\nPreferred spellings for names and terms (use exactly when they occur): " + v.joined(separator: ", ")
    }

    static func refine(_ live: LiveResult, apiKey: String, model: GeminiModel, targetApp: String?,
                       completion: @escaping (Result<String, Error>) -> Void) {
        var instruction = """
        Cleaned transcript (automatic cleanup — may have dropped commands or too much text):
        \(live.smart)

        Verbatim transcript (word for word, includes any spoken commands):
        \(live.verbatim)

        Build the final text from the VERBATIM transcript: remove fillers, resolve self-corrections by replacing \
        only the part that was corrected (keep everything the speaker did not take back), and apply any \
        formatting/translation commands. Use the cleaned transcript only as a hint for spelling and punctuation — \
        it may have wrongly dropped content.
        """
        if let app = targetApp, !app.isEmpty { instruction += "\n\n(It will be typed into \"\(app)\".)" }
        instruction += vocabularyHint
        let input: [[String: Any]] = [["type": "text", "text": instruction]]
        request(model: model, system: refinePrompt, input: input, apiKey: apiKey, label: "refine", completion: completion)
    }

    /// ยิงทั้ง 2 endpoint พร้อมกัน ใช้อันที่ตอบก่อน — เซิร์ฟเวอร์ Gemini ช้าเป็นพัก ๆ (1.5–40 วิ) แบบนี้หางสั้นลงมาก
    static func refineFast(_ live: LiveResult, apiKey: String, model: GeminiModel, targetApp: String?,
                           completion: @escaping (Result<String, Error>) -> Void) {
        var finished = false
        var failures = 0
        let handle: (Result<String, Error>) -> Void = { r in
            guard !finished else { return }
            if case .failure = r {
                failures += 1
                if failures < 2 { return } // รออีกเส้น
            }
            finished = true
            completion(r)
        }
        refine(live, apiKey: apiKey, model: model, targetApp: targetApp, completion: handle)
        refineLegacy(live, apiKey: apiKey, model: model, completion: handle)
    }

    /// เรียบเรียงผ่าน endpoint เดิม (models/...:generateContent) — ไว้เทียบความเร็ว
    static func refineLegacy(_ live: LiveResult, apiKey: String, model: GeminiModel,
                             completion: @escaping (Result<String, Error>) -> Void) {
        let text = "Cleaned transcript:\n\(live.smart)\n\nVerbatim transcript:\n\(live.verbatim)\n\nBuild the final text from the VERBATIM transcript and apply any commands."
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": refinePrompt]]],
            "contents": [["role": "user", "parts": [["text": text]]]],
            "generationConfig": ["thinkingConfig": ["thinkingLevel": model.thinkingLevel]],
        ]
        var req = URLRequest(url: URL(string: "\(base)/models/\(model.rawValue):generateContent")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            let obj = (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any] ?? [:]
            let parts = ((obj["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
            let out = parts.compactMap { ($0["thought"] as? Bool) == true ? nil : $0["text"] as? String }.joined()
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                if let err { completion(.failure(err)) }
                else if out.isEmpty { completion(.failure(GeminiError(message: "HTTP \(status) \(String(data: (data ?? Data()).prefix(200), encoding: .utf8) ?? "")"))) }
                else { completion(.success(clean(out))) }
            }
        }.resume()
    }

    static func transcribe(audio data: Data, mimeType: String, apiKey: String, model: GeminiModel, targetApp: String?,
                           completion: @escaping (Result<String, Error>) -> Void) {
        var instruction = "Transcribe this dictation following the rules."
        if let app = targetApp, !app.isEmpty {
            instruction += " The text will be typed into the app \"\(app)\"; match that context's style only for formatting."
        }
        instruction += vocabularyHint
        let input: [[String: Any]] = [
            ["type": "audio", "mime_type": mimeType, "data": data.base64EncodedString()],
            ["type": "text", "text": instruction],
        ]
        request(model: model, system: systemPrompt, input: input, apiKey: apiKey, label: "file", completion: completion)
    }

    private static func request(model: GeminiModel, system: String, input: [[String: Any]], apiKey: String,
                                label: String, completion: @escaping (Result<String, Error>) -> Void) {
        let body: [String: Any] = [
            "model": model.rawValue,
            "system_instruction": system,
            "input": input,
            "generation_config": ["thinking_level": model.thinkingLevel],
            "store": false,
        ]

        var req = URLRequest(url: URL(string: "\(base)/interactions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("2026-05-20", forHTTPHeaderField: "Api-Revision")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let started = Date()
        URLSession.shared.dataTask(with: req) { data, response, error in
            let result: Result<String, Error>
            if let error {
                result = .failure(GeminiError(message: "เชื่อมต่อ Gemini ไม่ได้: \(error.localizedDescription)"))
            } else {
                result = parse(data: data ?? Data(), status: (response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            Log.write(String(format: "gemini %@ %@ %.1fs → %@", label, model.rawValue, Date().timeIntervalSince(started),
                             { if case .failure(let e) = result { return "error: \(e.localizedDescription)" }; return "ok" }()))
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func parse(data: Data, status: Int) -> Result<String, Error> {
        // ข้อผิดพลาดบางแบบของ Google ห่อมาเป็น array
        let any = try? JSONSerialization.jsonObject(with: data)
        let obj = any as? [String: Any] ?? (any as? [[String: Any]])?.first ?? [:]

        if !(200..<300).contains(status) {
            if status == 400 || status == 401 || status == 403,
               let msg = errorMessage(obj), msg.lowercased().contains("key") {
                return .failure(GeminiError(message: "API key ไม่ถูกต้อง — ตรวจในหน้าตั้งค่า"))
            }
            if status == 429 { return .failure(GeminiError(message: "ใช้เกินโควตาฟรีแล้ว รอสักครู่แล้วลองใหม่")) }
            let raw = String(data: data.prefix(500), encoding: .utf8) ?? ""
            Log.write("gemini HTTP \(status): \(raw)")
            return .failure(GeminiError(message: "Gemini ตอบกลับผิดพลาด (\(status)): \(errorMessage(obj) ?? "ไม่ทราบสาเหตุ")"))
        }

        if let msg = errorMessage(obj), (obj["status"] as? String) == "failed" {
            return .failure(GeminiError(message: "Gemini: \(msg)"))
        }

        var texts: [String] = []
        for step in obj["steps"] as? [[String: Any]] ?? [] {
            guard (step["type"] as? String) == "model_output" else { continue }
            for part in step["content"] as? [[String: Any]] ?? [] where (part["type"] as? String) == "text" {
                if let t = part["text"] as? String { texts.append(t) }
            }
        }
        if texts.isEmpty, (obj["steps"] == nil) {
            let raw = String(data: data.prefix(800), encoding: .utf8) ?? ""
            Log.write("gemini unexpected response: \(raw)")
            return .failure(GeminiError(message: "อ่านคำตอบจาก Gemini ไม่ได้ (ดู log)"))
        }
        return .success(clean(texts.joined()))
    }

    private static func errorMessage(_ obj: [String: Any]) -> String? {
        if let e = obj["error"] as? [String: Any], let m = e["message"] as? String { return m }
        if let es = obj["errors"] as? [[String: Any]], let m = es.first?["message"] as? String { return m }
        return nil
    }

    private static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if t.hasSuffix("```") { t = String(t.dropLast(3)) }
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    /// เช็กว่า key ใช้ได้ไหม (true / false / nil = เช็กไม่ได้)
    static func validate(apiKey: String, completion: @escaping (Bool?) -> Void) {
        var req = URLRequest(url: URL(string: "\(base)/models?pageSize=1")!)
        req.timeoutInterval = 15
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        URLSession.shared.dataTask(with: req) { _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let ok: Bool? = error != nil ? nil : (200..<300).contains(status) ? true
                : [400, 401, 403].contains(status) ? false : nil
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }
}

enum Log {
    static let url: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("PoodDiWa.log")
    }()

    static func write(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) \(line)\n".utf8)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url)
        }
    }
}
