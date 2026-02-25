//
//  SceneKitLevelLoader.swift
//  Feudalism
//
//  Učitavanje mape iz .scn (SceneKit scene). Level = vizualni layout; gameplay objekti
//  se i dalje spawnaju iz GameMap/Placement u kodu.
//

import Foundation
import SceneKit
import AppKit

/// Rezultat učitavanja levela: root čvor za scenu i (opcionalno) čvor "terrain" za hit test.
struct LoadedLevel {
    /// Sadržaj levela – dodaj kao child u scene.rootNode. Ne uključuje kameru/svjetla (dodaje view).
    let levelRoot: SCNNode
    /// Čvor za hit test (name == "terrain"). Ako nil, view koristi proceduralni teren za klik.
    let terrainNode: SCNNode?
}

/// Učitava .scn level iz bundlea ili iz spremljenog filea. Solo mod: prvo učitaj postojeću (bundle ili SoloLevel.scn), inače generiraj i spremi.
/// Očekivani format: node "terrain" za hit test; koordinatni sustav 4000×4000; gameplay objekti se spawnaju iz GameMap u kodu.
enum SceneKitLevelLoader {
    /// Podržane ekstenzije (prvo .scn, pa .dae ako želiš Collada).
    private static let extensions = ["scn", "dae"]

    /// URL spremljenog solo levela: Application Support/Feudalism/SoloLevel.scn
    static func soloLevelFileURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let feudalism = dir.appendingPathComponent("Feudalism", isDirectory: true)
        try? FileManager.default.createDirectory(at: feudalism, withIntermediateDirectories: true)
        return feudalism.appendingPathComponent("SoloLevel.scn")
    }

    /// Obriši spremljenu solo mapu (.scn i _terrain.png) da se sljedeći put generira nova s ispravnom teksturom.
    static func deleteSoloLevelFiles() {
        guard let scnURL = soloLevelFileURL() else { return }
        let textureURL = scnURL.deletingLastPathComponent().appendingPathComponent("SoloLevel_terrain.png")
        try? FileManager.default.removeItem(at: scnURL)
        try? FileManager.default.removeItem(at: textureURL)
    }

    /// Solo mod: učitaj mapu. Redoslijed: (1) bundle po currentLevelName, (2) spremljeni SoloLevel.scn ako postoji, (3) nil = view će generirati i spremiti.
    static func loadForSoloMode(bundleLevelName: String?, bundle: Bundle = .main) -> LoadedLevel? {
        if let name = bundleLevelName, !name.isEmpty, let level = load(name: name, bundle: bundle) {
            return level
        }
        if let url = soloLevelFileURL(), FileManager.default.fileExists(atPath: url.path), let level = load(from: url, bundle: bundle) {
            return level
        }
        return nil
    }

    /// Generira level od jednog teren čvora, sprema u SoloLevel.scn i vraća LoadedLevel za prikaz (klon za view).
    /// Tekstura terena se eksportira u PNG (SoloLevel_terrain.png) i postavlja na materijal prije spremanja, tako da se spremi u mapu.
    /// Rotaciju terena ne dira – mora ostati u XZ ravnini (eulerAngles.x = -π/2) da se ne spremi krivo.
    static func generateAndSaveSoloLevel(terrainNode: SCNNode) -> LoadedLevel? {
        guard let scnURL = soloLevelFileURL() else { return nil }
        let dir = scnURL.deletingLastPathComponent()
        let textureURL = dir.appendingPathComponent("SoloLevel_terrain.png")
        // Obriši staru spremljenu mapu da se ne učitava bijeli/starí level – nova se generira s ispravnom teksturom.
        try? FileManager.default.removeItem(at: scnURL)
        try? FileManager.default.removeItem(at: textureURL)
        if SceneKitMapView.exportTerrainTextureFromNode(terrainNode, to: textureURL),
           let image = NSImage(contentsOf: textureURL) {
            let cloneForFile = terrainNode.clone()
            cloneForFile.position = SCNVector3Zero
            if let mat = cloneForFile.geometry?.materials.first {
                mat.diffuse.contents = image
                mat.ambient.contents = NSColor.black
                mat.specular.contents = NSColor.black
            }
            let scene = SCNScene()
            scene.rootNode.addChildNode(cloneForFile)
            do {
                try scene.write(to: scnURL, options: nil, delegate: nil)
            } catch {
                return nil
            }
        } else {
            let cloneForFile = terrainNode.clone()
            cloneForFile.position = SCNVector3Zero
            let scene = SCNScene()
            scene.rootNode.addChildNode(cloneForFile)
            do {
                try scene.write(to: scnURL, options: nil, delegate: nil)
            } catch {
                return nil
            }
        }
        let levelRoot = SCNNode()
        levelRoot.name = "levelRoot"
        let cloneForView = terrainNode.clone()
        levelRoot.addChildNode(cloneForView)
        let terrainForHit = levelRoot.childNodes.first { $0.name == "terrain" }
        terrainForHit?.categoryBitMask = 1
        return LoadedLevel(levelRoot: levelRoot, terrainNode: terrainForHit)
    }

    /// Učita level po imenu (bez ekstenzije). Npr. "Level" → Level.scn, "Maps/Level" → Maps/Level.scn.
    /// Vraća nil ako datoteka ne postoji ili se ne može učitati.
    static func load(name: String, bundle: Bundle = .main) -> LoadedLevel? {
        guard !name.isEmpty else { return nil }
        let base = name.hasSuffix("/") ? String(name.dropLast()) : name
        let pathParts = base.split(separator: "/").map(String.init)
        let fileName = pathParts.last ?? base
        let subdirectory: String? = pathParts.count > 1 ? pathParts.dropLast().joined(separator: "/") : nil
        for ext in extensions {
            let url: URL? = subdirectory != nil
                ? bundle.url(forResource: fileName, withExtension: ext, subdirectory: subdirectory)
                : bundle.url(forResource: fileName, withExtension: ext)
            if let url = url {
                return load(from: url, bundle: bundle)
            }
        }
        return nil
    }

    /// Učita level iz URL-a (file:// ili u bundleu).
    static func load(from url: URL, bundle: Bundle = .main) -> LoadedLevel? {
        guard let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) else { return nil }
        let levelRoot = SCNNode()
        levelRoot.name = "levelRoot"
        for child in scene.rootNode.childNodes {
            levelRoot.addChildNode(child.clone())
        }
        let terrainNode = findTerrainNode(in: levelRoot)
        terrainNode?.categoryBitMask = 1
        return LoadedLevel(levelRoot: levelRoot, terrainNode: terrainNode)
    }

    /// Pronađi čvor s name == "terrain" u hijerarhiji (za hit test).
    private static func findTerrainNode(in node: SCNNode) -> SCNNode? {
        if node.name == "terrain" { return node }
        for child in node.childNodes {
            if let t = findTerrainNode(in: child) { return t }
        }
        return nil
    }
}
