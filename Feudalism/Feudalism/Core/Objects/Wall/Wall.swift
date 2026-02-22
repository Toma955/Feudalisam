//
//  Wall.swift
//  Feudalism
//
//  Objekt Zid (Wall). Stvarne datoteke u Core/Objects/Wall/Wall/:
//  - Meshy_AI_Stone_Wall_0221071847_texture.obj
//  - Meshy_AI_Stone_Wall_0221071847_texture.mtl  (map_Kd Meshy_AI_Stone_Wall_0221071847_texture.png)
//  - Meshy_AI_Stone_Wall_0221071847_texture.png (tekstura – isto ime kao u .mtl)
//  .obj + .mtl + .png učitavaju se iz bundlea za prikaz u igri.
//

import Foundation
import AppKit
import SceneKit

/// Zid – objekt koji se gradi na karti. 3D model iz podmape Wall/ (Meshy AI Stone Wall).
enum Wall {
    /// Stabilan id tipa (za placement na mapi).
    static let objectId = "object_wall"

    /// Kratica za prikaz na karti / u listi.
    static let displayCode = "W"

    /// Ime 3D modela u bundleu (bez ekstenzije) – datoteka u Wall/Meshy_AI_Stone_Wall_0221071847_texture.obj
    static let modelAssetName = "Meshy_AI_Stone_Wall_0221071847_texture"
    /// Podmapa u bundleu gdje leže .obj, .mtl i .png (isti folder da .mtl nađe teksturu).
    static let modelSubdirectory = "Wall"

    /// Jedan GameObject za Zid – za katalog i placement na mapi.
    static var gameObject: GameObject {
        GameObject(
            id: objectId,
            name: "Wall",
            category: .ostali,
            width: 1,
            height: 1,
            displayCode: displayCode,
            modelAssetName: modelAssetName
        )
    }

