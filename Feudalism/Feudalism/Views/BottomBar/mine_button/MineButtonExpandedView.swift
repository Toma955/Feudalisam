//
//  MineButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Rudnik (industrija): lager, stump (drvo), iron_mine (željezo), stone_mine (kamen), carriage.
//

import SwiftUI

private let industryColumnWidth: CGFloat = 48

struct MineButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectLager: () -> Void
    var onSelectStump: () -> Void
    var onSelectIronMine: () -> Void
    var onSelectStoneMine: () -> Void
    var onSelectCarriage: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 22) {
                industryButton(assetName: "lager", systemName: "building.2.fill", action: onSelectLager)
                industryButton(assetName: "stump", systemName: "leaf.fill", action: onSelectStump)
                industryButton(assetName: "iron_mine", systemName: "cube.fill", action: onSelectIronMine)
                industryButton(assetName: "stone_mine", systemName: "mountain.2.fill", action: onSelectStoneMine)
                industryButton(assetName: "carriage", systemName: "cart.fill", action: onSelectCarriage)
            }
            HStack(spacing: 22) {
                industryLabel("industry_lager").frame(width: industryColumnWidth, alignment: .center)
                industryLabel("industry_wood").frame(width: industryColumnWidth, alignment: .center)
                industryLabel("industry_iron").frame(width: industryColumnWidth, alignment: .center)
                industryLabel("industry_stone").frame(width: industryColumnWidth, alignment: .center)
                industryLabel("industry_carriage").frame(width: industryColumnWidth, alignment: .center)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func industryButton(assetName: String, systemName: String, action: @escaping () -> Void) -> some View {
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
            .frame(width: industryColumnWidth, height: industryColumnWidth)
            .foregroundStyle(.white.opacity(0.95))
        }
        .buttonStyle(.plain)
    }

    private func industryLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
