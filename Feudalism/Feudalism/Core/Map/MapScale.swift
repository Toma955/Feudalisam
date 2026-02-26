//
//  MapScale.swift
//  Feudalism
//
//  Jedan izvor istine za prostor na mapi:
//  - Najmanja prostorna jedinica je 10×10 world jedinica (SpatialUnit10).
//  - Sve mape su kockaste i građene od tih jedinica: 200×200 = 200 jedinica po strani.
//  - Pravilo za gradnju: 1 ćelija za postavljanje = 40×40 = 4×4 minimalnih jedinica.
//  - Mreže 10×10 i 40×40 u Map Editoru su samo pravila prikaza (koja mreža se crta).
//
//  Što svaka minimalna prostorna jedinica (10×10) mora imati (nepromjenjivo):
//  - id, x (koordinata), y (koordinata)
//  - textureId (ID teksture – jedna po polju)
//  - objectIds (ID objekata – više po polju; npr. zelena polja: žbunje, stabla; može biti voda)
//  - elevation (elevacija; može ići u minus)
//  - walkable (Bool: hodanje), buildable (Bool: građenje objekata), canAfforest (Bool: pošumljavanje), canDigChannels (Bool: kupanje kanala)
//
//  Na mapi mora postojati točka 0.0, 0.0 (world x, y) kao ishodište za pozicioniranje mreža (10×10, 40×40) i sadržaja.
//

import Foundation
import CoreGraphics

/// Pravila prostora i dimenzija – minimalna jedinica 10×10, od nje se rade sve mape.
enum MapScale {
    // MARK: - Ishodište mape (0, 0)
    /// World X ishodišta mape – uvijek 0.0; mreže i sadržaj pozicioniraju se relativno na to.
    static let mapOriginWorldX: CGFloat = 0
    /// World Z ishodišta mape (y u ravnini XZ) – uvijek 0.0; mreže i sadržaj pozicioniraju se relativno na to.
    static let mapOriginWorldZ: CGFloat = 0

    // MARK: - Najmanja prostorna jedinica (izvor svega)
    /// Najmanja prostorna jedinica na mapi: 10×10 world jedinica. Sve mape su višekratnici ove jedinice.
    static let smallSpatialUnitWorldUnits: CGFloat = 10

    /// Koliko minimalnih jedinica (10×10) čini jednu stranu ćelije za gradnju (40×40). 4×4 = 16 jedinica po ćeliji.
    static let smallCellsPerObjectCubeSide: Int = 4

    /// Pravilo za gradnju: 1 logička ćelija (postavljanje, zid) = 40×40 world = 4×4 minimalnih jedinica.
    static var objectCubeWorldUnits: CGFloat {
        smallSpatialUnitWorldUnits * CGFloat(smallCellsPerObjectCubeSide)
    }

    /// 10 prostornih kocki čini jedinicu dimenzije mape (mapa side = broj minimalnih jedinica po strani).
    static let objectCubesPerMapDimensionUnit: Int = 10

    // MARK: - Izvedene veličine (ćelija = 40×40, ne 10×10)
    /// 1 logička ćelija mape (za gradnju) = 40×40 world jedinica. Preset 200×200 = 200×200 takvih ćelija.
    static var worldUnitsPerMapCell: CGFloat { objectCubeWorldUnits }

    /// Broj minimalnih jedinica po strani za dani preset (200, 400, …). To je „side” u MapDimension.
    static func smallUnitsPerSide(presetSide side: Int) -> Int { side }

    /// Broj ćelija za gradnju (40×40) po strani kad mapa ima side minimalnih jedinica. 200 → 50.
    static func placementCellsPerSide(smallUnitsPerSide side: Int) -> Int {
        side / smallCellsPerObjectCubeSide
    }

    /// World širina mape kad ima side minimalnih jedinica po strani: side × 10.
    static func worldWidth(smallUnitsPerSide side: Int) -> CGFloat {
        CGFloat(side) * smallSpatialUnitWorldUnits
    }

    /// World širina mape: cols ćelija × 40 world jedinica po ćeliji (ne 10).
    static func worldWidth(cols: Int) -> CGFloat {
        CGFloat(cols) * worldUnitsPerMapCell
    }

    /// World visina mape: rows ćelija × 40 world jedinica po ćeliji (ne 10).
    static func worldHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * worldUnitsPerMapCell
    }

    // MARK: - Dimenzija mape (uvijek kockasta) – izvor: Core/Enums/MapDimensions.swift
    /// Dozvoljene strane mape u minimalnim jedinicama: 200, 400, 600, 800, 1000 (broj 10×10 jedinica po strani).
    static var allowedMapSides: [Int] { MapDimension.allSides }

    /// Je li zadani side valjan (kockasta mapa).
    static func isValidMapSide(_ side: Int) -> Bool {
        MapDimension.isValid(side)
    }
}

// MARK: - Generator mape (nova mapa; delegira MapFileManageru)
enum MapGenerator {
    /// Kreira prvu (praznu) mapu i file preko MapFileManager.createMapFile.
    static func createAndSaveMap(name: String, side: Int, slot: MapEditorSlot = .solo) -> GameMap? {
        MapFileManager.createMapFile(name: name, side: side, slot: slot)
    }

    /// Kreira prvu mapu s enumom dimenzije (npr. .size200 → 200×200). Isto što createAndSaveMap(name:side:slot:) s dimension.side.
    static func createAndSaveMap(name: String, dimension: MapDimension, slot: MapEditorSlot = .solo) -> GameMap? {
        createAndSaveMap(name: name, side: dimension.side, slot: slot)
    }
}