    /// URL 3D modela (.obj) u bundleu – za učitavanje u igri. Podmapa Wall/ mora biti u targetu.
    static func modelURL(in bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: modelSubdirectory) {
            return url
        }
        return bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Core/Objects/Wall/Wall")
            ?? bundle.url(forResource: modelAssetName, withExtension: "obj")
    }

    /// Svi subdirectory putovi koje probamo (Xcode File System Sync može staviti resurse u Feudalism/...).
    private static let textureSubdirectories: [String?] = [
        "Wall",
        "Core/Objects/Wall/Wall",
        "Feudalism/Core/Objects/Wall/Wall",
        "Feudalism/Core/Objects/Wall",
        "Feudalism/Core/Objects",
        "Feudalism/Core",
        "Feudalism",
        nil, // root
    ]

    /// Učitaj teksturu iz iste mape kao .obj (direktno uz model u bundleu). Najpouzdanije.
    private static func loadTextureImageNextToOBJ(objURL: URL, bundle: Bundle = .main) -> Any? {
        let dir = objURL.deletingLastPathComponent()
        let names = [modelAssetName, "texture"]
        print("[Wall] Traženje teksture u istoj mapi kao .obj: \(dir.path)")
        for name in names {
            let texURL = dir.appendingPathComponent(name).appendingPathExtension("png")
            guard (try? texURL.checkResourceIsReachable()) == true else {
                print("[Wall]   – \(name).png: ne postoji")
                continue
            }
            print("[Wall]   – \(name).png: pronađen, učitavam…")
            if let image = NSImage(contentsOf: texURL) {
                print("[Wall] TEKSTURA UČITANA: iz iste mape kao .obj (\(name).png), veličina \(image.size.width)x\(image.size.height)")
                return image
            }
            print("[Wall]   → učitavanje slike nije uspjelo")
        }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            print("[Wall] U mapi .obj nalaze se datoteke: \(contents.joined(separator: ", ")). Ako nema .png, dodaj ga u Xcode (isti folder kao .obj) i u Copy Bundle Resources.")
        }
        return nil
    }

    /// Učitaj sliku teksture iz bundlea; ispisuje u konzolu što se dogodilo. Probamo sve vjerojatne putanje.
    private static func loadTextureImage(bundle: Bundle = .main, objURL: URL? = nil) -> Any? {
        if let obj = objURL, let img = loadTextureImageNextToOBJ(objURL: obj, bundle: bundle) {
            return img
        }
        let names = [modelAssetName, "texture"]
        let ext = "png"
        if let r = bundle.resourcePath {
            print("[Wall] Bundle resource path: \(r)")
        }
        print("[Wall] Učitavanje teksture: pokušaj pronaći .png u bundleu…")
        for name in names {
            for sub in textureSubdirectories {
                let subLabel = sub ?? "root"
                let url = sub != nil
                    ? bundle.url(forResource: name, withExtension: ext, subdirectory: sub)
                    : bundle.url(forResource: name, withExtension: ext)
                guard let url = url else {
                    print("[Wall]   – \(name).\(ext) u \(subLabel): NEMA (nil)")
                    continue
                }
                print("[Wall]   – \(name).\(ext) u \(subLabel): pronađen path \(url.path)")
                if let image = NSImage(contentsOf: url) {
                    print("[Wall] TEKSTURA UČITANA: \(name).png iz subdirectory '\(subLabel)', veličina \(image.size.width)x\(image.size.height)")
                    return image
                } else {
                    print("[Wall]   → NSImage(contentsOf:) vratio nil (datoteka prazna ili nije slika)")
                }
            }
        }
        // Direktno s resourceURL + relativna putanja (za slučaj da forResource ne radi kako očekujemo)
        if let base = bundle.resourceURL {
            let pathsToTry = [
                "Feudalism/Core/Objects/Wall/Wall/\(modelAssetName).png",
                "Feudalism/Core/Objects/Wall/Wall/texture.png",
                "Core/Objects/Wall/Wall/\(modelAssetName).png",
                "Core/Objects/Wall/Wall/texture.png",
                "Wall/\(modelAssetName).png",
                "Wall/texture.png",
                "\(modelAssetName).png",
                "texture.png",
            ]
            for rel in pathsToTry {
                let full = base.appendingPathComponent(rel)
                if (try? full.checkResourceIsReachable()) == true {
                    print("[Wall]   – direktni path \(rel): postoji, učitavam…")
                    if let image = NSImage(contentsOf: full) {
                        print("[Wall] TEKSTURA UČITANA: direktno iz \(rel), veličina \(image.size.width)x\(image.size.height)")
                        return image
                    }
                }
            }
        }
        print("[Wall] TEKSTURA NIJE UČITANA: nijedan .png nije pronađen na probanim putanjama. Provjeri da \(modelAssetName).png ili texture.png stoji u Copy Bundle Resources i da je u mapi Wall (npr. Feudalism/Core/Objects/Wall/Wall/).")
        return nil
    }

    /// Ako true, umjesto teksture stavi magenta (test: vidi li se boja → problem je UV ili učitavanje slike).
    private static let useTextureTestColor = false

    /// Stavi teksturu na sve materijale nodea (rekurzivno). Eksplicitno: wrap, isDoubleSided, lightingModel.
    /// Vraća broj materijala na koje je stavljena. Logira broj materijala za debug.
    private static func applyTextureToNode(_ node: SCNNode, textureImage: Any?) -> Int {
        guard textureImage != nil || useTextureTestColor else { return 0 }
        var n = 0
        if let geo = node.geometry {
            let mats = geo.materials
            if !mats.isEmpty {
                print("[Wall] applyTextureToNode: node '\(node.name ?? "?")' ima \(mats.count) materijal(a)")
            }
            for (i, mat) in mats.enumerated() {
                if useTextureTestColor {
                    mat.diffuse.contents = NSColor.magenta
                    mat.isDoubleSided = true
                    mat.lightingModel = .blinn
                    print("[Wall] mat[\(i)] postavljen na MAGENTA (test – ako se vidi, problem je UV ili učitavanje teksture)")
                } else if let textureImage = textureImage {
                    mat.diffuse.contents = textureImage
                    mat.diffuse.wrapS = .repeat
                    mat.diffuse.wrapT = .repeat
                    mat.isDoubleSided = true
                    mat.lightingModel = .physicallyBased
                }
                n += 1
            }
        }
        for child in node.childNodes {
            n += applyTextureToNode(child, textureImage: textureImage)
        }
        return n
    }

    /// Ispisuje u konzolu zašto se tekstura možda ne prikazuje (bijela boja umjesto slike).
    static func printTextureDiagnostics(bundle: Bundle = .main) {
        print("---------- [Wall] Dijagnostika teksture ----------")
        var hasProblem = false

        // 1. Nađi .obj
        let objURL: URL?
        if let url = bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: modelSubdirectory) {
            objURL = url
            print("[Wall] OK: .obj pronađen u bundleu (subdirectory: \(modelSubdirectory))")
        } else if let url = bundle.url(forResource: modelAssetName, withExtension: "obj", subdirectory: "Core/Objects/Wall/Wall") {
            objURL = url
            print("[Wall] OK: .obj pronađen u bundleu (subdirectory: Core/Objects/Wall/Wall)")
        } else if let url = bundle.url(forResource: modelAssetName, withExtension: "obj") {
            objURL = url
            print("[Wall] OK: .obj pronađen u bundleu (bez subdirectory)")
        } else {
            objURL = nil
            print("[Wall] PROBLEM: .obj NIJE pronađen. Provjeri: target Copy Bundle Resources sadrži \(modelAssetName).obj u mapi Wall/ ili Core/Objects/Wall/Wall/.")
            hasProblem = true
        }

        // 2. Postoji li tekstura u bundleu? (.mtl referencira Meshy_AI_Stone_Wall_0221071847_texture.png)
        let textureName = "Meshy_AI_Stone_Wall_0221071847_texture"
        let textureURLinWall = bundle.url(forResource: textureName, withExtension: "png", subdirectory: modelSubdirectory)
        let textureURLinWallFull = bundle.url(forResource: textureName, withExtension: "png", subdirectory: "Core/Objects/Wall/Wall")
        let textureURLAny = bundle.url(forResource: textureName, withExtension: "png")
        if textureURLinWall != nil {
            print("[Wall] OK: Tekstura .png pronađena u bundleu (subdirectory: \(modelSubdirectory))")
        } else if textureURLinWallFull != nil {
            print("[Wall] OK: Tekstura .png pronađena (subdirectory: Core/Objects/Wall/Wall)")
        } else if textureURLAny != nil {
            print("[Wall] UPOZORENJE: Tekstura .png postoji u bundleu, ali NE u istoj mapi kao .obj. SceneKit traži teksturu relativno uz .obj – stavi \(textureName).png u istu mapu kao .obj.")
            hasProblem = true
        } else {
            print("[Wall] PROBLEM: Tekstura \(textureName).png NIJE u bundleu. Zato je model bijel. U Xcodeu: Add Files → odaberi \(textureName).png iz Core/Objects/Wall/Wall/, označi target Feudalism i Copy Bundle Resources.")
            hasProblem = true
        }

        // 3. Učitaj scenu i provjeri materijale
        if let url = objURL, let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
            var materialCount = 0
            var materialsWithTexture = 0
            scene.rootNode.enumerateChildNodes { node, _ in
                guard let geo = node.geometry else { return }
                for m in geo.materials {
                    materialCount += 1
                    let c = m.diffuse.contents
                    let isColor = c is NSColor
                    if c != nil && !isColor { materialsWithTexture += 1 }
                }
            }
            if materialCount > 0 {
                if materialsWithTexture == 0 {
                    print("[Wall] PROBLEM: Model ima \(materialCount) materijal(a), ali NIJEDAN nema učitani diffuse texture (sve je boja). Uzrok: .mtl ne nalazi .png (pogrešan path u .mtl ili .png nije u istom folderu kao .obj u bundleu).")
                    hasProblem = true
                } else {
                    print("[Wall] OK: Učitano \(materialsWithTexture)/\(materialCount) materijala s teksturom.")
                }
            }
        } else if objURL != nil {
            print("[Wall] PROBLEM: Scena se nije uspjela učitati iz .obj (oštećen file ili nedostaje .mtl).")
            hasProblem = true
        }

        if !hasProblem {
            print("[Wall] Dijagnostika: nema očitih problema; ako je i dalje bijelo, provjeri ime u .mtl (map_Kd) i da li je .png u Copy Bundle Resources u istoj mapi kao .obj.")
        }
        print("---------- [Wall] Kraj dijagnostike ----------")
    }

    /// Učitaj 3D model zida kao SCNNode – igra je 3D. Tekstura se učitava iz iste mape kao .obj pa iz bundlea; u konzolu se ispisuje što se dogodilo.
    static func loadSceneKitNode(from bundle: Bundle = .main) -> SCNNode? {
        print("[Wall] Učitavanje 3D modela zida…")
        guard let url = modelURL(in: bundle) else {
            print("[Wall] Model NIJE učitán: .obj nije pronađen u bundleu.")
            return nil
        }
        guard let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) else {
            print("[Wall] Model NIJE učitán: SCNScene(url:) nije uspjela (oštećen .obj ili .mtl).")
            return nil
        }
        print("[Wall] Model .obj učitán s URL: \(url.path)")
        let node = SCNNode()
        for child in scene.rootNode.childNodes {
            node.addChildNode(child.clone())
        }
        let textureImage = loadTextureImage(bundle: bundle, objURL: url)
        if let textureImage = textureImage {
            let numMaterials = applyTextureToNode(node, textureImage: textureImage)
            print("[Wall] Tekstura primijenjena na \(numMaterials) materijal(a). Zid bi sada trebao biti s teksturom (ne bijel).")
        } else {
            print("[Wall] Tekstura nije primijenjena – slika nije učitana. Zid će ostati bijel.")
        }
        return node
    }
}
