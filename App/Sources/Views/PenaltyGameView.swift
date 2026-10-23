import SwiftUI

/// Daily penalty challenge. Tap once to fix the direction, once more to fix the height,
/// then the keeper dives. Top corners can't be saved, but aim too far and it goes wide.
struct PenaltyGameView: View {
    /// Called when the player closes the screen after shooting (true = goal).
    let onFinish: (Bool) -> Void

    enum Phase { case aimX, aimY, shot, done }

    enum Outcome {
        case goal, saved, wide, over, post

        var title: String {
            switch self {
            case .goal: return L("penalty.goal")
            case .saved: return L("penalty.saved")
            case .wide: return L("penalty.wide")
            case .over: return L("penalty.over")
            case .post: return L("penalty.post")
            }
        }
    }

    @State private var phase = Phase.aimX
    @State private var phaseStart = Date()
    @State private var aimX = 0.0
    @State private var aimY = 0.0
    /// Ball position: (0, -0.9) is the penalty spot, (x, y) inside the goal otherwise.
    @State private var ball = CGPoint(x: 0, y: -0.9)
    @State private var keeperZone = 0
    @State private var keeperHigh = false
    @State private var outcome: Outcome?

    private let swing = 1.12

    var body: some View {
        GeometryReader { geo in
            let goalWidth = geo.size.width * 0.86
            let goalHeight = goalWidth * 0.38
            let goalRect = CGRect(x: (geo.size.width - goalWidth) / 2, y: geo.size.height * 0.16,
                                  width: goalWidth, height: goalHeight)
            TimelineView(.animation(paused: phase == .shot || phase == .done)) { context in
                let liveX = phase == .aimX ? currentX(context.date) : aimX
                let liveY = phase == .aimY ? currentY(context.date) : aimY
                ZStack {
                    pitch
                    goal(goalRect)
                    keeper(goalRect)
                    if phase == .aimX || phase == .aimY {
                        aimMarker(x: liveX, y: phase == .aimY ? liveY : 0.5, goalRect: goalRect, showHeight: phase == .aimY)
                    }
                    ballView(goalRect: goalRect, size: geo.size)
                    overlayText(size: geo.size)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { tap() }
        }
        .ignoresSafeArea()
    }

    // MARK: - Aiming

    private func currentX(_ date: Date) -> Double {
        sin(date.timeIntervalSince(phaseStart) * 2.1) * swing
    }

    private func currentY(_ date: Date) -> Double {
        (1 - cos(date.timeIntervalSince(phaseStart) * 2.3)) / 2 * 1.2
    }

    private func tap() {
        switch phase {
        case .aimX:
            aimX = currentX(Date())
            phaseStart = Date()
            phase = .aimY
        case .aimY:
            aimY = currentY(Date())
            shoot()
        case .shot:
            break
        case .done:
            onFinish(outcome == .goal)
        }
    }

    private func shoot() {
        phase = .shot
        DailyRewards.markPenaltyTaken()
        let shotZone = aimX < -0.34 ? -1 : (aimX > 0.34 ? 1 : 0)
        // The keeper reads the shot 40% of the time, otherwise guesses one of the other zones.
        if Double.random(in: 0..<1) < 0.4 {
            keeperZone = shotZone
        } else {
            keeperZone = [-1, 0, 1].filter { $0 != shotZone }.randomElement() ?? 0
        }
        keeperHigh = aimY > 0.6

        let result: Outcome
        if abs(aimX) > 1.06 {
            result = .wide
        } else if aimY > 1.06 {
            result = .over
        } else if abs(aimX) > 0.98 || aimY > 0.98 {
            result = .post
        } else if keeperZone == shotZone {
            // Corners high up are out of reach.
            let reachable = shotZone == 0 ? aimY < 0.9 : (aimY < 0.68 || abs(aimX) < 0.75)
            result = reachable ? .saved : .goal
        } else {
            result = .goal
        }

        withAnimation(.easeOut(duration: 0.55)) {
            ball = CGPoint(x: aimX, y: aimY)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                outcome = result
                if result == .saved { ball = CGPoint(x: aimX * 0.6, y: -0.25) }
                phase = .done
            }
        }
    }

    // MARK: - Drawing

    private var pitch: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0B3D1F"), Color(hex: "14662F")], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.03 : 0))
                }
            }
        }
    }

    private func goal(_ rect: CGRect) -> some View {
        ZStack {
            // Net.
            Path { path in
                let step: CGFloat = 14
                var x = rect.minX
                while x <= rect.maxX {
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                    x += step
                }
                var y = rect.minY
                while y <= rect.maxY {
                    path.move(to: CGPoint(x: rect.minX, y: y))
                    path.addLine(to: CGPoint(x: rect.maxX, y: y))
                    y += step
                }
            }
            .stroke(Color.white.opacity(0.18), lineWidth: 1)
            // Posts and bar.
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            // Goal line.
            Path { path in
                path.move(to: CGPoint(x: rect.minX - 40, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX + 40, y: rect.maxY))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 2)
        }
    }

    private func keeper(_ rect: CGRect) -> some View {
        let height = rect.height * 0.78
        let diving = phase == .done || phase == .shot
        let dx = diving ? CGFloat(keeperZone) * rect.width * 0.3 : 0
        let lift = diving && keeperHigh ? rect.height * 0.18 : 0
        let angle = diving ? Double(keeperZone) * (keeperHigh ? 55 : 75) : 0
        return VStack(spacing: 2) {
            Circle().fill(Color(hex: "F2C9A0")).frame(width: height * 0.22, height: height * 0.22)
            ZStack {
                Capsule().fill(Theme.gold).frame(width: height * 0.95, height: height * 0.14)
                    .offset(y: -height * 0.12)
                RoundedRectangle(cornerRadius: 6).fill(Theme.gold).frame(width: height * 0.36, height: height * 0.42)
            }
            HStack(spacing: height * 0.06) {
                Capsule().fill(Color(hex: "1A1A1A")).frame(width: height * 0.12, height: height * 0.3)
                Capsule().fill(Color(hex: "1A1A1A")).frame(width: height * 0.12, height: height * 0.3)
            }
        }
        .rotationEffect(.degrees(angle))
        .position(x: rect.midX + dx, y: rect.maxY - height * 0.5 - lift)
        .animation(.easeOut(duration: 0.45), value: phase)
    }

    private func aimMarker(x: Double, y: Double, goalRect: CGRect, showHeight: Bool) -> some View {
        let point = CGPoint(x: goalRect.midX + x * goalRect.width / 2, y: goalRect.maxY - y * goalRect.height)
        return ZStack {
            if showHeight {
                Circle()
                    .stroke(Theme.goldLight, lineWidth: 3)
                    .frame(width: 30, height: 30)
                    .position(point)
            } else {
                Rectangle()
                    .fill(Theme.goldLight.opacity(0.8))
                    .frame(width: 3, height: goalRect.height + 30)
                    .position(x: point.x, y: goalRect.midY)
            }
        }
    }

    private func ballView(goalRect: CGRect, size: CGSize) -> some View {
        let spot = CGPoint(x: size.width / 2, y: goalRect.maxY + size.height * 0.48)
        let inFlight = ball.y > -0.9
        let target = CGPoint(x: goalRect.midX + ball.x * goalRect.width / 2, y: goalRect.maxY - ball.y * goalRect.height)
        let position = inFlight ? target : spot
        return Image(systemName: "soccerball")
            .font(.system(size: inFlight ? 22 : 40))
            .foregroundStyle(.white)
            .background(Circle().fill(Color.black).padding(3))
            .position(position)
    }

    private func overlayText(size: CGSize) -> some View {
        VStack(spacing: 10) {
            Spacer()
            if let outcome {
                Text(outcome.title)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(outcome == .goal ? Theme.goldLight : .white)
                    .transition(.scale.combined(with: .opacity))
                Text(outcome == .goal
                     ? L("penalty.reward", Fmt.money(DailyRewards.penaltyReward))
                     : L("penalty.tomorrow"))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                Text(L("penalty.tapToClose"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text(phase == .aimX ? L("penalty.aimDirection") : (phase == .aimY ? L("penalty.aimHeight") : " "))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(L("penalty.hint"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, size.height * 0.08)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
