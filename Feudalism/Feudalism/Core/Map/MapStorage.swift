//
//  MapStorage.swift
//  Feudalism
//
//  Mape se spremaju u foldere ovisno o dimenziji: samo 200, 400, 600, 800, 1000.
//  Struktura: Maps/200x200/, Maps/400x400/, Maps/600x600/, Maps/800x800/, Maps/1000x1000/.
//  (side = broj minimalnih jedinica 10×10 po strani; izvor: MapDimension.)
//

import Foundation

enum MapStorage {
    private static let mapsSubdir = "Maps"
    private static let catalogFileName = "map_catalog.json"

    private static var _lastMapsRootInProject: Bool = false

    /// Root za sve mape. Prvo pokušaj unutar projekta (PROJECT_DIR / cwd), pa Application Support kao fallback.
    /// Za spremanje u projekt: Xcode → Edit Scheme → Run → Options → Working Directory = $(PROJECT_DIR).
    static func mapsRoot() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"], !projectDir.isEmpty, !projectDir.contains("$(") {
            candidates.append(URL(fileURLWithPath: projectDir).appendingPathComponent("Feudalism", isDirectory: true).appendingPathComponent(mapsSubdir, isDirectory: true))
            candidates.append(URL(fileURLWithPath: projectDir).appendingPathComponent(mapsSubdir, isDirectory: true))
        }
        let cwd = fm.currentDirectoryPath
        if !cwd.isEmpty, cwd != "/" {
            candidates.append(URL(fileURLWithPath: cwd).appendingPathComponent("Feudalism", isDirectory: true).appendingPathComponent(mapsSubdir, isDirectory: true))
            candidates.append(URL(fileURLWithPath: cwd).appendingPathComponent(mapsSubdir, isDirectory: true))
        }
        for url in candidates {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                _lastMapsRootInProject = true
                return url
            } catch { continue }
        }
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            _lastMapsRootInProject = false
            return nil
        }
        let fallback = appSupport.appendingPathComponent("Feudalism", isDirectory: true).appendingPathComponent(mapsSubdir, isDirectory: true)
        try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
        _lastMapsRootInProject = false
        return fallback
    }

    /// Je li trenutni root za mape unutar projekta (true) ili Application Support (false). Bitno za spremanje – sustav zahtijeva spremanje u projekt.
    static func isMapsRootInProject() -> Bool {
        _ = mapsRoot()
        return _lastMapsRootInProject
    }

    /// Trenutna putanja u koju se spremaju mape (za prikaz u UI). Ako root nije dostupan, vraća "—".
    static func mapsRootPath() -> String {
        mapsRoot()?.path ?? "—"
    }

    /// Dopuštene dimenzije za foldere: izvor je enum MapDimension (200, 400, 600, 800, 1000).
    static func allowedSizes() -> [Int] {
        MapDimension.allSides
    }

    /// Folder za danu stranu (broj minimalnih jedinica po strani), npr. Maps/200x200/.
    static func directory(side: Int) -> URL? {
        guard let root = mapsRoot(), allowedSizes().contains(side) else { return nil }
        return root.appendingPathComponent("\(side)x\(side)", isDirectory: true)
    }

    /// Folder za mapu iz broja ćelija (rows == cols). 200×200 → 200x200.
    static func directory(rows: Int, cols: Int) -> URL? {
        guard rows == cols else { return nil }
        return directory(side: folderSide(rows: rows, cols: cols))
    }

    /// Potpun URL datoteke mape (npr. Maps/200x200/map_editor_solo.json).
    static func fileURL(side: Int, fileName: String) -> URL? {
        directory(side: side).map { $0.appendingPathComponent(fileName) }
    }

    /// Potpun URL za mapu iz rows/cols (kvadratna). Side za folder: 200×200 ćelija → 200x200.
    static func fileURL(rows: Int, cols: Int, fileName: String) -> URL? {
        guard rows == cols else { return nil }
        return fileURL(side: folderSide(rows: rows, cols: cols), fileName: fileName)
    }

    /// Side za ime foldera: rows ako je preset (200,400,…), inače rows*4 (legacy).
    static func folderSide(rows: Int, cols: Int) -> Int {
        guard rows == cols else { return rows * MapScale.smallCellsPerObjectCubeSide }
        return MapDimension.allSides.contains(rows) ? rows : (rows * MapScale.smallCellsPerObjectCubeSide)
    }

    /// Relativna staza (npr. "200x200/map_editor_solo.json").
    static func relativePath(side: Int, fileName: String) -> String? {
        guard allowedSizes().contains(side) else { return nil }
        return "\(side)x\(side)/\(fileName)"
    }

    /// Relativna staza iz rows/cols (kvadratna).
    static func relativePath(rows: Int, cols: Int, fileName: String) -> String? {
        guard rows == cols else { return nil }
        return relativePath(side: folderSide(rows: rows, cols: cols), fileName: fileName)
    }

    /// Ime datoteke za mapu: iz naziva mape (sanitizirano) ili fallback na slot (npr. map_editor_solo.json).
    /// Razmake zamjenjuje s _, uklanja znakove neprikladne za datoteku, ograničava duljinu; rezultat + ".json".
    static func fileName(forMapName mapName: String, slotFallback: MapEditorSlot) -> String {
        let t = mapName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return slotFallback.fileName }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-"))
        let sanitized = t
            .components(separatedBy: allowed.inverted)
            .joined(separator: "")
            .replacingOccurrences(of: " ", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let base = String(sanitized.prefix(120))
        guard !base.isEmpty else { return slotFallback.fileName }
        return base + ".json"
    }

    /// Stvori root Maps/ i foldere po dimenzijama: 200x200, 400x400, 600x600, 800x800, 1000x1000 (ako ne postoje).
    static func createSizeFoldersIfNeeded() {
        guard let root = mapsRoot() else { return }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for side in allowedSizes() {
            let dir = root.appendingPathComponent("\(side)x\(side)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Putanja foldera za prikaz (npr. "…/Feudalism/Maps/200x200/").
    static func displayPathForMap(side: Int) -> String {
        guard let dir = directory(side: side) else { return "—" }
        return dir.path
    }

    static func displayPathForMap(rows: Int, cols: Int) -> String {
        guard rows == cols else { return "—" }
        return displayPathForMap(side: folderSide(rows: rows, cols: cols))
    }
}
