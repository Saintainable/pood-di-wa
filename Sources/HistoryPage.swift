import AppKit
import SwiftUI

// MARK: - หน้าประวัติ: ค้นหาได้ แบ่งตามวัน คลิกเพื่อคัดลอก

struct HistoryPage: View {
    @ObservedObject var state: PermissionState
    @State private var query = ""
    @State private var copiedID: UUID?
    @State private var hoverID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("ประวัติ").font(Brand.font(26, .bold)).foregroundColor(.white)
                Text("\(state.history.count) รายการล่าสุด").font(Brand.font(12.5)).foregroundColor(Brand.muted)
                Spacer()
                if !state.history.isEmpty {
                    Button("ล้างทั้งหมด") { confirmClear() }.buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.top, 50)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.muted)
                TextField("ค้นหาสิ่งที่เคยพูด", text: $query)
                    .textFieldStyle(.plain)
                    .font(Brand.font(13.5))
                    .foregroundColor(.white)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Brand.muted)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Brand.line))

            if state.history.isEmpty {
                empty("ยังไม่มีประวัติ", "กดปุ่มลัดแล้วพูดในแอปไหนก็ได้ ข้อความจะมาเก็บไว้ที่นี่")
            } else if groups.isEmpty {
                empty("ไม่เจอคำว่า “\(query)”", "ลองค้นด้วยคำอื่น")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8, pinnedViews: []) {
                        ForEach(groups, id: \.title) { g in
                            Text(g.title)
                                .font(Brand.font(11, .bold)).tracking(1)
                                .foregroundColor(Color(nsColor: Brand.orange))
                                .padding(.top, 8)
                            ForEach(g.items) { row($0) }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    // แบ่งกลุ่ม วันนี้ / เมื่อวาน / วันที่
    private var groups: [(title: String, items: [HistoryItem])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let items = q.isEmpty ? state.history : state.history.filter {
            $0.text.localizedCaseInsensitiveContains(q) || ($0.app ?? "").localizedCaseInsensitiveContains(q)
        }
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "th_TH")
        fmt.dateFormat = "d MMMM"
        var out: [(String, [HistoryItem])] = []
        for item in items {
            let title = cal.isDateInToday(item.date) ? "วันนี้" : cal.isDateInYesterday(item.date) ? "เมื่อวาน" : fmt.string(from: item.date)
            if out.last?.0 == title { out[out.count - 1].1.append(item) } else { out.append((title, [item])) }
        }
        return out
    }

    private func row(_ item: HistoryItem) -> some View {
        let hovering = hoverID == item.id
        let copied = copiedID == item.id
        let time: String = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: item.date)
        }()
        return Button {
            History.copy(item)
            withAnimation(.easeOut(duration: 0.15)) { copiedID = item.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                if copiedID == item.id { withAnimation { copiedID = nil } }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(time)
                    .font(Brand.font(11.5, .semibold)).monospacedDigit()
                    .foregroundColor(Brand.muted)
                    .frame(width: 40, alignment: .leading)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text)
                        .font(Brand.font(13.5, .medium))
                        .foregroundColor(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let app = item.app {
                        Text(app)
                            .font(Brand.font(10.5, .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 7).padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
                Group {
                    if copied {
                        Image(systemName: "checkmark")
                            .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.5))
                    } else {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(Color(nsColor: Brand.orange))
                            .opacity(hovering ? 1 : 0)
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(hovering || copied ? 0.08 : 0)))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(hovering ? 0.09 : 0.04)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in hoverID = h ? item.id : (hoverID == item.id ? nil : hoverID) }
        .help("คลิกเพื่อคัดลอก")
    }

    private func empty(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Brand.hot)
            Text(title).font(Brand.font(16, .bold)).foregroundColor(.white)
            Text(detail).font(Brand.font(12.5)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "ลบประวัติทั้งหมด \(state.history.count) รายการ?"
        alert.informativeText = "ลบแล้วกู้คืนไม่ได้"
        alert.addButton(withTitle: "ลบทั้งหมด")
        alert.addButton(withTitle: "ยกเลิก")
        if alert.runModal() == .alertFirstButtonReturn { History.clear() }
    }
}
