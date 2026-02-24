//
//  WallBuildConditions.swift
//  Feudalism
//
//  Uvjeti za gradnju zida: resursi, nema objekata na putu, neprijatelj nije u zoni, teren dozvoljava.
//  Ako svi vraćaju true, zid se može graditi; inače ghost ide u crvenu i gradnja je onemogućena.
//

import Foundation

/// Uvjeti za postavljanje zida. Svaka funkcija vraća true kad je uvjet zadovoljen.
enum WallBuildConditions {

    /// Resursi dozvoljavaju gradnju (ima dovoljno kamena, drva, željeza za odabrani zid).
    static func resourcesAllow(gameState: GameState, objectId: String) -> Bool {
        // U ovoj fazi uvijek dozvoli; kasnije: gameState.resources.canAfford(objectId: objectId)
        return true
    }

    /// Nema objekata na putu (ćelije za zid su prazne).
    static func noObjectsInTheWay(gameState: GameState, objectId: String, cells: [(Int, Int)]) -> Bool {
        // U ovoj fazi uvijek dozvoli; kasnije: provjera gameMap.placements preko cells
        return true
    }

    /// Neprijatelj nije u zoni djelovanja (gradnja dopuštena u zoni).
    static func enemyNotInZone(gameState: GameState, objectId: String, cells: [(Int, Int)]) -> Bool {
        // U ovoj fazi uvijek dozvoli; kasnije: provjera neprijateljskih jedinica/realmova u zoni
        return true
    }

    /// Teren dozvoljava gradnju (npr. nije voda, strmo itd.).
    static func terrainAllows(gameState: GameState, objectId: String, cells: [(Int, Int)]) -> Bool {
        // U ovoj fazi uvijek dozvoli; kasnije: provjera tipa terena za svaku ćeliju
        return true
    }

    /// Svi uvjeti zadovoljeni – tek tada se zid može graditi. Ako netko vrati false, ghost ide u crvenu i gradnja se onemogućuje.
    static func wallBuildConditionsMet(gameState: GameState, objectId: String, cells: [(Int, Int)]) -> Bool {
        guard WallParent.isWall(objectId: objectId) else { return true }
        return resourcesAllow(gameState: gameState, objectId: objectId)
            && noObjectsInTheWay(gameState: gameState, objectId: objectId, cells: cells)
            && enemyNotInZone(gameState: gameState, objectId: objectId, cells: cells)
            && terrainAllows(gameState: gameState, objectId: objectId, cells: cells)
    }
}
