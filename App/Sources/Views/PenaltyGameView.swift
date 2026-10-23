import SwiftUI

/// Daily penalty challenge in a floodlit stadium. Three taps: direction, height, power.
/// The keeper sways while you aim, reads half the shots and covers a lot of the goal,
/// so only well-placed, well-struck penalties go in.
struct PenaltyGameView: View {
    /// Called when the player closes the screen after shooting (true = goal).
    let onFinish: (Bool) -> Void

    enum Phase: Int { case aimX, aimY, power, shot, done }

    enum Outcome: Equatable {
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
    @State private var power = 0.0
    /// Ball in goal coordinates: x -1…1 post to post, y 0…1 ground to bar. nil = on the spot.
    @State private var ballTarget: CGPoint?
    @State private var ballSpin = 0.0
    @State private var keeperDive = CGPoint.zero
    @State private var keeperDiving = false
    @State private var outcome: Outcome?
    @State private var resultTime = Date()

    // MARK: - Difficulty

    /// Sweep speeds (full left-right cycles per second); each phase is quicker than the last.
    private let xSpeed = 0.75
    private let ySpeed = 0.9
    private let powerSpeed = 1.1
    /// How far the markers swing past the posts and bar.
    private let xSwing = 1.15
    private let ySwing = 1.15
    /// Chance the keeper reads the shot's side.
    private let keeperReads = 0.5

    var body: some View {
        GeometryReader { geo in
            let layout = Layout(size: geo.size)
            TimelineView(.animation) { context in
                let now = context.date
                let liveX = phase == .aimX ? sweep(now, speed: xSpeed) * xSwing : aimX
                let liveY = phase == .aimY ? (sweep(now, speed: ySpeed) + 1) / 2 * ySwing : aimY
                let livePower = phase == .power ? (sweep(now, speed: powerSpeed) + 1) / 2 : power
                let sway = phase.rawValue < Phase.shot.rawValue ? sin(now.timeIntervalSince1970 * 2.6) * 0.12 : 0
                ZStack {
                    Stadium(layout: layout, time: now.timeIntervalSince1970)
                    GoalFrame(layout: layout, bulge: outcome == .goal ? ballTarget : nil)
                    keeper(layout, sway: sway)
                    if phase.rawValue <= Phase.power.rawValue {
                        aimMarkers(layout, x: liveX, y: liveY, showHeight: phase != .aimX)
                    }
                    ball(layout)
                    if outcome == .goal {
                        Confetti(start: resultTime, now: now, size: geo.size)
                    }
                    hud(layout, power: livePower)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { tap() }
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .medium), trigger: phase)
        .sensoryFeedback(.success, trigger: outcome == .goal)
    }

    // MARK: - Input

    /// Triangle wave between -1 and 1: constant speed, no slowing down at the edges.
    private func sweep(_ date: Date, speed: Double) -> Double {
        let t = date.timeIntervalSince(phaseStart) * speed
        let phase = t - floor(t)
        return phase < 0.5 ? -1 + phase * 4 : 3 - phase * 4
    }

    private func tap() {
        let now = Date()
        switch phase {
        case .aimX:
            aimX = sweep(now, speed: xSpeed) * xSwing
            phaseStart = now
            phase = .aimY
        case .aimY:
            aimY = (sweep(now, speed: ySpeed) + 1) / 2 * ySwing
            phaseStart = now
            phase = .power
        case .power:
            power = (sweep(now, speed: powerSpeed) + 1) / 2
            shoot()
        case .shot:
            break
        case .done:
            onFinish(outcome == .goal)
        }
    }

    // MARK: - Shot

    private func shoot() {
        phase = .shot
        DailyRewards.markPenaltyTaken()

        // Too much power sends the ball higher; too little lets the keeper get there.
        var y = aimY
        if power > 0.85 { y += (power - 0.85) * 2.2 }
        let x = aimX
        let weak = power < 0.4

        let shotSide = x < -0.3 ? -1.0 : (x > 0.3 ? 1.0 : 0.0)
        let side: Double
        if Double.random(in: 0..<1) < keeperReads {
            side = shotSide
        } else {
            side = [-1.0, 0.0, 1.0].filter { $0 != shotSide }.randomElement() ?? 0
        }
        let high = Bool.random()
        keeperDive = CGPoint(x: side * 0.58, y: side == 0 ? (high ? 0.55 : 0.25) : (high ? 0.62 : 0.3))

        let result: Outcome
        if abs(x) > 1.0 {
            result = .wide
        } else if y > 1.0 {
            result = .over
        } else if abs(x) > 0.94 || y > 0.94 {
            result = .post
        } else {
            let dx = x - Double(keeperDive.x)
            let dy = (y - Double(keeperDive.y)) * 1.3
            var reach = 0.46
            if weak { reach *= 1.45 }
            if power > 0.7 { reach *= 0.85 }
            result = (dx * dx + dy * dy).squareRoot() < reach ? .saved : .goal
        }

        withAnimation(.easeOut(duration: 0.38)) {
            keeperDiving = true
        }
        let flight = weak ? 0.75 : 0.5
        withAnimation(.easeOut(duration: flight)) {
            ballTarget = CGPoint(x: x, y: min(y, 1.25))
            ballSpin += weak ? 360 : 900
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + flight + 0.05) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                switch result {
                case .saved:
                    ballTarget = CGPoint(x: x * 0.4 + Double(keeperDive.x) * 0.2, y: -0.55)
                case .post:
                    ballTarget = CGPoint(x: x * 0.7, y: -0.35)
                default:
                    break
                }
                resultTime = Date()
                outcome = result
                phase = .done
            }
        }
    }

