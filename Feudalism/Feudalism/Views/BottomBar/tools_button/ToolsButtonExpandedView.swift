//
//  ToolsButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Alati: Sword, Mace, Report, Shovel, Pen. Koristi CategoryExpandedView s highlightom.
//

import SwiftUI

struct ToolsButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var selectedToolId: String?
    var onSelectSword: () -> Void
    var onSelectMace: () -> Void
    var onSelectReport: () -> Void
    var onSelectShovel: () -> Void
    var onSelectPen: () -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "sword_icon", systemName: "crossed.swords", labelKey: "tools_sword", action: onSelectSword, isHighlighted: selectedToolId == "sword", highlightColor: .green),
            CategoryExpandedItem(assetName: "mace", systemName: "hammer.fill", labelKey: "tools_mace", action: onSelectMace, isHighlighted: selectedToolId == "mace", highlightColor: .red),
            CategoryExpandedItem(assetName: "report", systemName: "doc.text.fill", labelKey: "tools_report", action: onSelectReport, isHighlighted: selectedToolId == "report", highlightColor: .green),
            CategoryExpandedItem(assetName: "shovel", systemName: "square.fill", labelKey: "tools_shovel", action: onSelectShovel, isHighlighted: selectedToolId == "shovel", highlightColor: .green),
            CategoryExpandedItem(assetName: "pen", systemName: "pencil", labelKey: "tools_pen", action: onSelectPen, isHighlighted: selectedToolId == "pen", highlightColor: .green),
        ])
    }
}
