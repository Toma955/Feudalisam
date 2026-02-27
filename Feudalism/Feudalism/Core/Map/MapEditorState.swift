//
//  MapEditorState.swift
//  Feudalism
//
//  Editor-only stanje – NE spremaju se u datoteku. Generira se kad se uključi editor mode
//  i veže na trenutnu mapu: selected, hovered, brushPreview, tempHeightDelta, paintMask,
//  debugFlags, undo/redo.
//

import Foundation
import SwiftUI

/// Jedna akcija u undo/redo stogu (npr. promjena visine jedne ćelije ili grupe).
struct MapEditorUndoAction {
    let cellIds: [String]
    let previousHeights: [String: CGFloat]
    let previousTerrain: [String: TerrainType]
    let previousWalkable: [String: Bool]
    /// Vrsta: elevacija ili teren/walkable.
    let kind: Kind
    enum Kind {
        case elevation
        case terrain
    }
}

/// Stanje koje se generira na mapi kad se uključi editor mode – linka se na GameMap.
/// Ne spremaju se u fizičku datoteku.
final class MapEditorState: ObservableObject {
    /// Odabrana ćelija (npr. za prikaz podataka ili kontekstni izbornik).
    @Published var selectedCell: MapCoordinate?
    /// Ćelija ispod kursora (hover).
    @Published var hoveredCell: MapCoordinate?
    /// Označene ćelije za precizno uređivanje visine (klik u modu „Odabir ćelija”).
    @Published var selectedCells: Set<MapCoordinate> = []
    /// Odabrana točka sjecišta (vertex) – jedna kugla = jedan vrh; pomicanje gore/dolje samo ta točka.
    @Published var selectedVertex: (row: Int, col: Int)?
    /// Koordinate prikaza četkice (brush preview) – prikazuje se na sceni.
    @Published var brushPreviewCells: [MapCoordinate] = []
    /// Privremena delta visine za prikaz (npr. +5 dok korisnik drži četkicu).
    @Published var tempHeightDelta: CGFloat = 0
    /// Maska ćelija obojanih za paint (npr. za batch operacije).
    @Published var paintMask: Set<String> = []
    /// Zastavice za debug (npr. prikaz mreže, normale).
    @Published var debugFlags: Set<String> = []

    /// Undo stog – globalno po editoru, ne po tileu.
    @Published private(set) var undoStack: [MapEditorUndoAction] = []
    @Published private(set) var redoStack: [MapEditorUndoAction] = []

    let maxUndoSteps: Int = 64

    init() {}

    func pushUndo(action: MapEditorUndoAction) {
        redoStack.removeAll()
        undoStack.append(action)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
    }

    func undo(applier: (MapEditorUndoAction) -> Void) {
        guard let action = undoStack.popLast() else { return }
        applier(action)
        redoStack.append(action)
    }

    func redo(applier: (MapEditorUndoAction) -> Void) {
        guard let action = redoStack.popLast() else { return }
        applier(action)
        undoStack.append(action)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Uključi/isključi ćeliju u odabir (mod „Odabir ćelija”).
    func toggleCellSelection(_ coordinate: MapCoordinate) {
        if selectedCells.contains(coordinate) {
            selectedCells.remove(coordinate)
        } else {
            selectedCells.insert(coordinate)
        }
        objectWillChange.send()
    }

    /// Ukloni sve označene ćelije iz odabira.
    func clearCellSelection() {
        selectedCells.removeAll()
        objectWillChange.send()
    }

    /// Očisti sve editor-only stanje (npr. pri izlasku iz editora).
    func clear() {
        selectedCell = nil
        hoveredCell = nil
        selectedCells = []
        selectedVertex = nil
        brushPreviewCells = []
        tempHeightDelta = 0
        paintMask = []
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