    // MARK: - Pieces

    private func keeper(_ layout: Layout, sway: Double) -> some View {
        let height = layout.goal.height * 0.8
        let target = keeperDiving ? keeperDive : CGPoint(x: sway, y: 0)
        let point = layout.point(x: target.x, y: target.y)
        let angle = keeperDiving ? Double(keeperDive.x) * 110 : sway * 40
        return ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.35))
                .frame(width: height * 0.6, height: height * 0.12)
                .position(x: layout.point(x: target.x, y: 0).x, y: layout.goal.maxY + 2)
            KeeperFigure(height: height)
                .rotationEffect(.degrees(angle))
                .position(x: point.x, y: point.y - (keeperDiving ? 0 : height * 0.5))
        }
    }

    private func aimMarkers(_ layout: Layout, x: Double, y: Double, showHeight: Bool) -> some View {
        let p = layout.point(x: x, y: showHeight ? y : 0.5)
        return ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [Theme.goldLight.opacity(0), Theme.goldLight, Theme.goldLight.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: layout.goal.height + 40)
                .position(x: p.x, y: layout.goal.midY)
                .opacity(showHeight ? 0.35 : 1)
            if showHeight {
                ZStack {
                    Circle().stroke(Theme.goldLight, lineWidth: 3)
                    Circle().fill(Theme.goldLight.opacity(0.25))
                    Rectangle().fill(Theme.goldLight).frame(width: 2, height: 12)
                    Rectangle().fill(Theme.goldLight).frame(width: 12, height: 2)
                }
                .frame(width: 30, height: 30)
                .position(p)
            }
        }
    }

    private func ball(_ layout: Layout) -> some View {
        let spot = layout.spot
        let position = ballTarget.map { layout.point(x: $0.x, y: $0.y) } ?? spot
        let depth = ballTarget == nil ? 1.0 : 0.5
        let size = 44 * depth
        let groundY = ballTarget.map { $0.y < 0 ? position.y : layout.goal.maxY + 4 } ?? spot.y + size * 0.45
        return ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.4))
                .frame(width: size * 0.9, height: size * 0.22)
                .position(x: position.x, y: groundY)
            Image(systemName: "soccerball")
                .font(.system(size: size))
                .foregroundStyle(.black)
                .background(Circle().fill(.white).padding(size * 0.04))
                .rotationEffect(.degrees(ballSpin))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                .position(position)
        }
    }

    private func hud(_ layout: Layout, power livePower: Double) -> some View {
        ZStack {
            // Steps
            VStack {
                HStack(spacing: 8) {
                    step(L("penalty.step.direction"), index: 0)
                    step(L("penalty.step.height"), index: 1)
                    step(L("penalty.step.power"), index: 2)
                }
                .padding(.top, 54)
                Spacer()
            }
            // Power bar
            if phase == .power || phase == .shot || phase == .done {
                PowerBar(value: livePower)
                    .frame(width: 22, height: layout.size.height * 0.3)
                    .position(x: layout.size.width - 30, y: layout.spot.y - layout.size.height * 0.12)
            }
            // Text
            VStack(spacing: 8) {
                Spacer()
                if let outcome {
                    Text(outcome.title)
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(outcome == .goal ? Theme.goldLight : .white)
                        .shadow(color: .black.opacity(0.6), radius: 6)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                    Text(outcome == .goal
                         ? L("penalty.reward", Fmt.money(DailyRewards.penaltyReward))
                         : L("penalty.tomorrow"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L("penalty.tapToClose"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text(instruction)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L("penalty.hint"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 170),
                alignment: .bottom
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 20)
        }
        .allowsHitTesting(false)
    }

    private var instruction: String {
        switch phase {
        case .aimX: return L("penalty.aimDirection")
        case .aimY: return L("penalty.aimHeight")
        case .power: return L("penalty.aimPower")
        default: return " "
        }
    }

    private func step(_ title: String, index: Int) -> some View {
        let current = phase.rawValue
        let done = current > index
        let active = current == index
        return Text(title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(active ? Theme.goldDark : .white)
            .background(active ? Theme.gold : (done ? Theme.positive.opacity(0.8) : Color.black.opacity(0.45)), in: Capsule())
    }
}

// MARK: - Layout

private struct Layout {
    let size: CGSize
    let goal: CGRect
    let spot: CGPoint
    let horizon: CGFloat

    init(size: CGSize) {
        self.size = size
        let width = size.width * 0.8
        let height = width * 0.36
        horizon = size.height * 0.3
        goal = CGRect(x: (size.width - width) / 2, y: horizon - height + size.height * 0.03, width: width, height: height)
        spot = CGPoint(x: size.width / 2, y: size.height * 0.72)
    }

    /// Goal coordinates (x -1…1, y 0…1) to screen.
    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(x: goal.midX + CGFloat(x) * goal.width / 2, y: goal.maxY - CGFloat(y) * goal.height)
    }
}

// MARK: - Stadium

private struct Stadium: View {
    let layout: Layout
    let time: Double

    var body: some View {
        Canvas { context, size in
            let horizon = layout.goal.maxY
            // Night sky.
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Color(hex: "050B18"), Color(hex: "0E1E3A")]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))

            // Stands full of fans.
            let standsTop = size.height * 0.04
            let standsBottom = layout.goal.minY - 14
            let palette: [Color] = [Theme.gold, .white, Color(hex: "C8102E"), Color(hex: "1E6FB8"), Color(hex: "2E7D32"),
                                    Color(hex: "F2C9A0"), Color(hex: "8D5524"), Color(hex: "1A1A1A")]
            var row = 0
            var y = standsTop
            while y < standsBottom {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : 4
                var col = 0
                while x < size.width {
                    let seed = (row * 131 + col * 71) % 997
                    let color = palette[seed % palette.count]
                    let bob = sin(time * 3 + Double(seed)) * (seed % 5 == 0 ? 1.5 : 0.4)
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y + bob, width: 6, height: 6)),
                                 with: .color(color.opacity(0.55 + Double(seed % 4) * 0.1)))
                    x += 8
                    col += 1
                }
                y += 8
                row += 1
            }
            context.fill(Path(CGRect(x: 0, y: standsTop, width: size.width, height: standsBottom - standsTop)),
                         with: .linearGradient(Gradient(colors: [.black.opacity(0.55), .clear]),
                                               startPoint: CGPoint(x: 0, y: standsTop), endPoint: CGPoint(x: 0, y: standsBottom)))

            // Floodlights.
            for lightX in [size.width * 0.08, size.width * 0.92] {
                let center = CGPoint(x: lightX, y: size.height * 0.03)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 70, y: center.y - 70, width: 140, height: 140)),
                             with: .radialGradient(Gradient(colors: [.white.opacity(0.55), .white.opacity(0)]),
                                                   center: center, startRadius: 2, endRadius: 70))
            }

            // Advertising boards.
            let boardRect = CGRect(x: 0, y: standsBottom, width: size.width, height: 14)
            context.fill(Path(boardRect), with: .color(Color(hex: "0B1730")))
            var boardX: CGFloat = 6
            var flip = false
            while boardX < size.width {
                let text = Text(flip ? "KICKOFF MANAGER" : "SCOUT · TRANSFER · GLORY")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(flip ? Theme.gold : .white)
                context.draw(text, at: CGPoint(x: boardX, y: boardRect.midY), anchor: .leading)
                boardX += flip ? 110 : 150
                flip.toggle()
            }

            // Pitch with mowing stripes in perspective.
            let pitchTop = boardRect.maxY
            let stripes = 9
            for index in 0..<stripes {
                let t0 = CGFloat(index) / CGFloat(stripes)
                let t1 = CGFloat(index + 1) / CGFloat(stripes)
                let y0 = pitchTop + (size.height - pitchTop) * t0 * t0
                let y1 = pitchTop + (size.height - pitchTop) * t1 * t1
                let color = index.isMultiple(of: 2) ? Color(hex: "1C7A36") : Color(hex: "17692E")
                context.fill(Path(CGRect(x: 0, y: y0, width: size.width, height: y1 - y0 + 1)), with: .color(color))
            }

            // Box lines.
            let line = GraphicsContext.Shading.color(.white.opacity(0.75))
            var box = Path()
            let goalLineY = layout.goal.maxY
            box.move(to: CGPoint(x: -20, y: goalLineY))
            box.addLine(to: CGPoint(x: size.width + 20, y: goalLineY))
            let sixLeft = layout.goal.minX - 24, sixRight = layout.goal.maxX + 24
            let sixY = goalLineY + size.height * 0.06
            box.move(to: CGPoint(x: sixLeft, y: goalLineY))
            box.addLine(to: CGPoint(x: sixLeft - 10, y: sixY))
            box.addLine(to: CGPoint(x: sixRight + 10, y: sixY))
            box.addLine(to: CGPoint(x: sixRight, y: goalLineY))
            let bigY = layout.spot.y + size.height * 0.12
            box.move(to: CGPoint(x: size.width * 0.02, y: goalLineY))
            box.addLine(to: CGPoint(x: -size.width * 0.15, y: bigY))
            box.move(to: CGPoint(x: size.width * 0.98, y: goalLineY))
            box.addLine(to: CGPoint(x: size.width * 1.15, y: bigY))
            context.stroke(box, with: line, lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: layout.spot.x - 6, y: layout.spot.y + 14, width: 12, height: 5)),
                         with: .color(.white.opacity(0.9)))
        }
    }
}

