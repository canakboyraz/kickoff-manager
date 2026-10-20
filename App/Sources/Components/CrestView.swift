import SwiftUI
import GameEngine

/// Shield-shaped club crest drawn from the club's colours and short name.
struct CrestView: View {
    let club: Club
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            ShieldShape()
                .fill(Color(hex: club.colors.primary))
            ShieldShape()
                .stroke(Color(hex: club.colors.secondary), lineWidth: max(1.5, size * 0.06))
            // A diagonal stripe keeps crests with similar colours apart.
            ShieldShape()
                .fill(Color(hex: club.colors.secondary).opacity(0.25))
                .mask(
                    Rectangle()
                        .frame(width: size * 0.22)
                        .rotationEffect(.degrees(35))
                )
            Text(club.shortName)
                .font(.system(size: size * 0.26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: club.colors.secondary))
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, size * 0.08)
                .offset(y: -size * 0.04)
        }
        .frame(width: size * 0.88, height: size)
        .accessibilityLabel(club.name)
    }
}

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + height * 0.08))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + width * 0.25, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + height * 0.08),
            control: CGPoint(x: rect.maxX - width * 0.25, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + height * 0.5))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.minY + height * 0.85)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + height * 0.5),
            control: CGPoint(x: rect.minX, y: rect.minY + height * 0.85)
        )
        path.closeSubpath()
        return path
    }
}

/// Round avatar with the player's initials, tinted by nationality so squads look varied.
struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 40

    private var tint: Color {
        let palette = ["2E4566", "3C3489", "085041", "712B13", "0C447C", "444441", "72243E"]
        let index = abs(player.nationality.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % palette.count
        return Color(hex: palette[index])
    }

    var body: some View {
        ZStack {
            Circle().fill(tint)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.18))
                .padding(size * 0.18)
                .offset(y: size * 0.08)
            Text(player.initials)
                .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
