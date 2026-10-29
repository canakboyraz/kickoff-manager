import SwiftUI
import GameEngine

/// Profile tab: your card and cosmetics, the store with packs, and the online ranking.
struct ProfileHubView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("", selection: Binding(get: { store.profileSection }, set: { store.profileSection = $0 })) {
                    ForEach(ProfileSection.allCases, id: \.self) { section in
                        Text(L("profile.section.\(section.rawValue)")).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                switch store.profileSection {
                case .profile: MyProfileView()
                case .store: StoreView()
                case .ranking: RankingView()
                }
            }
            .padding(16)
        }
        .gameBackground()
        .navigationTitle(L("tab.profile"))
        .navigationBarTitleDisplayMode(.inline)
        .gameDestinations()
    }
}

// MARK: - Profile card

/// The profile card other managers see: background, frame, badge, title and stats.
struct ProfileCardView: View {
    let name: String
    let look: ProfileLook
    let points: Int
    var rank: Int?
    var photo: UIImage?

    @State private var spin = 0.0

    var body: some View {
        let frame = look.item(.frame)
        let background = look.item(.background)
        let badge = look.item(.badge)
        let title = look.item(.title)
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                if let rank {
                    Text("#\(rank)")
                        .font(.caption.weight(.heavy).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.35), in: Capsule())
                        .foregroundStyle(.white)
                }
                Spacer()
                BadgeIcon(item: badge, size: 34)
            }
            ProfileAvatar(name: name, photo: photo, frame: frame, size: 96)
            VStack(spacing: 6) {
                Text(name)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                TitleTag(item: title)
            }
            HStack(spacing: 0) {
                stat(Fmt.number(points), L("profile.stat.points"))
                stat("\(look.trophies)", L("profile.stat.trophies"))
                stat("\(look.seasons)", L("profile.stat.seasons"))
            }
            .padding(.vertical, 10)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(background.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(frameShading(frame), lineWidth: frame.rarity >= .epic ? 5 : 3)
        )
        .shadow(color: frame.rarity.color.opacity(frame.rarity >= .epic ? 0.55 : 0.2), radius: 14)
        .onAppear {
            guard frame.rarity == .legendary else { return }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { spin = 360 }
        }
    }

    private func frameShading(_ frame: Cosmetic) -> AnyShapeStyle {
        if frame.rarity == .legendary {
            return AnyShapeStyle(AngularGradient(colors: frame.colors.map(Color.init(hex:)), center: .center, angle: .degrees(spin)))
        }
        return AnyShapeStyle(frame.gradient)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.heavy).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProfileAvatar: View {
    let name: String
    var photo: UIImage?
    let frame: Cosmetic
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Theme.surfaceRaised)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(frame.gradient, lineWidth: max(3, size * 0.07)))
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "M" : String(letters).uppercased()
    }
}

struct BadgeIcon: View {
    let item: Cosmetic
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: item.symbol.isEmpty ? "star.fill" : item.symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(Color(hex: item.colors.first ?? "FAC775"))
            .frame(width: size, height: size)
            .background(Circle().fill(.black.opacity(0.35)))
            .overlay(Circle().stroke(item.rarity.color.opacity(0.8), lineWidth: 1.5))
            .shadow(color: item.rarity >= .epic ? item.rarity.color.opacity(0.7) : .clear, radius: 6)
    }
}

struct TitleTag: View {
    let item: Cosmetic

    var body: some View {
        Text(item.name.uppercased())
            .font(.caption.weight(.heavy))
            .tracking(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(item.rarity == .common ? .white : item.rarity.color)
            .background(.black.opacity(0.35), in: Capsule())
            .overlay(Capsule().stroke(item.rarity.color.opacity(0.7), lineWidth: 1))
    }
}

// MARK: - My profile

struct MyProfileView: View {
    @Environment(GameStore.self) private var store
    @State private var kind: CosmeticKind = .frame
    private let center = GameCenterManager.shared

