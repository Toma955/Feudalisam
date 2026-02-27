//
//  MapCell.swift
//  Feudalism
//
//  Jedna ćelija mape (40×40): textureId (jedna), objectIds (više), elevation (može u minus),
//  walkable, buildable, canAfforest, canDigChannels. Zauzetost građevinama iz Placement-a.
//

import Foundation

/// Jedna ćelija mape (1×1 u gridu za gradnju) – runtime podaci u datoteci:
/// id, x/y, textureId, objectIds, terrain, height (elevacija; može u minus), resource,
/// walkable, buildable, canAfforest, canDigChannels, površina (G=zemlja), prohodnost.
struct MapCell: Identifiable, Codable {
    var id: String { coordinate.cellId }
    let coordinate: MapCoordinate
    /// ID teksture (jedna po polju).
    var textureId: String = "grass"
    /// ID objekata na polju (više: npr. žbunje, stabla, voda).
    var objectIds: [String] = []
    var terrain: TerrainType
    /// Elevacija – može ići u minus.
    var height: CGFloat = 0
    /// Resurs na ćeliji (npr. naslaga kamena); nil = nema resursa.
    var resource: ResourceType? = nil
    /// Može li se hodati.
    var walkable: Bool = true
    /// Može li se graditi.
    var buildable: Bool = true
    /// Može li se pošumljavati.
    var canAfforest: Bool = false
    /// Može li se kopati kanal (kupanje kanala).
    var canDigChannels: Bool = false
    /// Tip površine (G=zemlja, W=voda, P=ravnica, …). Default G.
    var povrsina: PovrsinaType = .zemlja
    /// Prohodnost – koliko brzo se može kretati (N, V, S, G, B). Default G = normalno.
    var prohodnost: ProhodnostType = .normalno

    /// Pojedinačne točke (vrhovi) kocke – 4 kuta ćelije, svaka s vlastitom koordinatom. Izvedeno iz generalne koordinate.
    var points: [MapCellPoint] {
        let r = Double(coordinate.row)
        let c = Double(coordinate.col)
        return [
            MapCellPoint(row: r, col: c, index: 0),       // gornji lijevi
            MapCellPoint(row: r, col: c + 1, index: 1),    // gornji desni
            MapCellPoint(row: r + 1, col: c, index: 2),   // donji lijevi
            MapCellPoint(row: r + 1, col: c + 1, index: 3) // donji desni
        ]
    }

    init(coordinate: MapCoordinate, textureId: String = "grass", objectIds: [String] = [], terrain: TerrainType = .grass, height: CGFloat = 0, resource: ResourceType? = nil, walkable: Bool? = nil, buildable: Bool? = nil, canAfforest: Bool = false, canDigChannels: Bool = false, povrsina: PovrsinaType = .zemlja, prohodnost: ProhodnostType = .normalno) {
        self.coordinate = coordinate
        self.textureId = textureId
        self.objectIds = objectIds
        self.terrain = terrain
        self.height = height
        self.resource = resource
        self.walkable = walkable ?? terrain.defaultWalkable
        self.buildable = buildable ?? terrain.defaultBuildable
        self.canAfforest = canAfforest
        self.canDigChannels = canDigChannels
        self.povrsina = povrsina
        self.prohodnost = prohodnost
    }

    enum CodingKeys: String, CodingKey {
        case coordinate, textureId, objectIds, terrain, height, resource, walkable, buildable, canAfforest, canDigChannels, povrsina, prohodnost
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coordinate = try c.decode(MapCoordinate.self, forKey: .coordinate)
        textureId = try c.decodeIfPresent(String.self, forKey: .textureId) ?? "grass"
        objectIds = try c.decodeIfPresent([String].self, forKey: .objectIds) ?? []
        terrain = try c.decode(TerrainType.self, forKey: .terrain)
        let h = try c.decodeIfPresent(Double.self, forKey: .height) ?? 0
        height = CGFloat(h)
        resource = try c.decodeIfPresent(ResourceType.self, forKey: .resource)
        walkable = try c.decodeIfPresent(Bool.self, forKey: .walkable) ?? terrain.defaultWalkable
        buildable = try c.decodeIfPresent(Bool.self, forKey: .buildable) ?? terrain.defaultBuildable
        canAfforest = try c.decodeIfPresent(Bool.self, forKey: .canAfforest) ?? false
        canDigChannels = try c.decodeIfPresent(Bool.self, forKey: .canDigChannels) ?? false
        povrsina = try c.decodeIfPresent(PovrsinaType.self, forKey: .povrsina) ?? .zemlja
        prohodnost = try c.decodeIfPresent(ProhodnostType.self, forKey: .prohodnost) ?? .normalno
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(coordinate, forKey: .coordinate)
        try c.encode(textureId, forKey: .textureId)
        try c.encode(objectIds, forKey: .objectIds)
        try c.encode(terrain, forKey: .terrain)
        try c.encode(Double(height), forKey: .height)
        try c.encodeIfPresent(resource, forKey: .resource)
        try c.encode(walkable, forKey: .walkable)
        try c.encode(buildable, forKey: .buildable)
        try c.encode(canAfforest, forKey: .canAfforest)
        try c.encode(canDigChannels, forKey: .canDigChannels)
        try c.encode(povrsina, forKey: .povrsina)
        try c.encode(prohodnost, forKey: .prohodnost)
    }
}
