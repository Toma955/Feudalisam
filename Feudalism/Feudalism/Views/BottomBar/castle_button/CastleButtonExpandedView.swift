//
//  CastleButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Dvor: Zid, Tržnica, Oružarnica, Steps, Stairs, Trening, Vrata (medieval_gates), Staja (stable), Rudari (pickaxe), Inženjering (devider), Kule (towers), Most (drawbridge).
//

import SwiftUI

private let castleColumnWidth: CGFloat = 48

struct CastleButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectWall: () -> Void
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
        VStack(spacing: 4) {
            HStack(spacing: 14) {
                castleButton(assetName: "wall", systemName: "rectangle.3.group", action: onSelectWall)
                castleButton(assetName: "market", systemName: "cart.fill", action: onSelectMarket)
                castleButton(assetName: "armory", systemName: "shield.fill", action: onSelectArmory)
                castleButton(assetName: "steps", systemName: "square.stack.3d.up.fill", action: onSelectSteps)
                castleButton(assetName: "stairs", systemName: "stairs", action: onSelectStairs)
                castleButton(assetName: "knight", systemName: "figure.boxing", action: onSelectTraining)
                castleButton(assetName: "medieval_gates", systemName: "door.left.hand.open", action: onSelectGates)
                castleButton(assetName: "stable", systemName: "building.2.fill", action: onSelectStable)
                castleButton(assetName: "pickaxe", systemName: "hammer.fill", action: onSelectMiners)
                castleButton(assetName: "devider", systemName: "wrench.and.screwdriver.fill", action: onSelectEngineering)
                castleButton(assetName: "towers", systemName: "building.columns.fill", action: onSelectTowers)
                castleButton(assetName: "drawbridge", systemName: "rectangle.portrait.bottomhalf.filled", action: onSelectDrawbridge)
            }
            HStack(spacing: 14) {
                castleLabel("wall").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("market").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_armory").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_steps").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_stairs").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_training").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_gates").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_stable").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_miners").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_engineering").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_towers").frame(width: castleColumnWidth, alignment: .center)
                castleLabel("castle_drawbridge").frame(width: castleColumnWidth, alignment: .center)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func castleButton(assetName: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let img = loadBarIcon(named: assetName) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 28))
                }
            }
            .frame(width: castleColumnWidth, height: castleColumnWidth)
            .foregroundStyle(.white.opacity(0.95))
        }
        .buttonStyle(.plain)
    }

    private func castleLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
