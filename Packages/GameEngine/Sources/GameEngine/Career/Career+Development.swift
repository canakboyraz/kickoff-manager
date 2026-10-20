import Foundation

extension Career {
    /// Runs every 4 matchdays. Young players with room to grow improve, veterans decline.
    /// Better training facilities and regular playing time speed up growth.
    mutating func developmentTick() {
        for id in Array(players.keys) {
            guard var player = players[id], player.clubID != nil else { continue }
            let trainingLevel = player.clubID.flatMap { clubs[$0]?.facilities.training } ?? 3
            let age = player.age(in: season)

            var change: Double
            switch age {
            case ...20: change = 2.0
            case 21...23: change = 1.4
            case 24...27: change = 0.5
            case 28...30: change = 0
            case 31...32: change = -0.8
            default: change = -1.3
            }

            if change > 0 {
                let gap = Double(player.potential - player.overall)
                change = gap <= 0 ? 0 : change * min(1.2, gap / 8 + 0.2)
                let training = 0.7 + Double(trainingLevel) * 0.06
                let playingTime = 0.55 + 0.45 * min(1, Double(player.appearancesSinceTick) / 3)
                change *= training * playingTime
            } else if change < 0 {
                change *= 1.05 - Double(trainingLevel) * 0.02
            }

            player.developmentProgress += change + rng.normal(sd: 0.25)

            while player.developmentProgress >= 1 {
                player.developmentProgress -= 1
                guard player.overall < player.potential else {
                    player.developmentProgress = 0
                    break
                }
                improve(&player)
            }
            while player.developmentProgress <= -1 {
                player.developmentProgress += 1
                decline(&player)
            }

            player.appearancesSinceTick = 0
            players[id] = player
        }
    }

    /// Raises one attribute that matters for the player's position.
    mutating func improve(_ player: inout Player) {
        let weights = Attributes.weights(for: player.position)
        let kinds = Array(weights.keys).sorted { $0.rawValue < $1.rawValue }
        guard let index = rng.weightedIndex(kinds.map { weights[$0] ?? 0 }) else { return }
        player.attributes[kinds[index]] += 1
    }

    /// Lowers one attribute; physical attributes fade first.
    mutating func decline(_ player: inout Player) {
        var kinds: [AttributeKind] = [.pace, .physical, .shooting, .passing, .dribbling, .defending]
        var weights: [Double] = [3, 3, 1, 1, 1, 1]
        if player.position == .goalkeeper {
            kinds.append(.goalkeeping)
            weights.append(2)
        }
        guard let index = rng.weightedIndex(weights) else { return }
        player.attributes[kinds[index]] -= 1
    }
}
