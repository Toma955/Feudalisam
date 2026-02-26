//
//  MapEnums.swift
//  Feudalism
//
//  Enum za mapu i enum za kreiranje mape – sve na jednom mjestu uz MapDimensions i MapCellEnums.
//

import Foundation

/// Tip mape (glavna površinska, podzemna, itd.).
enum MapKind: String, Codable, CaseIterable, Identifiable {
    case main = "main"
    case underground = "underground"

    var id: String { rawValue }
}

/// Faza / način kreiranja mape (nova, učitavanje, uređivanje).
enum MapCreationMode: String, Codable, CaseIterable, Identifiable {
    case new = "new"
    case load = "load"
    case edit = "edit"

    var id: String { rawValue }
}
