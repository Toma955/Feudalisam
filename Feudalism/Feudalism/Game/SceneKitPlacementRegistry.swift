//
//  SceneKitPlacementRegistry.swift
//  Feudalism
//
//  Jedan izvor istine za prikaz objekata na 3D karti: učitavanje modela i ponovna primjena teksture po objectId.
//  Uklanja dupli kod iz SceneKitMapView (12× template/ghost/refresh/ghost visibility).
//

import Foundation
import SceneKit
import AppKit

/// Konfiguracija jednog tipa objekta za prikaz na karti: veličina u ćelijama i opcionalni Y offset (npr. mlina).
struct SceneKitPlacementConfig {
    let objectId: String
    let cellW: Int
    let cellH: Int
    /// Dodatni Y pomak u world jedinicama (npr. Windmill +8).
    let yOffset: CGFloat
}

/// Registry objekata koji imaju 3D model na karti. Koristi PlaceableSceneKitObject protokol – jedan izvor tipova.
enum SceneKitPlacementRegistry {
    /// Svi objectId-evi koji se mogu postaviti na mapu s 3D modelom (iz PlaceableSceneKitTypes).
    static let placeableObjectIds: [String] = PlaceableSceneKitTypes.all.map { $0.objectId }

    /// Konfiguracija (cellW, cellH, yOffset) po objectId. Koristi ObjectCatalog za veličinu; yOffset samo za iznimke.
    static func config(for objectId: String) -> SceneKitPlacementConfig? {
        guard let obj = ObjectCatalog.shared.object(id: objectId) else { return nil }
        let w = max(1, obj.size.width)
        let h = max(1, obj.size.height)
        let yOffset: CGFloat = objectId == Windmill.objectId ? 8 : 0
        return SceneKitPlacementConfig(objectId: objectId, cellW: w, cellH: h, yOffset: yOffset)
    }

    /// Svi configi za placeableObjectIds (samo oni s validnim objektom u katalogu).
    static var allConfigs: [SceneKitPlacementConfig] {
        placeableObjectIds.compactMap { config(for: $0) }
    }

    /// Učita 3D čvor za dani objectId. Vraća nil ako tip nije podržan ili model nije učitan.
    static func loadSceneKitNode(objectId: String, bundle: Bundle = .main) -> SCNNode? {
        guard let type = PlaceableSceneKitTypes.all.first(where: { $0.objectId == objectId }) else { return nil }
        return type.loadSceneKitNode(from: bundle)
    }

    /// Ponovno primijeni teksturu na klonirani čvor (nakon clone() materijali se dijele). Vraća true ako je primijenjeno.
    static func reapplyTexture(objectId: String, to node: SCNNode, bundle: Bundle = .main) -> Bool {
        guard let type = PlaceableSceneKitTypes.all.first(where: { $0.objectId == objectId }) else { return false }
        return type.reapplyTexture(to: node, bundle: bundle)
    }
}