    var body: some View {
        let profile = store.profile
        VStack(spacing: 14) {
            ProfileCardView(
                name: center.playerName.isEmpty ? L("profile.defaultName") : center.playerName,
                look: profile.look,
                points: profile.lifetimePoints
            )
            HStack {
                Label(L("points.balance", Fmt.number(profile.points)), systemImage: "star.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.positive)
                Spacer()
                Button(L("profile.goStore")) { store.profileSection = .store }
                    .font(.subheadline.weight(.semibold))
            }
            .gameCard(padding: 12)
            if !center.isAuthenticated {
                Button {
                    center.showDashboard()
                } label: {
                    Label(L("gc.signIn"), systemImage: "gamecontroller.fill")
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.goldLight))
                Text(L("gc.signInHint"))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            customize(profile)
            earnings
        }
    }

    private func customize(_ profile: ProfileStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("profile.customize"))
            Picker("", selection: $kind) {
                ForEach(CosmeticKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            let items = CosmeticCatalog.items(kind)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    let owned = profile.owns(item)
                    let equipped = profile.equipped(kind) == item
                    Button {
                        if owned { withAnimation(.snappy) { profile.equip(item) } }
                    } label: {
                        CosmeticTile(item: item, owned: owned, equipped: equipped)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(L("profile.lockedHint"))
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .gameCard()
    }

    private var earnings: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: L("profile.howToEarn"))
            ForEach(["win", "title", "cup", "sale", "season"], id: \.self) { key in
                Label(L("profile.earn.\(key)"), systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard()
    }
}

/// A cosmetic preview square used in the profile editor and the store.
struct CosmeticTile: View {
    let item: Cosmetic
    var owned = true
    var equipped = false
    var price: Int?

    var body: some View {
        VStack(spacing: 6) {
            preview
                .frame(height: 54)
            Text(item.name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            if let price {
                Label(Fmt.number(price), systemImage: "star.circle.fill")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.positive)
            } else {
                Text(equipped ? L("profile.equipped") : (owned ? item.rarity.label : L("profile.locked")))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(equipped ? Theme.gold : item.rarity.color)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Theme.surfaceRaised.opacity(owned ? 1 : 0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(equipped ? Theme.gold : item.rarity.color.opacity(owned ? 0.7 : 0.3), lineWidth: equipped ? 2.5 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if !owned && price == nil {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(Theme.textMuted).padding(6)
            }
        }
        .opacity(owned || price != nil ? 1 : 0.7)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .frame:
            RoundedRectangle(cornerRadius: 10).fill(Theme.backgroundDeep)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(item.gradient, lineWidth: 5))
                .frame(width: 54)
        case .background:
            RoundedRectangle(cornerRadius: 10).fill(item.gradient).frame(width: 70)
        case .badge:
            BadgeIcon(item: item, size: 46)
        case .title:
            TitleTag(item: item).scaleEffect(0.8)
        }
    }
}

// MARK: - Online ranking

struct RankingView: View {
    private let center = GameCenterManager.shared

    var body: some View {
        VStack(spacing: 12) {
            if !center.isAuthenticated {
                VStack(spacing: 10) {
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.goldLight)
                    Text(L("ranking.signIn"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button(L("gc.signIn")) { center.showDashboard() }
                        .buttonStyle(GoldButtonStyle())
                }
                .gameCard()
            } else {
                HStack {
                    SectionTitle(text: L("ranking.title"))
                    Spacer()
                    Button {
                        center.showDashboard()
                    } label: {
                        Label(L("ranking.achievements"), systemImage: "rosette")
                            .font(.caption.weight(.semibold))
                    }
                }
                if center.isLoading && center.ranking.isEmpty {
                    ProgressView().padding(30)
                } else if center.ranking.isEmpty {
                    Text(center.loadFailed ? L("ranking.failed") : L("ranking.empty"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 24)
                }
                if let first = center.ranking.first {
                    ProfileCardView(name: first.name, look: first.look, points: first.points,
                                    rank: first.rank, photo: center.photo(for: first.id))
                }
                ForEach(center.ranking.dropFirst()) { row in
                    RankingRow(row: row, photo: center.photo(for: row.id))
                }
            }
        }
        .task { await center.loadRanking() }
        .refreshable { await center.loadRanking() }
    }
}

struct RankingRow: View {
    let row: OnlineManager
    var photo: UIImage?

    var body: some View {
        let background = row.look.item(.background)
        HStack(spacing: 10) {
            Text("\(row.rank)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(row.rank <= 3 ? Theme.gold : .white.opacity(0.8))
                .frame(width: 30)
            ProfileAvatar(name: row.name, photo: photo, frame: row.look.item(.frame), size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                TitleTag(item: row.look.item(.title))
                    .scaleEffect(0.8, anchor: .leading)
            }
            Spacer(minLength: 4)
            BadgeIcon(item: row.look.item(.badge), size: 28)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.number(row.points))
                    .font(.subheadline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Theme.positive)
                Label("\(row.look.trophies)", systemImage: "trophy.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(10)
        .background(background.gradient.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(row.isMe ? Theme.gold : row.look.item(.frame).rarity.color.opacity(0.6), lineWidth: row.isMe ? 2.5 : 1)
        )
    }
}
