//
//  PovrsinaType.swift
//  Feudalism
//
//  Tip površine ćelije mape – označen slovom (G, W, P, D, …). Default G = zemlja.
//

import Foundation

/// Tip površine jedne ćelije (zemlja, voda, ravnica, pustinja, …). Slovo = kratka oznaka za serializaciju/UI.
enum PovrsinaType: String, Codable, CaseIterable, Identifiable {
    case zemlja = "G"   // obična zemlja (default)
    case voda = "W"
    case ravnica = "P"
    case pustinja = "D"
    case suma = "F"     // šuma
    case stijena = "S"

    var id: String { rawValue }

    /// Jednoslovna ili dvoslovna oznaka (G, W, P, D, F, S).
    var letterCode: String { rawValue }

    /// Ime za prikaz u UI.
    var displayName: String {
        switch self {
        case .zemlja: return "Zemlja"
        case .voda: return "Voda"
        case .ravnica: return "Ravnica"
        case .pustinja: return "Pustinja"
        case .suma: return "Šuma"
        case .stijena: return "Stijena"
        }
    }

    /// Zadana površina pri kreiranju nove ćelije (G = zemlja).
    static var `default`: PovrsinaType { .zemlja }
}
