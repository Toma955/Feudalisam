//
//  GameSituationSnapshot.swift
//  Feudalism
//
//  Realna situacija u igri – ono što se stvarno dešava. Koristi se da AI:
//  - reagira na trenutno stanje,
//  - predvida budućnost,
//  - ima osnovne postavke (profil) i prema njima se ponaša.
//
//  Igra je isključivo za treniranje i ograđivanje modela. Python koristi isti
//  format (JSON) za treniranje; Swift koristi za inferencu u igri.
//

import Foundation

/// Snapshot realne situacije u igri – serijalizabilan (JSON) za Swift inferencu i Python treniranje.
struct GameSituationSnapshot: Codable {
    /// Potez / vrijeme u igri.
    var turn: Int
    /// Veličina mape (rows × cols).
    var mapRows: Int
    var mapCols: Int
    /// Krajevi – stanje svakog (defeated, resursi kad dodamo po-realm).
    var realms: [RealmSnapshot]
    /// Postavljeni objekti na karti (koji realm, gdje, što).
    var placements: [PlacementSnapshot]
    /// Id realm-a koji „gleda” situaciju (AI lord za kojeg donosimo odluku).
    var actingRealmId: String
    /// Opcionalno: kratki digest terena (npr. broj ćelija po tipu) – za manji input u model.
    var terrainSummary: TerrainSummary?
}

struct RealmSnapshot: Codable {
    var id: String
    var name: String
    var isDefeated: Bool
    var lordType: String
    var aiProfileId: String?
    var groupId: String?
}

struct PlacementSnapshot: Codable {
    var id: String
    var objectId: String
    var row: Int
    var col: Int
    var width: Int
    var height: Int
    /// Kad dodamo vlasništvo: koji realm posjeduje (realmId).
    var realmId: String?
}

struct TerrainSummary: Codable {
    var grass: Int
    var water: Int
    var forest: Int
    var mountain: Int
}

// MARK: - Iz živog GameState / GameMap

extension GameSituationSnapshot {
    /// Napravi snapshot realne situacije iz trenutnog stanja igre – za AI reakciju i predikciju.
    static func from(gameState: GameState, actingRealmId: String) -> GameSituationSnapshot {
        let realms = gameState.realms.map { r in
            RealmSnapshot(
                id: r.id,
                name: r.name,
                isDefeated: r.isDefeated,
                lordType: r.lordType.rawValue,
                aiProfileId: r.aiProfileId,
                groupId: r.groupId
            )
        }
        let placements = gameState.gameMap.placements.map { p in
            PlacementSnapshot(
                id: p.id,
                objectId: p.objectId,
                row: p.row,
                col: p.col,
                width: p.width,
                height: p.height,
                realmId: nil
            )
        }
        var terrainSummary: TerrainSummary?
        let cells = gameState.gameMap.cells
        if !cells.isEmpty {
            var g = 0, w = 0, f = 0, m = 0
            for (_, cell) in cells {
                switch cell.terrain {
                case .grass: g += 1
                case .water: w += 1
                case .forest: f += 1
                case .mountain: m += 1
                }
            }
            terrainSummary = TerrainSummary(grass: g, water: w, forest: f, mountain: m)
        }
        return GameSituationSnapshot(
            turn: gameState.currentTurn,
            mapRows: gameState.gameMap.rows,
            mapCols: gameState.gameMap.cols,
            realms: realms,
            placements: placements,
            actingRealmId: actingRealmId,
            terrainSummary: terrainSummary
        )
    }

    /// JSON za Python (treniranje) ili log – isti format kao u igri.
    func toJSONData() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
