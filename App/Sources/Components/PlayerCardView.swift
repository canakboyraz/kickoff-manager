import SwiftUI
import GameEngine

/// FUT-style card: rating, avatar, name, position, best three attributes and fitness.
struct PlayerCardView: View {
    let player: Player
    /// The slot he fills on the team sheet (position label turns amber when out of position).
    var slot: Position? = nil
    var isSelected = false
    /// Contract runs out at the end of this season.
    var contractEnding = false

    private var hasGrowth: Bool { player.potential - player.overall >= 8 }
    private var outOfPosition: Bool { slot.map { $0 != player.position } ?? false }
    private var tier: Color { Theme.tierColor(player.overall) }

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .top, spacing: 0) {
                Text("\(player.overall)")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(tier)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    if player.isInjured {
                        Image(systemName: "cross.circle.fill").foregroundStyle(Theme.negative)
                    } else if player.isSuspended {
                        Image(systemName: "rectangle.portrait.fill").foregroundStyle(Theme.negative)
                    } else if player.isTransferListed {
                        Image(systemName: "tag.fill").foregroundStyle(Theme.warning)
                    } else if contractEnding {
                        Image(systemName: "doc.text.fill").foregroundStyle(Theme.warning)
                    }
                    if hasGrowth {
                        Image(systemName: "arrow.up.right").foregroundStyle(Theme.positive)
                    }
                }
                .font(.system(size: 10, weight: .bold))
            }
            PlayerAvatar(player: player, size: 32)
            Text(player.lastName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            // Natural position always; when he fills a different slot, show it in amber.
            HStack(spacing: 2) {
                Text(player.position.shortLabel)
                    .foregroundStyle(Theme.textSecondary)
                if outOfPosition, let slot {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7, weight: .heavy))
                    Text(slot.shortLabel)
                }
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.warning)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            TopAttributesRow(player: player)
            ValueBar(value: player.fitness, maxValue: 100, color: Theme.fitnessColor(player.fitness), height: 4)
                .accessibilityLabel(L("player.fitness"))
                .accessibilityValue("\(player.fitness)")
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Theme.surfaceRaised : Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Theme.gold : tier.opacity(0.8), lineWidth: isSelected ? 2.5 : 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1)
        .opacity(player.isAvailable ? 1 : 0.65)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

/// The player's three best attributes, e.g. "88 PAC · 84 DRI · 80 SHO".
struct TopAttributesRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 2) {
            ForEach(player.topAttributes, id: \.self) { kind in
                let value = player.attributes[kind]
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.tierColor(value))
                    Text(kind.shortLabel)
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Placeholder for an empty starting or bench slot.
struct EmptySlotCard: View {
    let label: String
    var isSelected = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .font(.title3)
            Text(label)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(isSelected ? Theme.gold : Theme.textMuted)
        .frame(maxWidth: .infinity, minHeight: 118)
        .background(Theme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Theme.gold : Theme.stroke, style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: [4, 3]))
        )
    }
}

/// Compact list row used on the transfer market and elsewhere.
struct PlayerRow: View {
    let player: Player
    let season: Int
    var clubName: String?
    var trailing: String?
    /// Found by the club's scouts (cheaper to sign).
    var scouted = false

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
                    if player.isTransferListed {
                        Image(systemName: "tag.fill").font(.caption2).foregroundStyle(Theme.warning)
                    }
                    if scouted {
                        Image(systemName: "binoculars.fill").font(.caption2).foregroundStyle(Theme.positive)
                    }
                }
                Text([player.position.shortLabel, L("format.age", String(player.age(in: season))), clubName]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                Text(player.topAttributes.map { "\(player.attributes[$0]) \($0.shortLabel)" }.joined(separator: "  "))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
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
