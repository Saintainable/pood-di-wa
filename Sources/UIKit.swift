import AppKit
import SwiftUI

// MARK: - ชิ้นส่วน UI โทน ดำถ่าน + ส้ม-แดง

/// ปุ่มหลัก: แคปซูลไล่สีส้ม → แดง กดแล้วยุบนิดนึง
struct HotButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.font(compact ? 12 : 14, .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 12 : 20)
            .padding(.vertical, compact ? 5 : 9)
            .background(Capsule().fill(Brand.hot))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18)))
            .shadow(color: Color(nsColor: Brand.red).opacity(configuration.isPressed ? 0.1 : 0.35), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// ปุ่มรอง: ตัวหนังสือเทา ไม่มีพื้น
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.font(12, .semibold))
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.4 : 0.6))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.05)))
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(Brand.font(11, .black))
                .tracking(1.2)
                .foregroundColor(Color(nsColor: Brand.orange))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Brand.line))
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(Brand.font(15, .bold))
                .foregroundColor(granted ? .white.opacity(0.5) : .white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(granted ? AnyShapeStyle(Color.white.opacity(0.06)) : AnyShapeStyle(Brand.hot)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Brand.font(13, .bold)).foregroundColor(.white)
                Text(detail).font(Brand.font(11)).foregroundColor(Brand.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted {
                Label("เรียบร้อย", systemImage: "checkmark")
                    .font(Brand.font(11, .heavy))
                    .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.5))
            } else {
                Button("อนุญาต", action: action).buttonStyle(HotButtonStyle(compact: true))
            }
        }
    }
}

struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Brand.font(12, .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18)))
            .shadow(color: .black.opacity(0.5), radius: 0, y: 2)
    }
}

/// สวิตช์ 2 ทางแบบแคปซูล (แทน segmented control สีน้ำเงินของระบบ)
struct Toggle2<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, label in
                Button { selection = value } label: {
                    Text(label)
                        .font(Brand.font(12, .bold))
                        .foregroundColor(.white.opacity(selection == value ? 1 : 0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selection == value ? AnyShapeStyle(Brand.hot) : AnyShapeStyle(Color.clear)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .overlay(Capsule().strokeBorder(Brand.line))
    }
}

/// ป้ายคำเฉพาะ — ชี้แล้วมีปุ่ม × ให้ลบ
struct VocabChip: View {
    let word: String
    var highlight = false
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(word)
                .font(Brand.font(12, .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(Color(nsColor: Brand.red)))
                }
                .buttonStyle(.plain)
                .help("ลบคำนี้")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, hovering ? 4 : 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(hovering ? Color.white.opacity(0.16)
                                   : highlight ? Color(nsColor: Brand.orange).opacity(0.22) : Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(hovering ? 0.25 : 0.10)))
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}

/// จัดของเรียงต่อกันแล้วขึ้นบรรทัดใหม่เมื่อเต็ม (แบบตัวหนังสือ)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: maxW.isFinite ? maxW : widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > bounds.width { y += rowH + spacing; x = 0; rowH = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// ปุ่มเครดิต: ชี้เมาส์ = เห็นชื่อผู้สร้างสั้น ๆ · คลิก = การ์ดรายชื่อทีม
struct CreditsButton: View {
    @State private var open = false
    @State private var hovering = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill").font(.system(size: 10, weight: .bold))
                Text(hovering ? "Made by Saintainable" : "Credits")
            }
            .font(Brand.font(12, .semibold))
            .foregroundColor(.white.opacity(hovering || open ? 0.95 : 0.6))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(hovering || open ? 0.12 : 0.05)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .popover(isPresented: $open, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Pood Di Wa").font(Brand.font(17, .bold)).foregroundStyle(Brand.hot)
                        Text("Version \(version)").font(Brand.font(11)).foregroundColor(Brand.muted)
                    }
                }
                creditRow("Created by", "Saintainable", hot: true)
                creditRow("Contributor", "Andrew ii23")
            }
            .padding(18)
            .frame(width: 240, alignment: .leading)
            .background(Brand.ink)
            .preferredColorScheme(.dark)
        }
        .help("Made by Saintainable · Contributor: Andrew ii23")
    }

    private func creditRow(_ role: String, _ name: String, hot: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(role.uppercased())
                .font(Brand.font(10, .bold)).tracking(1.1)
                .foregroundColor(Brand.muted)
            Group {
                if hot { Text(name).foregroundStyle(Brand.hot) } else { Text(name).foregroundColor(.white) }
            }
            .font(Brand.font(15, .bold))
        }
    }
}

