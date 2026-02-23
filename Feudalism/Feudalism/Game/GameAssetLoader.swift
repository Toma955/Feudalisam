//
//  GameAssetLoader.swift
//  Feudalism
//
//  Paralelno učitavanje asseta pri pokretanju igre: teren, level .scn, modeli objekata.
//  Teški posao (decode, čitanje) na background taskovima; korištenje cachea na MainActor.
//

import Foundation
import SceneKit
import SwiftUI

/// Cache učitane assete – teren, level, template čvorovi po objectId.
struct LoadedGameAssets {
    var terrainTexture: Any?
    var level: LoadedLevel?
    /// Učitani 3D čvorovi za svaki placeable objectId (za template/ghost).
    var placementNodes: [String: SCNNode] = [:]
}

/// Paralelni loader s progressom. Pokreni pri startu igre (npr. IntroView).
final class GameAssetLoader: ObservableObject {
    static let shared = GameAssetLoader()

    @Published private(set) var loadProgress: Double = 0
    @Published private(set) var loadStatus: String = ""
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var assets: LoadedGameAssets = LoadedGameAssets()

    private let lock = NSLock()
    private var loadTask: Task<Void, Never>?

    private init() {}

    /// Maksimalan broj istovremenih taskova (ne preopterećuj disk).
    private static var maxConcurrency: Int {
        min(6, max(2, ProcessInfo.processInfo.activeProcessorCount - 1))
    }

    /// Pokreni učitavanje ako još nije pokrenuto; inače samo čekaj. Pozovi pri startu (IntroView).
    func loadAllIfNeeded() async {
        if isLoaded { return }
        lock.lock()
        if let existing = loadTask {
            lock.unlock()
            _ = await existing.value
            return
        }
        let task = Task { await loadAll() }
        loadTask = task
        lock.unlock()
        await task.value
    }

    /// Jednom paralelno učitaj sve: teren, level, svi modeli. Progress i status ažuriraju se na MainActor.
    func loadAll() async {
        await MainActor.run {
            loadStatus = "Priprema…"
            loadProgress = 0
        }

        let totalSteps = 2 + SceneKitPlacementRegistry.placeableObjectIds.count
        var completed = 0

        func reportProgress() {
            completed += 1
            let p = Double(completed) / Double(totalSteps)
            Task { @MainActor in
                self.loadProgress = p
                if completed < totalSteps {
                    self.loadStatus = "Učitavanje… \(Int(p * 100))%"
                }
            }
        }

        var terrainTexture: Any?
        var level: LoadedLevel?
        var placementNodes: [String: SCNNode] = [:]

        await withTaskGroup(of: (String, Any?).self) { group in
            group.addTask {
                let t = SceneKitMapView.createTerrainTextureForPreload()
                reportProgress()
                return ("terrain", t)
            }
            group.addTask {
                if !UserDefaults.standard.bool(forKey: "Feudalism.didDeleteStaleSoloLevelForTextureFix") {
                    SceneKitLevelLoader.deleteSoloLevelFiles()
                    UserDefaults.standard.set(true, forKey: "Feudalism.didDeleteStaleSoloLevelForTextureFix")
                }
                let l = SceneKitLevelLoader.loadForSoloMode(bundleLevelName: "Level", bundle: .main)
                reportProgress()
                return ("level", l as Any?)
            }
            for objectId in SceneKitPlacementRegistry.placeableObjectIds {
                group.addTask {
                    let node = SceneKitPlacementRegistry.loadSceneKitNode(objectId: objectId, bundle: .main)
                    reportProgress()
                    return (objectId, node as Any?)
                }
            }

            for await (key, value) in group {
                switch key {
                case "terrain":
                    terrainTexture = value
                case "level":
                    level = value as? LoadedLevel
                default:
                    if let node = value as? SCNNode {
                        placementNodes[key] = node
                    }
                }
            }
        }

        await MainActor.run {
            assets = LoadedGameAssets(
                terrainTexture: terrainTexture,
                level: level,
                placementNodes: placementNodes
            )
            isLoaded = true
            loadProgress = 1
            loadStatus = "Gotovo"
        }
    }

    /// Dohvati učitani level (nil ako nije učitan ili nema mape).
    func cachedLevel() -> LoadedLevel? {
        assets.level
    }

    /// Dohvati učitani placement čvor za objectId (nil ako nije učitan).
    func cachedPlacementNode(objectId: String) -> SCNNode? {
        assets.placementNodes[objectId]
    }

    /// Dohvati učitanu teksturu terena (nil ako nije učitana).
    func cachedTerrainTexture() -> Any? {
        assets.terrainTexture
    }
}
