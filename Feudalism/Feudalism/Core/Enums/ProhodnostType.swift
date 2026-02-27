//
//  ProhodnostType.swift
//  Feudalism
//
//  Prohodnost ćelije – koliko se brzo može kretati kroz područje. Označeno slovima.
//

import Foundation

/// Prohodnost ćelije: brzina kretanja kroz područje. Slovo = kratka oznaka.
enum ProhodnostType: String, Codable, CaseIterable, Identifiable {
    case neprohodno = "N"   // 0 – ne može se proći
    case vrloSporo = "V"    // vrlo sporo
    case sporo = "S"
    case normalno = "G"     // normalna brzina (default)
    case brzo = "B"

    var id: String { rawValue }

    /// Oznaka slovom (N, V, S, G, B).
    var letterCode: String { rawValue }

    /// Multiplikator brzine kretanja (0 = neprohodno, inače 1).
    var speedMultiplier: Double {
        switch self {
        case .neprohodno: return 0
        case .vrloSporo, .sporo, .normalno, .brzo: return 1
        }
    }

    /// Je li područje uopće prohodno?
    var isPassable: Bool { speedMultiplier > 0 }

    /// Ime za prikaz u UI.
    var displayName: String {
        switch self {
        case .neprohodno: return "Neprohodno"
        case .vrloSporo: return "Vrlo sporo"
        case .sporo: return "Sporo"
        case .normalno: return "Normalno"
        case .brzo: return "Brzo"
        }
    }

    /// Zadana prohodnost pri kreiranju nove ćelije (G = normalno).
    static var `default`: ProhodnostType { .normalno }
}
