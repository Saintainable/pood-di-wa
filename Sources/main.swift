import AppKit
import SwiftUI

// โหมดทดสอบสำหรับนักพัฒนา: PoodDiWa --selftest file.wav (WAV 16 kHz mono 16-bit)
// ใช้ key ที่บันทึกไว้ในแอป ส่งเสียงแบบสดไป Gemini Live แล้วพิมพ์ผลลัพธ์
if let i = CommandLine.arguments.firstIndex(of: "--selftest"), i + 1 < CommandLine.arguments.count {
    SelfTest.run(path: CommandLine.arguments[i + 1])
}

// พรีวิวมาสคอตเป็นไฟล์ PNG (สำหรับนักพัฒนา): --mascot-preview <dir>
if let i = CommandLine.arguments.firstIndex(of: "--mascot-preview"), i + 1 < CommandLine.arguments.count {
    let dir = CommandLine.arguments[i + 1]
    MainActor.assumeIsolated {
    for (name, sleep, rage) in [("calm", false, 0.0), ("annoyed", false, 0.35), ("angry", false, 0.6),
                                ("max", false, 1.0), ("sleep", true, 0.0), ("talk-soft", false, -1), ("talk-loud", false, -2)] {
        VoiceActivity.shared.listening = rage < 0
        VoiceActivity.shared.level = rage == -1 ? 0.3 : rage == -2 ? 0.95 : 0
        let view = MascotView(sleeping: sleep, onPoke: {}, clipY: MascotView.bodyCenter.y + 10, debugRage: max(0, rage))
            .frame(width: MascotView.frameSize.width, height: MascotView.frameSize.height)
            .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        let r = ImageRenderer(content: view)
        r.scale = 3
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/mascot-\(name).png"))
        }
    }
    }
    exit(0)
}

// วัดความเร็วขั้นเรียบเรียง: --bench-refine (interactions vs generateContent)
if CommandLine.arguments.contains("--bench-refine") {
    setvbuf(stdout, nil, _IONBF, 0)
    guard let key = Settings.shared.geminiKey else { print("no key"); exit(1) }
    let live = LiveResult(smart: "ช่วยบอกทีมว่าวันศุกร์นี้เราจะเลื่อนประชุมไปเป็นวันจันทร์",
                          verbatim: "ช่วยบอกทีมว่าวันศุกร์นี้เราจะเลื่อนประชุมไปเป็นวันจันทร์ แปลเป็นภาษาอังกฤษ")
    var round = 0
    func next() {
        round += 1
        guard round <= 6 else { exit(0) }
        let t = Date()
        GeminiClient.refineFast(live, apiKey: key, model: .flashLite, targetApp: nil) { r in
            print(String(format: "race %.2fs %@", Date().timeIntervalSince(t), String(((try? r.get()) ?? "\(r)").prefix(60))))
            next()
        }
    }
    next()
    RunLoop.main.run()
}

// ทดสอบขั้นเรียบเรียง: --compose-test (โทนตามแอป / แก้ข้อความที่เลือก / คำย่อ)
if CommandLine.arguments.contains("--compose-test") {
    setvbuf(stdout, nil, _IONBF, 0)
    guard let key = Settings.shared.geminiKey else { print("no key"); exit(1) }
    let snip = Snippet(trigger: "ที่อยู่ฉัน", text: "99/9 ถนนสุขุมวิท กรุงเทพฯ 10110")
    let saved = Snippets.all
    Snippets.save([snip])
    print("snippet whole:", Snippets.apply("ที่อยู่ ฉัน"))
    print("snippet inline:", Snippets.apply("ส่งของมาที่อยู่ฉันนะ"))
    Snippets.save(saved)
    print("thai words:", Stats.wordCount("พรุ่งนี้ผมจะเข้าประชุมตอนบ่ายสามโมงครับ"))
    for t in ["เด็กๆชอบมาก", "เด็ก ๆชอบ", "มากๆ", "ดีๆ.", "ไปๆมาๆ แล้ว", "ๆ ต้นบรรทัด", "ช้าๆ\nเร็วๆ"] {
        print("ๆ:", t.debugDescription, "→", ThaiText.fixMaiYamok(t).debugDescription)
    }
    let bad = LiveResult(smart: "พรุ่งนี้我们 ไปประชุมกัน", verbatim: "พรุ่งนี้我们 ไปประชุมกัน")
    print("guard: unexpected script =", SpokenLanguage.hasUnexpectedScript(bad.smart),
          "→ refine =", GeminiClient.decide(bad, vocabulary: []).refine)
    print("guard: vietnamese =", SpokenLanguage.hasUnexpectedScript("Được rồi"), " thai/eng ok =",
          SpokenLanguage.hasUnexpectedScript("วันนี้ review code ใน GitHub"))
    let cases: [(String, LiveResult, Tone, String?)] = [
        ("wrong script fix", bad, .asSpoken, nil),
        ("tone formal", LiveResult(smart: "พรุ่งนี้กูไม่ว่างนะ เลื่อนประชุมไปวันศุกร์ได้ป่ะ", verbatim: "พรุ่งนี้กูไม่ว่างนะ เลื่อนประชุมไปวันศุกร์ได้ป่ะ"), .formal, nil),
        ("tone casual", LiveResult(smart: "เรียนทุกท่าน ขอแจ้งเลื่อนการประชุมเป็นวันศุกร์", verbatim: "เรียนทุกท่าน ขอแจ้งเลื่อนการประชุมเป็นวันศุกร์"), .casual, nil),
        ("selection command", LiveResult(smart: "เขียนให้สุภาพ", verbatim: "เขียนให้สุภาพ"), .asSpoken, "พรุ่งนี้ประชุม 10 โมง ใครไม่มาบอกด้วย"),
        ("selection translate", LiveResult(smart: "แปลเป็นภาษาอังกฤษ", verbatim: "แปลเป็นภาษาอังกฤษ"), .asSpoken, "ขอบคุณที่ช่วยเหลือเสมอครับ"),
        ("selection plain dictation", LiveResult(smart: "วันนี้อากาศดีมาก", verbatim: "วันนี้อากาศดีมาก"), .asSpoken, "ข้อความเก่า"),
    ]
    var i = 0
    func next() {
        guard i < cases.count else { exit(0) }
        let c = cases[i]; i += 1
        let t = Date()
        GeminiClient.refineFast(c.1, tone: c.2, selection: c.3, apiKey: key, model: .flashLite, targetApp: nil) { r in
            print(String(format: "[%@] %.2fs → %@", c.0, Date().timeIntervalSince(t), (try? r.get()) ?? "ERR \(r)"))
            next()
        }
    }
    next()
    RunLoop.main.run()
}

