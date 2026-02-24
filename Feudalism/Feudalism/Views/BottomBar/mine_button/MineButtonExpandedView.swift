//
//  MineButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Rudnik (industrija): lager, stump, iron_mine, stone_mine, carriage. Koristi CategoryExpandedView.
//

import SwiftUI

struct MineButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectLager: () -> Void
    var onSelectStump: () -> Void
    var onSelectIronMine: () -> Void
    var onSelectStoneMine: () -> Void
    var onSelectCarriage: () -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "lager", systemName: "building.2.fill", labelKey: "industry_lager", action: onSelectLager),
            CategoryExpandedItem(assetName: "stump", systemName: "leaf.fill", labelKey: "industry_wood", action: onSelectStump),
            CategoryExpandedItem(assetName: "iron_mine", systemName: "cube.fill", labelKey: "industry_iron", action: onSelectIronMine),
            CategoryExpandedItem(assetName: "stone_mine", systemName: "mountain.2.fill", labelKey: "industry_stone", action: onSelectStoneMine),
            CategoryExpandedItem(assetName: "carriage", systemName: "cart.fill", labelKey: "industry_carriage", action: onSelectCarriage),
        ])
    }
}
