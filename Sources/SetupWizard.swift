import AppKit
import SwiftUI

// MARK: - ตั้งค่าครั้งแรก 3 ขั้น — ให้คนที่ไม่รู้เทคทำตามได้

struct SetupWizard: View {
    @ObservedObject var state: PermissionState
    var onDone: () -> Void
    @State private var step = 0
    @State private var keyText = ""

    private var stepDone: [Bool] {
        [state.mic, state.accessibility, (state.hasKey && state.keyOK != false) || state.engine == .apple]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture {} // กันคลิกทะลุไปข้างหลัง

            VStack(spacing: 0) {
                // หัว: ความคืบหน้า
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i <= step ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.white.opacity(0.12)))
                            .frame(height: 5)
                    }
                }
                .padding(.bottom, 22)

                Group {
                    switch step {
                    case 0: micStep
                    case 1: accessibilityStep
                    default: keyStep
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)

                // ท้าย: ปุ่มย้อน / ต่อไป — ต้องทำขั้นนั้นให้เสร็จก่อนถึงไปต่อได้
                HStack {
                    if step > 0 {
                        Button("ย้อนกลับ") { withAnimation { step -= 1 } }.buttonStyle(GhostButtonStyle())
                    }
                    Spacer()
                    Text(stepDone[step] ? "ขั้นที่ \(step + 1) จาก 3 · เรียบร้อย" : "ขั้นที่ \(step + 1) จาก 3 · ทำขั้นนี้ให้เสร็จก่อนนะ")
                        .font(Brand.font(11.5)).foregroundColor(Brand.muted)
                    Spacer()
                    if step < 2 {
                        Button("ต่อไป") { withAnimation { step += 1 } }
                            .buttonStyle(HotButtonStyle())
                            .disabled(!stepDone[step])
                            .opacity(stepDone[step] ? 1 : 0.35)
                    } else {
                        Button("เสร็จแล้ว ลองพูดเลย!", action: onDone)
                            .buttonStyle(HotButtonStyle())
                            .disabled(!stepDone.allSatisfy { $0 })
                            .opacity(stepDone.allSatisfy { $0 } ? 1 : 0.35)
                    }
                }
                .padding(.top, 18)
            }
            .padding(28)
            .frame(width: 560)
            .background(RoundedRectangle(cornerRadius: 22).fill(Brand.ink))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.1)))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        }
        .onAppear {
            // ข้ามขั้นที่ทำไว้แล้ว
            step = stepDone.firstIndex(of: false) ?? 2
            if let s = MainView.argValue("--setup-step"), let n = Int(s) { step = n } // สำหรับถ่ายภาพหน้าจอ
        }
    }

    private func header(_ n: Int, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ขั้นที่ \(n)").font(Brand.font(12, .bold)).foregroundColor(Color(nsColor: Brand.orange))
            Text(title).font(Brand.font(24, .bold)).foregroundColor(.white)
            Text(detail).font(Brand.font(13.5)).foregroundColor(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func doneBadge(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(Brand.font(14, .bold))
            .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.5))
    }

    // ขั้น 1: ไมค์
    private var micStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            header(1, "ให้พูดดิวะได้ยินเสียงคุณ", "กดปุ่มด้านล่าง แล้วกด “OK” ในหน้าต่างที่ Mac ถาม")
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Brand.hot)
                .frame(maxWidth: .infinity)
            if state.mic {
                doneBadge("ได้ยินแล้ว เรียบร้อย")
            } else {
                Button("อนุญาตไมโครโฟน") { Permissions.requestMic { state.refresh() } }
                    .buttonStyle(HotButtonStyle())
            }
        }
    }

    // ขั้น 2: Accessibility พร้อมภาพจำลองว่าต้องกดตรงไหน
    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(2, "ให้พูดดิวะพิมพ์แทนคุณได้",
                   "Mac จะเปิดหน้า Privacy & Security → Accessibility ให้ เปิดสวิตช์ “Pood Di Wa” ตามภาพ")
            // ภาพจำลองหน้า System Settings
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.8)).frame(width: 9, height: 9) }
                    Text("Accessibility").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 8)
                }
                .padding(10)
                Divider().overlay(Color.white.opacity(0.08))
                fakeRow("Notes", on: false, highlight: false)
                fakeRow("Pood Di Wa", on: true, highlight: true)
                fakeRow("Safari", on: false, highlight: false)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))

            if state.accessibility {
                doneBadge("เรียบร้อย พิมพ์แทนได้แล้ว")
            } else {
                HStack(spacing: 12) {
                    Button("เปิดหน้าตั้งค่าของ Mac") { Permissions.requestAccessibility() }
                        .buttonStyle(HotButtonStyle())
                    Text("เปิดแล้วไม่ขึ้นเครื่องหมายถูก? ลบ Pood Di Wa ด้วยปุ่ม − แล้วกดใหม่")
                        .font(Brand.font(11)).foregroundColor(Brand.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func fakeRow(_ name: String, on: Bool, highlight: Bool) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(highlight ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.white.opacity(0.15)))
                .frame(width: 20, height: 20)
            Text(name).font(.system(size: 13, weight: highlight ? .bold : .regular)).foregroundColor(.white.opacity(highlight ? 1 : 0.6))
            Spacer()
            if highlight {
                Text("เปิดตรงนี้").font(Brand.font(11, .bold)).foregroundColor(Color(nsColor: Brand.amber))
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundColor(Color(nsColor: Brand.amber))
            }
            Capsule()
                .fill(on ? Color.blue : Color.white.opacity(0.2))
                .frame(width: 32, height: 18)
                .overlay(Circle().fill(.white).frame(width: 14).offset(x: on ? 7 : -7))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(highlight ? Color(nsColor: Brand.orange).opacity(0.12) : Color.clear)
    }

    // ขั้น 3: Gemini key — เด่นที่สุด ปุ่มเดียวชัด ๆ
    private var keyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(3, "ขอกุญแจฟรีให้พูดดิวะ",
                   "พูดดิวะใช้ Gemini ของ Google ฟังเสียงคุณ ต้องมี “กุญแจ” (API key) ของคุณเอง — ฟรี ไม่ต้องผูกบัตร ใช้เวลา 1 นาที")

            if state.engine == .apple && !state.hasKey {
                Text("ตอนนี้ตั้งเป็นแบบพื้นฐานของ Apple ไว้ (ในตั้งค่าขั้นสูง) — ใส่กุญแจเพื่อให้ฉลาดเต็มที่ได้นะ")
                    .font(Brand.font(11.5)).foregroundColor(Brand.muted)
            }

            if state.hasKey && state.keyOK != false {
                VStack(alignment: .leading, spacing: 8) {
                    doneBadge(state.keyOK == true ? "กุญแจใช้งานได้ พร้อมแล้ว!" : "บันทึกกุญแจแล้ว")
                    Text("อยากเปลี่ยนกุญแจทีหลัง ไปที่ ตั้งค่า → ขั้นสูง").font(Brand.font(11.5)).foregroundColor(Brand.muted)
                }
                .padding(.top, 10)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    stepLine("1", "กดปุ่มส้มด้านล่าง → ล็อกอินบัญชี Google")
                    stepLine("2", "กด “Create API key” แล้วกดคัดลอก")
                    stepLine("3", "กลับมากด “วางจากคลิปบอร์ด” — เสร็จ!")

                    // ปุ่มหลักปุ่มเดียว ใหญ่ ๆ
                    Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill").font(.system(size: 16, weight: .bold))
                            Text("ขอกุญแจฟรีที่ Google").font(Brand.font(16, .bold))
                            Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Brand.hot))
                        .shadow(color: Color(nsColor: Brand.red).opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 10) {
                        Button {
                            let clip = NSPasteboard.general.string(forType: .string)?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if clip.isEmpty { state.keyStatus = "คลิปบอร์ดว่าง — กดคัดลอกกุญแจจากหน้า Google ก่อน" }
                            else { state.saveKey(clip) }
                        } label: {
                            Label("วางจากคลิปบอร์ด", systemImage: "doc.on.clipboard")
                                .font(Brand.font(13, .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2)))
                        }
                        .buttonStyle(.plain)
                        Text("หรือวางเองในช่องด้านล่าง").font(Brand.font(11.5)).foregroundColor(Brand.muted)
                    }
                    KeyField(state: state, keyText: $keyText, showLink: false)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: Brand.orange).opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Brand.hot, lineWidth: 1.5))
            }
        }
    }

    private func stepLine(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(Brand.font(12, .bold)).foregroundColor(.black)
                .frame(width: 20, height: 20).background(Circle().fill(Color.white.opacity(0.85)))
            Text(text).font(Brand.font(13)).foregroundColor(.white.opacity(0.9))
        }
    }
}
