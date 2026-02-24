//
//  CastleButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Dvor: Zid, Tržnica, Oružarnica, … Koristi CategoryExpandedView.
//

import SwiftUI

struct CastleButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectWall: () -> Void
    var onSelectSmallWall: () -> Void
    var onSelectMarket: () -> Void
    var onSelectArmory: () -> Void
    var onSelectSteps: () -> Void
    var onSelectStairs: () -> Void
    var onSelectTraining: () -> Void
    var onSelectGates: () -> Void
    var onSelectStable: () -> Void
    var onSelectMiners: () -> Void
    var onSelectEngineering: () -> Void
    var onSelectTowers: () -> Void
    var onSelectDrawbridge: () -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "wall", systemName: "rectangle.3.group", labelKey: "huge_wall", action: onSelectWall),
            CategoryExpandedItem(assetName: "wall", systemName: "rectangle.3.group", labelKey: "wall_small", action: onSelectSmallWall),
            CategoryExpandedItem(assetName: "market", systemName: "cart.fill", labelKey: "market", action: onSelectMarket),
            CategoryExpandedItem(assetName: "armory", systemName: "shield.fill", labelKey: "castle_armory", action: onSelectArmory),
            CategoryExpandedItem(assetName: "steps", systemName: "square.stack.3d.up.fill", labelKey: "castle_steps", action: onSelectSteps),
            CategoryExpandedItem(assetName: "stairs", systemName: "stairs", labelKey: "castle_stairs", action: onSelectStairs),
            CategoryExpandedItem(assetName: "knight", systemName: "figure.boxing", labelKey: "castle_training", action: onSelectTraining),
            CategoryExpandedItem(assetName: "medieval_gates", systemName: "door.left.hand.open", labelKey: "castle_gates", action: onSelectGates),
            CategoryExpandedItem(assetName: "stable", systemName: "building.2.fill", labelKey: "castle_stable", action: onSelectStable),
            CategoryExpandedItem(assetName: "pickaxe", systemName: "hammer.fill", labelKey: "castle_miners", action: onSelectMiners),
            CategoryExpandedItem(assetName: "devider", systemName: "wrench.and.screwdriver.fill", labelKey: "castle_engineering", action: onSelectEngineering),
            CategoryExpandedItem(assetName: "towers", systemName: "building.columns.fill", labelKey: "castle_towers", action: onSelectTowers),
            CategoryExpandedItem(assetName: "drawbridge", systemName: "rectangle.portrait.bottomhalf.filled", labelKey: "castle_drawbridge", action: onSelectDrawbridge),
        ])
    }
}
