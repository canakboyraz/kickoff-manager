import Foundation

enum Scheduler {
    /// Double round robin (circle method). Every club plays every other club home and away.
    /// Matchdays are numbered from 1.
    static func doubleRoundRobin(clubIDs: [UUID], rng: inout SeededRandom) -> [Fixture] {
        var teams: [UUID?] = clubIDs.shuffled(using: &rng).map { Optional($0) }
        if teams.count % 2 == 1 { teams.append(nil) }
        let count = teams.count
        guard count >= 2 else { return [] }
        let rounds = count - 1

        var firstHalf: [Fixture] = []
        for round in 0..<rounds {
            for index in 0..<(count / 2) {
                guard let a = teams[index], let b = teams[count - 1 - index] else { continue }
                // Alternate home advantage so clubs don't get long home or away runs.
                let aIsHome = index == 0 ? round % 2 == 0 : (round + index) % 2 == 0
                firstHalf.append(Fixture(
                    id: UUID(),
                    matchday: round + 1,
                    homeID: aIsHome ? a : b,
                    awayID: aIsHome ? b : a,
                    result: nil
                ))
            }
            // Rotate every team except the first.
            let last = teams.removeLast()
            teams.insert(last, at: 1)
        }

        let secondHalf = firstHalf.map {
            Fixture(id: UUID(), matchday: $0.matchday + rounds, homeID: $0.awayID, awayID: $0.homeID, result: nil)
        }
        return firstHalf + secondHalf
    }
}
