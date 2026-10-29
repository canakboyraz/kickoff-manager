import SwiftUI
import GameEngine

/// Packs (bought with Kickoff Points) and the cosmetics shop with daily offers.
struct StoreView: View {
    @Environment(GameStore.self) private var store
    @State private var opening: [RevealedCard]?
    @State private var openingPack: PackType?
    @State private var oddsPack: PackType?
    @State private var confirmPack: PackType?
    @State private var notice: String?
    @State private var kind: CosmeticKind = .frame

    var body: some View {
        let profile = store.profile
        VStack(spacing: 14) {
            HStack {
                Label(L("points.balance", Fmt.number(profile.points)), systemImage: "star.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.positive)
                Spacer()
                Text(L("store.earnHint"))
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.trailing)
            }
            .gameCard(padding: 12)

            SectionTitle(text: L("store.packs"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(PackType.all) { pack in
                    PackTile(pack: pack, affordable: profile.points >= pack.cost) {
                        confirmPack = pack
                    } onOdds: {
                        oddsPack = pack
                    }
                }
            }
            Text(L("store.packsNote"))
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            SectionTitle(text: L("store.daily"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(CosmeticCatalog.dailyOffers()) { item in
                    shopButton(item, profile: profile)
                }
            }

            SectionTitle(text: L("store.catalog"))
            Picker("", selection: $kind) {
                ForEach(CosmeticKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(CosmeticCatalog.items(kind).filter { !$0.isDefault }) { item in
                    shopButton(item, profile: profile)
                }
            }
        }
        .confirmationDialog(
            confirmPack.map { L("store.confirm", $0.name, Fmt.number($0.cost)) } ?? "",
            isPresented: Binding(get: { confirmPack != nil }, set: { if !$0 { confirmPack = nil } }),
            titleVisibility: .visible,
            presenting: confirmPack
        ) { pack in
            Button(L("store.open")) { open(pack) }
        }
        .sheet(item: $oddsPack) { pack in
            OddsSheet(pack: pack).presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: Binding(get: { opening != nil }, set: { if !$0 { opening = nil } })) {
            if let opening, let openingPack {
                PackOpeningView(pack: openingPack, cards: opening) { self.opening = nil }
            }
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(L("common.ok")) {}
        }
    }

    private func open(_ pack: PackType) {
        guard let cards = PackOpener.open(pack, store: store) else {
            notice = L("store.notEnough")
            return
        }
        openingPack = pack
        opening = cards
    }

    private func shopButton(_ item: Cosmetic, profile: ProfileStore) -> some View {
        let owned = profile.owns(item)
        return Button {
            guard !owned else { return }
            if profile.buy(item) {
                notice = L("store.bought", item.name)
            } else {
                notice = L("store.notEnough")
            }
        } label: {
            CosmeticTile(item: item, owned: true, equipped: owned, price: owned ? nil : item.rarity.price)
        }
        .buttonStyle(.plain)
        .disabled(owned)
    }
}

struct PackTile: View {
    let pack: PackType
    let affordable: Bool
    let onOpen: () -> Void
    let onOdds: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(pack.gradient)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
                VStack(spacing: 4) {
                    Image(systemName: "soccerball")
                        .font(.system(size: 30, weight: .bold))
                    Text(pack.name.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(1)
                    Text(L("store.cards", String(pack.cardCount)))
                        .font(.caption2.weight(.semibold))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 3)
            }
            .frame(height: 130)
            Button(action: onOpen) {
                Label(Fmt.number(pack.cost), systemImage: "star.circle.fill")
                    .font(.subheadline.weight(.heavy))
            }
            .buttonStyle(GoldButtonStyle())
            .disabled(!affordable)
            .opacity(affordable ? 1 : 0.5)
            Button(L("store.odds"), action: onOdds)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Exact drop rates for each card in a pack (shown before buying).
struct OddsSheet: View {
    let pack: PackType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(pack.oddsTables.enumerated()), id: \.offset) { _, group in
                    Section(L("odds.section", String(group.cards))) {
                        ForEach(Array(group.rows.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text(L("odds.percent", String(format: "%.1f", row.percent)))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Text(L("odds.footer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("odds.title", pack.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }
}
