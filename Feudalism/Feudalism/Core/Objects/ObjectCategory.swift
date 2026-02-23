//
//  ObjectCategory.swift
//  Feudalism
//
//  Mapa objekata – kategorije u koje stavljamo sve objekte u igri.
//

import Foundation
import SwiftUI

/// Kategorije objekata u igri. Svaki objekt pripada jednoj kategoriji.
enum ObjectCategory: String, CaseIterable, Identifiable, Codable {
    case spremista = "Spremišta"
    case resursi = "Resursi"
    case hrana = "Hrana"
    case farme = "Farme"
    case vojska = "Vojska"
    case religija = "Religija"
    case dvorac = "Dvorac"
    case vojnici = "Vojnici"
    case radnici = "Radnici"
    case industrija = "Industrija"
    case ostali = "Ostali"

    var id: String { rawValue }

    /// Kratki identifikator za kod (npr. za spremanje).
    var key: String {
        switch self {
        case .spremista: return "spremista"
        case .resursi: return "resursi"
        case .hrana: return "hrana"
        case .farme: return "farme"
        case .vojska: return "vojska"
        case .religija: return "religija"
        case .dvorac: return "dvorac"
        case .vojnici: return "vojnici"
        case .radnici: return "radnici"
        case .industrija: return "industrija"
        case .ostali: return "ostali"
        }
    }

    /// Boja za UI (izbornici, ikone).
    var accentColor: Color {
        switch self {
        case .spremista: return .brown
        case .resursi: return .orange
        case .hrana: return .green
        case .farme: return Color(red: 0.4, green: 0.7, blue: 0.3)
        case .vojska: return .red
        case .religija: return .purple
        case .dvorac: return .gray
        case .vojnici: return Color(red: 0.6, green: 0.2, blue: 0.2)
        case .radnici: return .blue
        case .industrija: return Color(red: 0.5, green: 0.45, blue: 0.35)
        case .ostali: return .secondary
        }
    }
}
