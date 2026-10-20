import Foundation
import SwiftUI
import GameEngine

/// Localized string from Localizable.strings.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Localized format string. Use %@ placeholders in the .strings files.
func L(_ key: String, _ arguments: String...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
}

enum Fmt {
    /// €42.5M, €850K, €900
    static func money(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        let amount = abs(Double(value))
        if amount >= 1_000_000 {
            let millions = amount / 1_000_000
            let text = millions >= 100 ? String(format: "%.0f", millions) : String(format: "%.1f", millions)
            return "\(sign)€\(text)M"
        }
        if amount >= 1_000 {
            return "\(sign)€\(Int((amount / 1_000).rounded()))K"
        }
        return "\(sign)€\(Int(amount))"
    }

    static func wage(_ value: Int) -> String {
        L("format.wage", money(value))
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func rating(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func seasonLabel(_ season: Int) -> String {
        "\(season)/\(String(season + 1).suffix(2))"
    }
}

extension Position {
    var shortLabel: String { L("pos.\(rawValue)") }
    var longLabel: String { L("pos.long.\(rawValue)") }
}

extension FacilityKind {
    var label: String { L("facility.\(rawValue)") }
    var detail: String { L("facility.\(rawValue).detail") }
    var icon: String {
        switch self {
        case .training: return "figure.run"
        case .youth: return "graduationcap.fill"
        case .medical: return "cross.case.fill"
        case .stadium: return "building.columns.fill"
        }
    }
}

extension AttributeKind {
    var label: String { L("attr.\(rawValue)") }
    /// Three-letter label used on player cards.
    var shortLabel: String { L("attr.short.\(rawValue)") }
}

extension CompetitionKind {
    var label: String { L("cup.\(rawValue)") }
    var icon: String { self == .eliteCup ? "trophy.fill" : "star.circle.fill" }
    var color: Color { self == .eliteCup ? Theme.elite : Theme.continental }
}

extension CupStage {
    var key: String {
        switch self {
        case .group: return "group"
        case .quarterFinal: return "quarterFinal"
        case .semiFinal: return "semiFinal"
        case .final: return "final"
        case .winner: return "winner"
        }
    }

    var label: String { L("stage.\(key)") }
}

extension CupFixture {
    /// "Group · matchday 3", "Quarter-final · 1st leg", "Final".
    var stageCaption: String {
        switch stage {
        case .group: return L("stage.groupMatch", String(leg))
        case .final, .winner: return CupStage.final.label
        case .quarterFinal, .semiFinal: return L("stage.leg", stage.label, String(leg))
        }
    }
}

enum Flags {
    static func emoji(_ code: String) -> String {
        switch code {
        case "EN": return "🏴󠁧󠁢󠁥󠁮󠁧󠁿"
        default:
            let base: UInt32 = 127397
            return code.uppercased().unicodeScalars
                .compactMap { UnicodeScalar(base + $0.value) }
                .map { String($0) }
                .joined()
        }
    }

    static func countryName(_ code: String) -> String { L("country.\(code)") }
}