// โหมดพรีวิวแถบอัดเสียง (สำหรับนักพัฒนา): ฟัง → คิด → ข้อความ แล้วปิด
if CommandLine.arguments.contains("--hud-preview") {
    let a = NSApplication.shared
    a.setActivationPolicy(.accessory)
    let hud = HUDController()
    hud.model.phase = .listening
    hud.model.showText = CommandLine.arguments.contains("--text")
    hud.show()
    let sample = "พรุ่งนี้ผมจะเข้าประชุมตอนบ่ายสามโมงครับ แล้วก็ช่วยส่งไฟล์ presentation ให้ด้วยนะครับ"
    var t = 0.0
    Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
        t += 0.05
        hud.model.level = CGFloat(0.45 + 0.4 * sin(t * 5) * sin(t * 1.3))
        hud.model.text = String(sample.prefix(Int(t * 14)))
        if t > 2.5, hud.model.phase == .listening { hud.model.phase = .handsFree }
        if t > 5, hud.model.phase == .handsFree { hud.model.phase = .processing }
        if t > 7.5, hud.model.phase == .processing { hud.flash("ใส่ Gemini API key ก่อน (ฟรี)") }
        if t > 10 { exit(0) }
    }
    a.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

enum SelfTest {
    static func run(path: String) -> Never {
        guard let key = Settings.shared.geminiKey else { print("no key in keychain"); exit(1) }
        guard let wav = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let range = wav.range(of: Data("data".utf8)) else { print("bad wav"); exit(1) }
        let pcm = wav.subdata(in: (range.upperBound + 4)..<wav.count)
        let live = LiveTranscriber()
        if let v = CommandLine.arguments.firstIndex(of: "--vocab"), v + 1 < CommandLine.arguments.count {
            live.vocabulary = CommandLine.arguments[v + 1].components(separatedBy: ",").filter { !$0.isEmpty }
        } else {
            live.vocabulary = Settings.shared.vocabulary
        }
        if let l = CommandLine.arguments.firstIndex(of: "--langs"), l + 1 < CommandLine.arguments.count {
            let v = CommandLine.arguments[l + 1]
            live.languages = v == "auto" ? [] : v.components(separatedBy: ",")
        } else {
            live.languages = SpokenLanguage.selected
        }
        print("vocab: \(live.vocabulary) langs: \(live.languages)")
        live.onPartial = { print("  interim: \($0)") }
        live.startWithoutMic(apiKey: key)

        // ป้อนเสียงตามเวลาจริง ทีละ 100 ms
        var offset = 0
        let started = Date()
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            let end = min(offset + 3_200, pcm.count)
            live.feed(pcm.subdata(in: offset..<end))
            offset = end
            guard offset >= pcm.count else { return }
            t.invalidate()
            let released = Date()
            print(String(format: "audio %.1fs streamed in %.1fs", Double(pcm.count) / 32_000, released.timeIntervalSince(started)))
            live.stop { result in
                print(String(format: "release→result %.2fs", Date().timeIntervalSince(released)))
                switch result {
                case .success(let res):
                    print("SMART: \(res.smart)")
                    print("VERBATIM: \(res.verbatim)")
                    let d = GeminiClient.decide(res, vocabulary: live.vocabulary)
                    print("FINAL: \(d.text)  [refine: \(d.refine)]")
                    guard d.refine else { exit(0) }
                    let r0 = Date()
                    GeminiClient.refineFast(res, apiKey: key, model: Settings.shared.geminiModel, targetApp: nil) { r in
                        print(String(format: "refine %.2fs", Date().timeIntervalSince(r0)))
                        print("REFINED: \((try? r.get()) ?? "error: \(r)")")
                        exit(0)
                    }
                case .failure(let e):
                    print("FAIL: \(e.localizedDescription)")
                    exit(2)
                }
            }
        }
        RunLoop.main.run()
        exit(0)
    }
}