private struct GoalFrame: View {
    let layout: Layout
    /// Where the ball hit the net (makes it bulge).
    let bulge: CGPoint?

    var body: some View {
        Canvas { context, _ in
            let rect = layout.goal
            let depth: CGFloat = 16
            let back = rect.insetBy(dx: depth, dy: 0).offsetBy(dx: 0, dy: -depth * 0.4)
            context.fill(Path(rect), with: .color(.black.opacity(0.25)))

            // Net grid, pushed back where the ball hit.
            var net = Path()
            let step: CGFloat = 11
            func bend(_ p: CGPoint) -> CGPoint {
                guard let bulge else { return p }
                let center = layout.point(x: bulge.x, y: bulge.y)
                let dx = p.x - center.x, dy = p.y - center.y
                let distance = (dx * dx + dy * dy).squareRoot()
                let push = max(0, 1 - distance / 70) * 10
                return CGPoint(x: p.x - dx / max(distance, 1) * push, y: p.y - dy / max(distance, 1) * push - push * 0.6)
            }
            var x = rect.minX
            while x <= rect.maxX {
                var y = rect.minY
                net.move(to: bend(CGPoint(x: x, y: y)))
                while y <= rect.maxY {
                    net.addLine(to: bend(CGPoint(x: x, y: y)))
                    y += 4
                }
                x += step
            }
            var y = rect.minY
            while y <= rect.maxY {
                var x = rect.minX
                net.move(to: bend(CGPoint(x: x, y: y)))
                while x <= rect.maxX {
                    net.addLine(to: bend(CGPoint(x: x, y: y)))
                    x += 4
                }
                y += step
            }
            context.stroke(net, with: .color(.white.opacity(0.28)), lineWidth: 0.8)

            // Side and back frame for depth.
            var frame = Path()
            frame.move(to: CGPoint(x: rect.minX, y: rect.minY))
            frame.addLine(to: CGPoint(x: back.minX, y: back.minY))
            frame.addLine(to: CGPoint(x: back.maxX, y: back.minY))
            frame.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            frame.move(to: CGPoint(x: back.minX, y: back.minY))
            frame.addLine(to: CGPoint(x: back.minX + 4, y: rect.maxY))
            frame.move(to: CGPoint(x: back.maxX, y: back.minY))
            frame.addLine(to: CGPoint(x: back.maxX - 4, y: rect.maxY))
            context.stroke(frame, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

            // Posts and crossbar.
            var posts = Path()
            posts.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            posts.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            posts.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            posts.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            context.stroke(posts, with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            context.stroke(posts, with: .color(.white), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}

private struct KeeperFigure: View {
    let height: CGFloat

    var body: some View {
        let unit = height / 10
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color(hex: "D9A27A"))
                Capsule().fill(Color(hex: "2B1B12")).frame(height: unit * 0.7).offset(y: -unit * 0.7)
            }
            .frame(width: unit * 2, height: unit * 2)
            ZStack(alignment: .top) {
                // Arms out, gloves on.
                HStack(spacing: unit * 2.6) {
                    glove(unit).rotationEffect(.degrees(-25))
                    glove(unit).rotationEffect(.degrees(25))
                }
                .offset(y: -unit * 0.4)
                Capsule().fill(Color(hex: "9BE15D")).frame(width: unit * 7.5, height: unit * 1.1)
                RoundedRectangle(cornerRadius: unit * 0.8)
                    .fill(LinearGradient(colors: [Color(hex: "B6F27A"), Color(hex: "6FB83A")], startPoint: .top, endPoint: .bottom))
                    .frame(width: unit * 3.4, height: unit * 3.4)
                    .overlay(Text("1").font(.system(size: unit * 1.8, weight: .black)).foregroundStyle(Color(hex: "1A1A1A")))
            }
            Rectangle().fill(Color(hex: "1A1A1A")).frame(width: unit * 3.2, height: unit * 1.2)
            HStack(spacing: unit * 0.5) {
                leg(unit)
                leg(unit)
            }
        }
    }

    private func glove(_ unit: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: unit * 0.5)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: unit * 0.5).stroke(Color(hex: "E57C00"), lineWidth: unit * 0.3))
            .frame(width: unit * 1.3, height: unit * 1.5)
    }

    private func leg(_ unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(hex: "D9A27A")).frame(width: unit * 0.9, height: unit * 0.6)
            Rectangle().fill(Color(hex: "9BE15D")).frame(width: unit * 1, height: unit * 1.3)
            Capsule().fill(Color.black).frame(width: unit * 1.4, height: unit * 0.6)
        }
    }
}

