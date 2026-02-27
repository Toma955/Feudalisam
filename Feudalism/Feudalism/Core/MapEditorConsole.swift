//
//  MapEditorConsole.swift
//  Feudalism
//
//  Konzola u Map Editoru – ispis poruka (selector, hit test, stanje). Uvijek se ispisuje kad je editor otvoren.
//

import Foundation
import SwiftUI

@MainActor
final class MapEditorConsole: ObservableObject {
    static let shared = MapEditorConsole()

    @Published private(set) var lines: [String] = []
    private let maxLines = 400
    private let dateFormatter: DateFormatter

    private init() {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        dateFormatter = df
    }

    /// Dodaj red u konzolu (poziva se iz Map Editora i SceneKit coordinatora).
    func append(_ message: String) {
        let ts = dateFormatter.string(from: Date())
        lines.append("[\(ts)] \(message)")
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func clear() {
        lines.removeAll(keepingCapacity: true)
    }
}
