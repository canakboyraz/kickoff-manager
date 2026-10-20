import SwiftUI
import GameEngine

enum Theme {
    static let background = Color(hex: "0E1A2B")
    static let backgroundDeep = Color(hex: "08111D")
    static let surface = Color(hex: "1D2E45")
    static let surfaceRaised = Color(hex: "26395A")
    static let stroke = Color(hex: "2E4566")

    static let gold = Color(hex: "EF9F27")
    static let goldLight = Color(hex: "FAC775")
    static let goldDark = Color(hex: "412402")
    static let silver = Color(hex: "D3D1C7")
    static let bronze = Color(hex: "E0A97A")

    static let pitch = Color(hex: "1F6B3A")
    static let pitchLine = Color(hex: "5DA874")

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "85B7EB")
    static let textMuted = Color(hex: "8A9BB4")

    static let positive = Color(hex: "5DCAA5")
    static let negative = Color(hex: "F09595")
    static let warning = Color(hex: "FAC775")

    /// Card border and rating colour by quality tier (gold / silver / bronze).
    static func tierColor(_ overall: Int) -> Color {
        switch overall {
        case 80...: return goldLight
        case 70..<80: return silver
        case 60..<70: return bronze
        default: return textMuted
        }
    }

    static func moraleColor(_ morale: Int) -> Color {
        morale >= 65 ? positive : (morale >= 40 ? warning : negative)
    }

    static func fitnessColor(_ fitness: Int) -> Color {
        fitness >= 80 ? positive : (fitness >= 60 ? warning : negative)
    }

    static let elite = Color(hex: "AFA9EC")
    static let continental = Color(hex: "5DCAA5")
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

struct GameCard: ViewModifier {
    var padding: CGFloat = 14
    var highlight: Color?

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(highlight ?? Theme.stroke, lineWidth: highlight == nil ? 0.5 : 1.5)
            )
    }
}

extension View {
    func gameCard(padding: CGFloat = 14, highlight: Color? = nil) -> some View {
        modifier(GameCard(padding: padding, highlight: highlight))
    }

    /// Dark navy page background used by every screen.
    func gameBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

/// Big gold call-to-action button.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.goldDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Secondary outlined button.
struct OutlineButtonStyle: ButtonStyle {
    var color: Color = Theme.textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.surfaceRaised.opacity(configuration.isPressed ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(color.opacity(0.5), lineWidth: 1))
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(Theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

struct Chip: View {
    let text: String
    var icon: String?
    var color: Color = Theme.goldLight

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.surfaceRaised, in: Capsule())
    }
}

/// Horizontal bar for attributes, morale, etc.
struct ValueBar: View {
    let value: Int
    var maxValue: Int = 99
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.backgroundDeep)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(min(value, maxValue)) / CGFloat(maxValue))
            }
        }
        .frame(height: height)
    }
}

/// Title on the left, value on the right.
struct InfoRow: View {
    let title: String
    let value: String
    var color: Color = Theme.textPrimary

    var body: some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }
}
