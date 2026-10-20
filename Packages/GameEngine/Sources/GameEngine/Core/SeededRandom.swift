import Foundation

/// Deterministic random generator (SplitMix64). Stored inside the save file,
/// so a loaded career continues with the same random sequence.
public struct SeededRandom: RandomNumberGenerator, Codable, Hashable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    public mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    public mutating func double(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }

    public mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    /// Box–Muller normal distribution.
    public mutating func normal(mean: Double = 0, sd: Double = 1) -> Double {
        let u1 = max(unit(), 1e-12)
        let u2 = unit()
        return mean + sd * (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }

    /// Knuth's Poisson sampler; fine for the small lambdas used for goals.
    public mutating func poisson(_ lambda: Double) -> Int {
        let limit = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= unit()
        } while p > limit
        return k - 1
    }

    /// Picks an index proportionally to the given non-negative weights.
    public mutating func weightedIndex(_ weights: [Double]) -> Int? {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return nil }
        var roll = unit() * total
        for (index, weight) in weights.enumerated() {
            roll -= max(0, weight)
            if roll < 0 { return index }
        }
        return weights.indices.last
    }

    public mutating func pick<T>(_ items: [T]) -> T {
        items[Int.random(in: 0..<items.count, using: &self)]
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
