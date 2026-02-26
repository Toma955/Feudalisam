//
//  SpatialUnit10.swift
//  Feudalism
//
//  Najmanja prostorna jedinica na mapi: 10×10 world jedinica.
//  Sve mape su kockaste i građene od ovih jedinica (npr. 200×200 = 200 jedinica po strani).
//

import Foundation
import CoreGraphics

/// Jedna minimalna prostorna jedinica (10×10 world jedinica).
/// Mapa se gradi od ovih jedinica; pravilo za gradnju je 40×40 (4×4 ovih jedinica).
/// Svaka jedinica: id, x, y, textureId, objectIds, elevation (može u minus), walkable, buildable, canAfforest, canDigChannels (v. MapScale).
struct SpatialUnit10: Identifiable, Hashable, Codable, Sendable {
    /// Jedinstveni id (npr. "x_y" za indekse u mreži).
    var id: String { "\(x)_\(y)" }

    /// Koordinata x (stupac u mreži minimalnih jedinica, 0..<side).
    let x: Int
    /// Koordinata y (red u mreži minimalnih jedinica, 0..<side).
    let y: Int
    /// ID teksture (jedna po polju).
    var textureId: String = "grass"
    /// ID objekata na polju (više po polju: npr. žbunje, stabla, voda).
    var objectIds: [String] = []
    /// Elevacija – može ići u minus.
    var elevation: CGFloat = 0
    /// Može li se preći (hodati).
    var walkable: Bool = true
    /// Može li se graditi.
    var buildable: Bool = true
    /// Može li se pošumljavati.
    var canAfforest: Bool = false
    /// Može li se kopati kanal (kupanje kanala).
    var canDigChannels: Bool = false

    init(x: Int, y: Int, textureId: String = "grass", objectIds: [String] = [], elevation: CGFloat = 0, walkable: Bool = true, buildable: Bool = true, canAfforest: Bool = false, canDigChannels: Bool = false) {
        self.x = x
        self.y = y
        self.textureId = textureId
        self.objectIds = objectIds
        self.elevation = elevation
        self.walkable = walkable
        self.buildable = buildable
        self.canAfforest = canAfforest
        self.canDigChannels = canDigChannels
    }

    enum CodingKeys: String, CodingKey { case x, y, textureId, objectIds, elevation, walkable, buildable, canAfforest, canDigChannels }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Int.self, forKey: .x)
        y = try c.decode(Int.self, forKey: .y)
        textureId = try c.decodeIfPresent(String.self, forKey: .textureId) ?? "grass"
        objectIds = try c.decodeIfPresent([String].self, forKey: .objectIds) ?? []
        elevation = CGFloat(try c.decodeIfPresent(Double.self, forKey: .elevation) ?? 0)
        walkable = try c.decodeIfPresent(Bool.self, forKey: .walkable) ?? true
        buildable = try c.decodeIfPresent(Bool.self, forKey: .buildable) ?? true
        canAfforest = try c.decodeIfPresent(Bool.self, forKey: .canAfforest) ?? false
        canDigChannels = try c.decodeIfPresent(Bool.self, forKey: .canDigChannels) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(textureId, forKey: .textureId)
        try c.encode(objectIds, forKey: .objectIds)
        try c.encode(Double(elevation), forKey: .elevation)
        try c.encode(walkable, forKey: .walkable)
        try c.encode(buildable, forKey: .buildable)
        try c.encode(canAfforest, forKey: .canAfforest)
        try c.encode(canDigChannels, forKey: .canDigChannels)
    }

    /// World koordinata X sredine ove jedinice (relativno na ishodište 0,0 – MapScale.mapOriginWorldX/Z).
    func worldCenterX(side: Int) -> CGFloat {
        let halfW = CGFloat(side) * MapScale.smallSpatialUnitWorldUnits / 2
        return MapScale.mapOriginWorldX + CGFloat(x) * MapScale.smallSpatialUnitWorldUnits - halfW + MapScale.smallSpatialUnitWorldUnits / 2
    }

    /// World koordinata Z sredine ove jedinice (relativno na ishodište 0,0).
    func worldCenterZ(side: Int) -> CGFloat {
        let halfH = CGFloat(side) * MapScale.smallSpatialUnitWorldUnits / 2
        return MapScale.mapOriginWorldZ + CGFloat(y) * MapScale.smallSpatialUnitWorldUnits - halfH + MapScale.smallSpatialUnitWorldUnits / 2
    }

    /// Indeks u gradbenoj ćeliji (0..<4) za x smjer. placementCol = x / 4.
    var placementCol: Int { x / MapScale.smallCellsPerObjectCubeSide }
    /// Indeks u gradbenoj ćeliji (0..<4) za y smjer. placementRow = y / 4.
    var placementRow: Int { y / MapScale.smallCellsPerObjectCubeSide }
}
