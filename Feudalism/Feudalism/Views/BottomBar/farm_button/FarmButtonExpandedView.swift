//
//  FarmButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Farma: jedan red ikona, ispod jedan red natpisa.
//

import SwiftUI

private let columnWidth: CGFloat = 48
/// Visina ikona u proširenom izborniku (niska traka).
private let expandedIconSize: CGFloat = 34

struct FarmButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectAppleFarm: () -> Void
    var onSelectPigFarm: () -> Void
    var onSelectHayFarm: () -> Void
    var onSelectCowFarm: () -> Void
    var onSelectSheepFarm: () -> Void
    var onSelectWheatFarm: () -> Void
    var onSelectCornFarm: () -> Void
    var onSelectChickenFarm: () -> Void
    var onSelectVegetablesFarm: () -> Void
    var onSelectGrapesFarm: () -> Void
    var onSelectSpicesFarm: () -> Void
    var onSelectFlowerFarm: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Red ikona
            HStack(spacing: 14) {
                AppleFarmBarButtonView(action: onSelectAppleFarm, iconOnly: true, iconOnlySize: 40)
                    .frame(width: columnWidth, alignment: .center)
                WheatFarmBarButtonView(action: onSelectWheatFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                    .padding(.leading, 8)
                CornFarmBarButtonView(action: onSelectCornFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                HayFarmBarButtonView(action: onSelectHayFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                VegetablesFarmBarButtonView(action: onSelectVegetablesFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                GrapesFarmBarButtonView(action: onSelectGrapesFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                SpicesFarmBarButtonView(action: onSelectSpicesFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                FlowerFarmBarButtonView(action: onSelectFlowerFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 1, height: expandedIconSize)
                PigFarmBarButtonView(action: onSelectPigFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                CowFarmBarButtonView(action: onSelectCowFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                SheepFarmBarButtonView(action: onSelectSheepFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
                ChickenFarmBarButtonView(action: onSelectChickenFarm, iconOnly: true)
                    .frame(width: columnWidth, alignment: .center)
            }
            // Jedan red natpisa, malo dole
            HStack(spacing: 14) {
                farmLabel("apple_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("wheat_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("corn_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("resource_hop").frame(width: columnWidth, alignment: .center)
                farmLabel("vegetables_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("grapes_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("spices_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("flower_farm").frame(width: columnWidth, alignment: .center)
                Color.clear.frame(width: 1)
                farmLabel("pig_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("cow_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("sheep_farm").frame(width: columnWidth, alignment: .center)
                farmLabel("chicken_farm").frame(width: columnWidth, alignment: .center)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func farmLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
