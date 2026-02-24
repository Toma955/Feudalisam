//
//  PlaceableSceneKitObject.swift
//  Feudalism
//
//  Protocol za objekte koji se mogu postaviti na 3D kartu – učitavanje modela i primjena teksture.
//  Svaki tip (Wall, Market, Windmill, …) konformira; registry koristi ovaj protokol umjesto switcha.
//

import Foundation
import SceneKit

/// Objekt koji ima 3D model na karti: id, učitavanje čvora i ponovna primjena teksture.
protocol PlaceableSceneKitObject {
    static var objectId: String { get }
    static func loadSceneKitNode(from bundle: Bundle) -> SCNNode?
    static func reapplyTexture(to node: SCNNode, bundle: Bundle) -> Bool
}

/// Svi tipovi koji se mogu postaviti na mapu (redoslijed za registry).
enum PlaceableSceneKitTypes {
    static let all: [PlaceableSceneKitObject.Type] = [
        Wall.self,
        Steps.self,
        Market.self,
        Windmill.self,
        Bakery.self,
        Granary.self,
        Well.self,
        Hotel.self,
        Iron.self,
        Stone.self,
        Chicken.self,
        Corn.self,
    ]
}
