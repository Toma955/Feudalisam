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

/// Registry objekata koji imaju 3D model na karti. Učitavanje i reapply teksture po objectId.
enum SceneKitPlacementRegistry {
    /// Svi objectId-evi koji se mogu postaviti na mapu s 3D modelom (redoslijed nije bitan).
    static let placeableObjectIds: [String] = [
        Wall.objectId,
        Market.objectId,
        Windmill.objectId,
        Bakery.objectId,
        Granary.objectId,
        Well.objectId,
        Hotel.objectId,
        Iron.objectId,
        Stone.objectId,
        Chicken.objectId,
        Corn.objectId,
    ]

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
        switch objectId {
        case Wall.objectId: return Wall.loadSceneKitNode(from: bundle)
        case Market.objectId: return Market.loadSceneKitNode(from: bundle)
        case Windmill.objectId: return Windmill.loadSceneKitNode(from: bundle)
        case Bakery.objectId: return Bakery.loadSceneKitNode(from: bundle)
        case Granary.objectId: return Granary.loadSceneKitNode(from: bundle)
        case Well.objectId: return Well.loadSceneKitNode(from: bundle)
        case Hotel.objectId: return Hotel.loadSceneKitNode(from: bundle)
        case Iron.objectId: return Iron.loadSceneKitNode(from: bundle)
        case Stone.objectId: return Stone.loadSceneKitNode(from: bundle)
        case Chicken.objectId: return Chicken.loadSceneKitNode(from: bundle)
        case Corn.objectId: return Corn.loadSceneKitNode(from: bundle)
        default: return nil
        }
    }

    /// Ponovno primijeni teksturu na klonirani čvor (nakon clone() materijali se dijele). Vraća true ako je primijenjeno.
    static func reapplyTexture(objectId: String, to node: SCNNode, bundle: Bundle = .main) -> Bool {
        switch objectId {
        case Wall.objectId: return Wall.reapplyTexture(to: node, bundle: bundle)
        case Market.objectId: return Market.reapplyTexture(to: node, bundle: bundle)
        case Windmill.objectId: return Windmill.reapplyTexture(to: node, bundle: bundle)
        case Bakery.objectId: return Bakery.reapplyTexture(to: node, bundle: bundle)
        case Granary.objectId: return Granary.reapplyTexture(to: node, bundle: bundle)
        case Well.objectId: return Well.reapplyTexture(to: node, bundle: bundle)
        case Hotel.objectId: return Hotel.reapplyTexture(to: node, bundle: bundle)
        case Iron.objectId: return Iron.reapplyTexture(to: node, bundle: bundle)
        case Stone.objectId: return Stone.reapplyTexture(to: node, bundle: bundle)
        case Chicken.objectId: return Chicken.reapplyTexture(to: node, bundle: bundle)
        case Corn.objectId: return Corn.reapplyTexture(to: node, bundle: bundle)
        default: return false
        }
    }
}
