import SwiftUI
import GameEngine

/// FUT-style squad card: rating on top, avatar, name, position.
struct PlayerCardView: View {
    let player: Player
    var season: Int
    var slotLabel: String?

    private var hasGrowth: Bool { player.potential - player.overall >= 8 }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top) {
                Text("\(player.overall)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.tierColor(player.overall))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if player.isInjured {
                        Image(systemName: "cross.circle.fill").foregroundStyle(Theme.negative)
                    }
                    if hasGrowth {
                        Image(systemName: "arrow.up.right").foregroundStyle(Theme.positive)
                    }
                }
                .font(.caption)
            }
            PlayerAvatar(player: player, size: 42)
            Text(player.shortName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(slotLabel ?? player.position.shortLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.tierColor(player.overall).opacity(0.8), lineWidth: 1)
        )
        .opacity(player.isInjured ? 0.6 : 1)
    }
}

/// Compact list row used on the transfer market and elsewhere.
struct PlayerRow: View {
    let player: Player
    let season: Int
    var clubName: String?
    var trailing: String?

    var body: some View {
        HStack(spacing: 12) {
            PlayerAvatar(player: player, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(Flags.emoji(player.nationality)).font(.caption)
                    Text(player.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                Text([player.position.shortLabel, L("format.age", String(player.age(in: season))), clubName]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.overall)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.tierColor(player.overall))
                if let trailing {
                    Text(trailing)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
