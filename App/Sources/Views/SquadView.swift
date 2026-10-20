import SwiftUI
import GameEngine

struct SquadView: View {
    @Environment(GameStore.self) private var store
    @State private var mode = Mode.lineup

    enum Mode: String, CaseIterable, Identifiable {
        case lineup, squad
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            if let career = store.career {
                VStack(spacing: 14) {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(L("squad.mode.\(mode.rawValue)")).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    summary(career)

                    switch mode {
                    case .lineup: LineupPitch(career: career)
                    case .squad: squadGrid(career)
                    }
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("tab.squad"))
        .navigationBarTitleDisplayMode(.inline)
        .gameDestinations()
    }

    private func summary(_ career: Career) -> some View {
        let squad = career.userSquad
        let lineup = career.userLineup
        let strength = MatchEngine.strength(of: lineup)
        let averageAge = squad.isEmpty ? 0 : Double(squad.map { $0.age(in: career.season) }.reduce(0, +)) / Double(squad.count)
        return HStack(spacing: 8) {
            StatTile(title: L("squad.attack"), value: String(Int(strength.attack.rounded())))
            StatTile(title: L("squad.defence"), value: String(Int(strength.defence.rounded())))
            StatTile(title: L("squad.players"), value: String(squad.count))
            StatTile(title: L("squad.avgAge"), value: String(format: "%.1f", averageAge))
        }
    }

    private func squadGrid(_ career: Career) -> some View {
        let squad = career.userSquad
        let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Position.Line.allCases, id: \.self) { line in
                let group = squad.filter { $0.position.line == line }
                if !group.isEmpty {
                    SectionTitle(text: L("line.\(line.rawValue)"))
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(group) { player in
                            NavigationLink(value: PlayerLink(id: player.id)) {
                                PlayerCardView(player: player, season: career.season)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
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

/// The automatically chosen best XI drawn on a pitch (4-3-3).
struct LineupPitch: View {
    let career: Career

    var body: some View {
        let lineup = career.userLineup
        let rows: [[LineupSlot]] = [Position.Line.attack, .midfield, .defence, .goalkeeper].map { line in
            arrange(lineup.filter { $0.slot.line == line })
        }
        VStack(spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.player.id) { entry in
                        NavigationLink(value: PlayerLink(id: entry.player.id)) {
                            PlayerCardView(player: entry.player, season: career.season, slotLabel: entry.slot.shortLabel)
                                .frame(maxWidth: 84)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Text(L("squad.autoLineup"))
                .font(.caption2)
                .foregroundStyle(Color(hex: "C0DD97"))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(PitchBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// How central a slot sits in its line (higher = more central).
    private func centrality(_ slot: Position) -> Int {
        switch slot {
        case .winger, .fullBack: return 0
        case .centreBack, .centralMid: return 1
        case .defensiveMid, .striker, .attackingMid, .goalkeeper: return 2
        }
    }

    /// Places central players in the middle and wide players on the flanks (e.g. W ST W, FB CB CB FB).
    private func arrange(_ entries: [LineupSlot]) -> [LineupSlot] {
        var row: [LineupSlot] = []
        for (index, entry) in entries.sorted(by: { centrality($0.slot) > centrality($1.slot) }).enumerated() {
            if index % 2 == 0 { row.append(entry) } else { row.insert(entry, at: 0) }
        }
        return row
    }
}
