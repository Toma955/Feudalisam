//
//  SmallWall.swift
//  Feudalism
//
//  Mali zid: child od ParentWall; samo prosljeđuje visinu (wallHeightInUnits = 240). Parent radi 3D i teksture.
//

import Foundation
import AppKit
import SceneKit

enum SmallWall: PlaceableSceneKitObject {
    static let objectId = "object_wall_small"
    static let displayCode = "S"
    static let modelAssetName: String? = nil

    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Small wall",
            category: .ostali,
            width: 1,
            height: 1,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        ParentWall.loadSceneKitNode(from: bundle, wallHeight: wallHeightInUnits)
    }

    static func reapplyTexture(to node: SCNNode, bundle: Bundle = .main) -> Bool {
        ParentWall.reapplyTexture(to: node, bundle: bundle, wallHeight: wallHeightInUnits)
    }
}
