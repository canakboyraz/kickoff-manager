import SwiftUI
import GameEngine

/// FUT-style pack opening: the pack bursts open, then each card is revealed, best last.
/// Star and legend players get a walkout: flag, then position, then club, then the card.
struct PackOpeningView: View {
    let pack: PackType
    let cards: [RevealedCard]
    let onDone: () -> Void

    @Environment(GameStore.self) private var store

    enum Stage: Equatable {
        case sealed
        case card(index: Int, walkoutStep: Int)
        case summary
    }

    @State private var stage = Stage.sealed
    @State private var shake = false
    @State private var flash = 0.0
    @State private var revealToken = 0
    @State private var walkoutTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            background
            switch stage {
            case .sealed:
                sealedPack
            case .card(let index, let step):
                cardStage(cards[index], index: index, step: step)
            case .summary:
                summary
            }
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: revealToken)
        .statusBarHidden()
    }

    // MARK: Flow

    private func advance() {
        switch stage {
        case .sealed:
            withAnimation(.easeInOut(duration: 0.08).repeatCount(8, autoreverses: true)) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.15)) { flash = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    show(index: 0)
                    withAnimation(.easeIn(duration: 0.5)) { flash = 0 }
                }
            }
        case .card(let index, let step):
            if cards[index].reward.isWalkout && step < 3 {
                // Skip the walkout straight to the card.
                walkoutTask?.cancel()
                reveal(index: index, step: 3)
            } else if index + 1 < cards.count {
                show(index: index + 1)
            } else {
                withAnimation(.spring) { stage = .summary }
            }
        case .summary:
            onDone()
        }
    }

    private func show(index: Int) {
        walkoutTask?.cancel()
        let card = cards[index]
        guard card.reward.isWalkout else {
            reveal(index: index, step: 3)
            return
        }
        reveal(index: index, step: 0)
        walkoutTask = Task { @MainActor in
            for step in 1...3 {
                try? await Task.sleep(for: .milliseconds(1_100))
                guard !Task.isCancelled else { return }
                reveal(index: index, step: step)
            }
        }
    }

    private func reveal(index: Int, step: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            stage = .card(index: index, walkoutStep: step)
        }
        revealToken += 1
    }

    // MARK: Pieces

    private var season: Int { store.career?.season ?? Calendar.current.component(.year, from: Date()) }

    private var currentRarity: Rarity {
        if case .card(let index, _) = stage { return cards[index].reward.rarity }
        return .common
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "02060E"), Color(hex: "0B1730")], startPoint: .top, endPoint: .bottom)
            if case .card = stage {
                LightRays(color: currentRarity.color, intensity: currentRarity >= .epic ? 1 : 0.45)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }

    private var sealedPack: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(pack.gradient)
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                VStack(spacing: 12) {
                    Image(systemName: "soccerball")
                        .font(.system(size: 70, weight: .bold))
                    Text(pack.name.uppercased())
                        .font(.title.weight(.black))
                        .tracking(2)
                    Text(L("store.cards", String(pack.cardCount)))
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6)
            }
            .frame(width: 230, height: 330)
            .rotationEffect(.degrees(shake ? 3 : -3))
            .shadow(color: Color(hex: pack.colors[0]).opacity(0.6), radius: 30)
            Text(L("pack.tapToOpen"))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private func cardStage(_ card: RevealedCard, index: Int, step: Int) -> some View {
        VStack(spacing: 22) {
            Text(L("pack.progress", String(index + 1), String(cards.count)))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            switch card.reward {
            case .player(let player, let tier):
                if step < 3 {
                    walkout(player, step: step)
                } else {
                    PackPlayerCard(player: player, tier: tier, season: season)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                    Text(L("pack.joined", store.career?.userClub.shortName ?? ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            case .cosmetic(let item, let isNew):
                CosmeticRevealCard(item: item, isNew: isNew)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            case .points(let amount, let reason):
                VStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(Theme.positive)
                    Text("+\(Fmt.number(amount))")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .transition(.scale.combined(with: .opacity))
            }
            Spacer()
            Text(L("pack.tapToContinue"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 30)
        }
        .padding(.horizontal, 24)
        .id("\(index)-\(step)")
    }

    @ViewBuilder
    private func walkout(_ player: Player, step: Int) -> some View {
        VStack(spacing: 18) {
            Text(Flags.emoji(player.nationality))
                .font(.system(size: 110))
            if step >= 1 {
                Text(player.position.longLabel.uppercased())
                    .font(.title.weight(.black))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if step >= 2, let career = store.career {
                CrestView(club: career.userClub, size: 90)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Text(L("pack.summary"))
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .padding(.top, 40)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(cards) { card in
                        summaryTile(card.reward)
                    }
                }
                .padding(.horizontal, 16)
            }
            Button(L("pack.done")) { onDone() }
                .buttonStyle(GoldButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func summaryTile(_ reward: PackReward) -> some View {
        switch reward {
        case .player(let player, let tier):
            PackPlayerCard(player: player, tier: tier, season: season).scaleEffect(0.6).frame(height: 210)
        case .cosmetic(let item, let isNew):
            CosmeticRevealCard(item: item, isNew: isNew).scaleEffect(0.6).frame(height: 210)
        case .points(let amount, _):
            VStack {
                Image(systemName: "star.circle.fill").font(.largeTitle).foregroundStyle(Theme.positive)
                Text("+\(Fmt.number(amount))").font(.headline.weight(.black)).foregroundStyle(.white)
            }
            .frame(height: 210)
        }
    }
}

// MARK: - Cards

/// Big FUT-style card for a player pulled from a pack.
struct PackPlayerCard: View {
    let player: Player
    let tier: PackPlayerTier
    let season: Int

    private var colors: [Color] {
        switch tier {
        case .prospect: return [Color(hex: "7FD3FF"), Color(hex: "1E6FB8"), Color(hex: "0A2A4F")]
        case .solid: return [Color(hex: "F2F4F7"), Color(hex: "A7AFB9"), Color(hex: "4A5260")]
        case .star: return [Color(hex: "FFF1B8"), Color(hex: "EF9F27"), Color(hex: "6B3B00")]
        case .legend: return [Color(hex: "FFE7FF"), Color(hex: "B27BFF"), Color(hex: "2A0B5E")]
        }
    }

    private var textColor: Color { tier == .solid ? Color(hex: "1A1F2A") : .white }

    var body: some View {
        let kinds = AttributeKind.allCases.filter { player.position == .goalkeeper || $0 != .goalkeeping }.prefix(6)
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(spacing: 0) {
                    Text("\(player.overall)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                    Text(player.position.shortLabel)
                        .font(.headline.weight(.heavy))
                    Text(Flags.emoji(player.nationality)).font(.title2)
                }
                Spacer()
                Text(L("pack.tier.\(tier.rawValue)").uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.25), in: Capsule())
            }
            PlayerAvatar(player: player, size: 96)
                .overlay(Circle().stroke(textColor.opacity(0.5), lineWidth: 2))
            Text(player.lastName.uppercased())
                .font(.title3.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Divider().overlay(textColor.opacity(0.4))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(Array(kinds), id: \.self) { kind in
                    HStack(spacing: 6) {
                        Text("\(player.attributes[kind])").font(.subheadline.weight(.black).monospacedDigit())
                        Text(kind.shortLabel).font(.caption.weight(.semibold)).opacity(0.85)
                        Spacer(minLength: 0)
                    }
                }
            }
            Text(L("pack.potential", String(player.potential), String(player.age(in: season))))
                .font(.caption2.weight(.semibold))
                .opacity(0.8)
        }
        .foregroundStyle(textColor)
        .padding(18)
        .frame(width: 250)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 2))
        .shadow(color: colors[1].opacity(0.8), radius: tier == .legend || tier == .star ? 30 : 12)
    }
}

struct CosmeticRevealCard: View {
    let item: Cosmetic
    let isNew: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text(item.kind.label.uppercased())
                .font(.caption.weight(.black))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
            CosmeticTile(item: item)
                .frame(width: 150)
                .scaleEffect(1.3)
                .padding(.vertical, 20)
            Text(item.name)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(item.rarity.label.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(item.rarity.color)
            Text(isNew ? L("pack.new") : L("pack.duplicate", Fmt.number(item.rarity.duplicateRefund)))
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((isNew ? Theme.positive : Theme.surfaceRaised).opacity(0.9), in: Capsule())
                .foregroundStyle(isNew ? Theme.goldDark : .white)
        }
        .padding(22)
        .frame(width: 250)
        .background(Theme.backgroundDeep.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(item.rarity.color, lineWidth: 2.5))
        .shadow(color: item.rarity.color.opacity(0.7), radius: item.rarity >= .epic ? 30 : 10)
    }
}

/// Slowly turning beams of light behind the revealed card.
struct LightRays: View {
    let color: Color
    var intensity: Double = 1

    var body: some View {
        TimelineView(.animation) { context in
            let angle = context.date.timeIntervalSinceReferenceDate * 12
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
                let radius = max(size.width, size.height)
                for index in 0..<14 {
                    let start = Angle.degrees(angle + Double(index) * 360 / 14)
                    var path = Path()
                    path.move(to: center)
                    path.addArc(center: center, radius: radius, startAngle: start, endAngle: start + .degrees(9), clockwise: false)
                    path.closeSubpath()
                    canvas.fill(path, with: .radialGradient(
                        Gradient(colors: [color.opacity(0.55 * intensity), color.opacity(0)]),
                        center: center, startRadius: 10, endRadius: radius * 0.7))
                }
                canvas.fill(Path(ellipseIn: CGRect(x: center.x - 140, y: center.y - 140, width: 280, height: 280)),
                            with: .radialGradient(Gradient(colors: [color.opacity(0.6 * intensity), .clear]),
                                                  center: center, startRadius: 0, endRadius: 140))
            }
        }
        .allowsHitTesting(false)
    }
}
