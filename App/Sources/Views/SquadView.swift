import SwiftUI
import GameEngine

/// Team sheet: starting eleven on the pitch, seven substitutes and the rest of the squad.
/// Tap one player, then another, to swap them.
struct SquadView: View {
    @Environment(GameStore.self) private var store
    @State private var selection: LineupRef?

    private let gridColumns = [GridItem(.adaptive(minimum: 72), spacing: 6)]

    var body: some View {
        ScrollView {
            if let career = store.career {
                VStack(spacing: 14) {
                    controls(career)
                    warnings(career)
                    pitch(career)
                    bench(career)
                    reserves(career)
                }
                .padding(16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let career = store.career, let ref = selection, let player = career.lineupPlayer(ref) {
                selectionBar(player)
            }
        }
        .gameBackground()
        .navigationTitle(L("tab.squad"))
        .navigationBarTitleDisplayMode(.inline)
        .gameDestinations()
        .sensoryFeedback(.selection, trigger: selection)
    }

    // MARK: - Sections

    private func controls(_ career: Career) -> some View {
        let strength = MatchEngine.strength(of: career.teamSheet(for: career.userClubID))
        let starters = career.userStarters.compactMap { $0 }
        let fitness = starters.isEmpty ? 0 : starters.map(\.fitness).reduce(0, +) / starters.count
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(Formation.allCases, id: \.self) { formation in
                        Button {
                            withAnimation(.snappy) {
                                store.update { $0.setFormation(formation) }
                                selection = nil
                            }
                        } label: {
                            if formation == career.userTactics.formation {
                                Label(formation.rawValue, systemImage: "checkmark")
                            } else {
                                Text(formation.rawValue)
                            }
                        }
                    }
                } label: {
                    Label(career.userTactics.formation.rawValue, systemImage: "rectangle.split.3x3")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.goldDark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.gold, in: Capsule())
                }
                Spacer()
                Button {
                    withAnimation(.snappy) {
                        store.update { $0.autoPickLineup() }
                        selection = nil
                    }
                } label: {
                    Label(L("squad.auto"), systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                StatTile(title: L("squad.attack"), value: String(Int(strength.attack.rounded())))
                StatTile(title: L("squad.defence"), value: String(Int(strength.defence.rounded())))
                StatTile(title: L("squad.fitness"), value: "\(fitness)%")
            }
            Text(L("squad.hint"))
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func warnings(_ career: Career) -> some View {
        let starters = career.userStarters
        let picked = starters.compactMap { $0 }
        let injured = picked.filter { !$0.isAvailable }.count
        let tired = picked.filter { $0.isAvailable && $0.fitness < 70 }.count
        let empty = starters.filter { $0 == nil }.count
        if injured > 0 || tired > 0 || empty > 0 {
            VStack(alignment: .leading, spacing: 6) {
                if injured > 0 {
                    warningLine(icon: "cross.case.fill", text: L("squad.warn.injured", String(injured)), color: Theme.negative)
                }
                if empty > 0 {
                    warningLine(icon: "exclamationmark.triangle.fill", text: L("squad.warn.empty", String(empty)), color: Theme.warning)
                }
                if tired > 0 {
                    warningLine(icon: "battery.25", text: L("squad.warn.tired", String(tired)), color: Theme.warning)
                }
            }
            .gameCard(padding: 10)
        }
    }

    private func warningLine(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pitch(_ career: Career) -> some View {
        let rows = career.userTactics.formation.rows
        let starters = career.userStarters
        let offsets = rowOffsets(rows)
        return VStack(spacing: 10) {
            ForEach(Array(rows.indices.reversed()), id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(Array(rows[rowIndex].enumerated()), id: \.offset) { column, slot in
                        let index = offsets[rowIndex] + column
                        slotView(ref: .starter(index), player: index < starters.count ? starters[index] : nil, slot: slot)
                            .frame(maxWidth: 76)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(PitchBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bench(_ career: Career) -> some View {
        let ids = career.userTactics.bench
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: L("squad.bench", String(min(ids.count, Tactics.benchSize)), String(Tactics.benchSize)))
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(0..<Tactics.benchSize, id: \.self) { index in
                    slotView(ref: .bench(index), player: index < ids.count ? career.player(ids[index]) : nil, slot: nil)
                }
            }
        }
    }

    private func reserves(_ career: Career) -> some View {
        let reserves = career.userReserves
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: L("squad.reserves", String(reserves.count)))
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(reserves) { player in
                    slotView(ref: .reserve(player.id), player: player, slot: nil)
                }
            }
        }
    }

    private func selectionBar(_ player: Player) -> some View {
        HStack(spacing: 10) {
            PlayerAvatar(player: player, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(L("squad.swapHint"))
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            NavigationLink(value: PlayerLink(id: player.id)) {
                Image(systemName: "person.text.rectangle")
                    .font(.title3)
            }
            .accessibilityLabel(L("squad.profile"))
            Button {
                selection = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel(L("common.cancel"))
        }
        .foregroundStyle(Theme.gold)
        .padding(12)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Cards and taps

    @ViewBuilder
    private func slotView(ref: LineupRef, player: Player?, slot: Position?) -> some View {
        Button {
            tap(ref)
        } label: {
            if let player {
                PlayerCardView(player: player, slot: slot, isSelected: selection == ref)
            } else {
                EmptySlotCard(label: slot?.shortLabel ?? L("squad.emptyBench"), isSelected: selection == ref)
            }
        }
        .buttonStyle(.plain)
    }

    private func tap(_ ref: LineupRef) {
        guard let current = selection else {
            selection = ref
            return
        }
        if current == ref {
            selection = nil
            return
        }
        // Two reserves can't be swapped; just move the selection.
        if case .reserve = current, case .reserve = ref {
            selection = ref
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.update { $0.swapLineup(current, ref) }
            selection = nil
        }
    }

    private func rowOffsets(_ rows: [[Position]]) -> [Int] {
        var offsets: [Int] = []
        var total = 0
        for row in rows {
            offsets.append(total)
            total += row.count
        }
        return offsets
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.goldLight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
