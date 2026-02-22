//
//  SpatialSize.swift
//  Feudalism
//
//  Prostorna veličina u jedinicama mape. Najmanja jedinica je 1×1; sve ostalo je višekratnik.
//

import Foundation

/// Veličina u prostornim jedinicama. **Najmanja jedinica je 1×1** – od toga kreće sve ostalo (kuća 4×4, mapa 100×100, …).
struct SpatialSize: Hashable, Codable, Sendable {
    /// Širina u jedinicama (min 1).
    var width: Int
    /// Visina u jedinicama (min 1).
    var height: Int

    init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    /// Najmanja prostorna veličina: 1×1.
    static let oneByOne = SpatialSize(width: 1, height: 1)

    /// Broj ćelija koje ova veličina pokriva (npr. 4×4 = 16).
    var cellCount: Int { width * height }

    /// Je li ova veličina 1×1?
    var isMinimal: Bool { width == 1 && height == 1 }
}
