import SwiftUI
import GameEngine

/// Send scouts out with a brief; the players they find are cheaper to sign this season.
struct ScoutView: View {
    @Environment(GameStore.self) private var store
    @State private var position: Position?
    @State private var maxAge = 0
    @State private var minPotential = 0
    @State private var countryCode: String?
    @State private var maxValue = 0
    @State private var notice: String?

    var body: some View {
        ScrollView {
            if let career = store.career {
                VStack(spacing: 14) {
                    Label(L("scout.hint"), systemImage: "binoculars.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gameCard(padding: 10, highlight: Theme.positive.opacity(0.5))
                    briefCard(career)
                    if !career.scoutMissions.isEmpty {
                        missions(career)
                    }
                    found(career)
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("scout.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(L("common.ok")) {}
        }
    }

    // MARK: - Brief

    private var brief: ScoutBrief {
        ScoutBrief(
            position: position,
            maxAge: maxAge > 0 ? maxAge : nil,
            minPotential: minPotential > 0 ? minPotential : nil,
            countryCode: countryCode,
            maxValue: maxValue > 0 ? maxValue : nil
        )
    }

    private func briefCard(_ career: Career) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: L("scout.brief"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(L("transfers.all"), selected: position == nil) { position = nil }
                    ForEach(Position.allCases, id: \.self) { item in
                        chip(item.shortLabel, selected: position == item) { position = item }
                    }
                }
            }
            optionRow(L("scout.league"), value: countryCode.map { code in
                career.leagues.first { $0.countryCode == code }.map { "\(Flags.emoji(code)) \($0.name)" } ?? code
            } ?? L("scout.allLeagues")) {
                Button(L("scout.allLeagues")) { countryCode = nil }
                ForEach(career.leagues) { league in
                    Button("\(Flags.emoji(league.countryCode)) \(league.name)") { countryCode = league.countryCode }
                }
            }
            optionRow(L("scout.maxAge"), value: maxAge > 0 ? L("transfers.maxAge", String(maxAge)) : L("transfers.anyAge")) {
                Button(L("transfers.anyAge")) { maxAge = 0 }
                ForEach([19, 21, 23, 25, 28], id: \.self) { age in
                    Button(L("transfers.maxAge", String(age))) { maxAge = age }
                }
            }
            optionRow(L("scout.minPotential"), value: minPotential > 0 ? "\(minPotential)+" : L("scout.any")) {
                Button(L("scout.any")) { minPotential = 0 }
                ForEach([70, 75, 80, 85], id: \.self) { value in
                    Button("\(value)+") { minPotential = value }
                }
            }
            optionRow(L("scout.maxValue"), value: maxValue > 0 ? Fmt.money(maxValue) : L("scout.any")) {
                Button(L("scout.any")) { maxValue = 0 }
                ForEach([1_000_000, 3_000_000, 5_000_000, 10_000_000, 20_000_000, 50_000_000], id: \.self) { value in
                    Button(Fmt.money(value)) { maxValue = value }
                }
            }
            Button {
                send(career)
            } label: {
                Label(L("scout.send", Fmt.money(career.scoutCost), String(Career.scoutWeeks(for: brief))),
                      systemImage: "paperplane.fill")
            }
            .buttonStyle(GoldButtonStyle())
            .disabled(career.scoutMissions.count >= Career.maxScoutMissions)
            if career.scoutMissions.count >= Career.maxScoutMissions {
                Text(L("scout.busy", String(Career.maxScoutMissions)))
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .gameCard()
    }

    private func send(_ career: Career) {
        let result = store.update { $0.startScoutMission(brief) }
        switch result {
        case .started(let weeks)?: notice = L("scout.started", String(weeks))
        case .tooManyMissions?: notice = L("scout.busy", String(Career.maxScoutMissions))
        case .insufficientFunds?: notice = L("scout.noMoney")
        case nil: break
        }
    }

    private func optionRow<Content: View>(_ title: String, value: String, @ViewBuilder options: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Menu {
                options()
            } label: {
                HStack(spacing: 4) {
                    Text(value).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.goldLight)
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Theme.goldDark : Theme.textPrimary)
                .background(selected ? Theme.gold : Theme.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Missions and reports

    private func missions(_ career: Career) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: L("scout.onTheRoad"))
            ForEach(career.scoutMissions) { mission in
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk.motion")
                        .foregroundStyle(Theme.goldLight)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary(mission.brief, career: career))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                        Text(L("scout.weeksLeft", String(mission.weeksLeft)))
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    Button {
                        store.update { $0.cancelScoutMission(mission.id) }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted)
                    }
                    .accessibilityLabel(L("common.cancel"))
                }
                .gameCard(padding: 10)
            }
        }
    }

    private func summary(_ brief: ScoutBrief, career: Career) -> String {
        var parts: [String] = []
        parts.append(brief.position?.longLabel ?? L("scout.anyPosition"))
        if let code = brief.countryCode { parts.append(Flags.countryName(code)) } else { parts.append(L("scout.allLeagues")) }
        if let age = brief.maxAge { parts.append(L("transfers.maxAge", String(age))) }
        if let potential = brief.minPotential { parts.append(L("scout.potentialShort", String(potential))) }
        if let value = brief.maxValue { parts.append("≤ \(Fmt.money(value))") }
        return parts.joined(separator: " · ")
    }

    private func found(_ career: Career) -> some View {
        let entries = career.scoutedPlayers
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: L("scout.found"))
            if entries.isEmpty {
                Text(L("scout.noneYet"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gameCard()
            }
            ForEach(entries, id: \.report.playerID) { entry in
                NavigationLink(value: PlayerLink(id: entry.player.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        PlayerRow(
                            player: entry.player,
                            season: career.season,
                            clubName: entry.player.clubID.flatMap { career.club($0)?.shortName } ?? L("freeAgent.badge"),
                            trailing: entry.player.isFreeAgent
                                ? Fmt.wage(career.wageDemand(for: entry.player.id))
                                : Fmt.money(career.askingPrice(for: entry.player.id)),
                            scouted: true
                        )
                        HStack(spacing: 6) {
                            HStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { index in
                                    Image(systemName: index < entry.report.stars ? "star.fill" : "star")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(Theme.gold)
                            Text(L("scout.potential", String(entry.player.potential)))
                            Spacer()
                            Text(L("scout.discounts",
                                   String(Int((entry.report.feeDiscount * 100).rounded())),
                                   String(Int((entry.report.wageDiscount * 100).rounded()))))
                                .foregroundStyle(Theme.positive)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    }
                    .gameCard(padding: 10)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