private struct PowerBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.black.opacity(0.5))
                // Sweet spot: strong enough to beat the keeper, not so hard it flies over.
                Rectangle()
                    .fill(Theme.positive.opacity(0.45))
                    .frame(height: geo.size.height * 0.15)
                    .offset(y: -geo.size.height * 0.7)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.positive, Theme.gold, Theme.negative],
                                         startPoint: .bottom, endPoint: .top))
                    .frame(height: max(6, geo.size.height * value))
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1.5))
        }
    }
}

private struct Confetti: View {
    let start: Date
    let now: Date
    let size: CGSize

    var body: some View {
        let elapsed = now.timeIntervalSince(start)
        Canvas { context, _ in
            guard elapsed < 3 else { return }
            let colors: [Color] = [Theme.gold, Theme.goldLight, .white, Theme.positive, Color(hex: "C8102E")]
            for index in 0..<90 {
                let seed = Double((index * 7919) % 1000) / 1000
                let seed2 = Double((index * 104_729) % 1000) / 1000
                let x = size.width * seed + sin(elapsed * 3 + seed * 10) * 18
                let y = -20 + elapsed * (180 + seed2 * 220) + elapsed * elapsed * 40
                let rect = CGRect(x: x, y: y, width: 6, height: 10)
                var piece = context
                piece.translateBy(x: rect.midX, y: rect.midY)
                piece.rotate(by: .radians(elapsed * (4 + seed * 6)))
                piece.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)),
                           with: .color(colors[index % colors.count].opacity(max(0, 1 - elapsed / 3))))
            }
        }
        .allowsHitTesting(false)
    }
}
