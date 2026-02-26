//
//  SoloMapChoiceView.swift
//  Feudalism
//
//  Komponenta odabira mape za solo mode: crni prikaz (širi se s veličinom),
//  lista mapa (gore/dole) ili Učitaj/Generiraj + opcije proceduralne. Veličina (200–1000) bira se u donjem baru.
//

import SwiftUI

/// Objekt za odabir mape u solo modu. Uključuje se u SoloSetupView.
/// Odgovoran za: prikaz crnog elementa (animirana veličina), lista mapa iz kataloga
/// ili Učitaj/Generiraj + opcije proceduralne generacije. Veličina se bira u donjem baru SoloSetupView.
struct SoloMapChoiceView: View {
    @EnvironmentObject private var gameState: GameState

    @Binding var selectedMapSize: MapSizePreset
    @Binding var selectedMapIndex: Int
    @Binding var selectedMapType: SoloMapType
    @Binding var randomVegetacija: Bool
    @Binding var randomRadnaPozicija: Bool
    @Binding var randomRijeke: Bool
    @Binding var randomOscilacijeTerena: Bool
    @Binding var randomZemlje: Bool

    /// Proporcionalna veličina: 200→najmanje, 1000→najveće; od 8 do 10 simetričnije (veći korak).
    private static let sizeAt200: CGFloat = 120
    private static let sizeAt800: CGFloat = 310
    private static let sizeAt1000: CGFloat = 400
    private var previewSideBase: CGFloat {
        let s = selectedMapSize.side
        if s <= 800 {
            return Self.sizeAt200 + CGFloat(s - 200) * (Self.sizeAt800 - Self.sizeAt200) / 600
        } else {
            return Self.sizeAt800 + CGFloat(s - 800) * (Self.sizeAt1000 - Self.sizeAt800) / 200
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Jedan red: uvijek jedan centriran element; ako ima mapa – trenutna u sredini, ostale lijevo/desno; ako nema – "Nema mapa"
            centralMapRow
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if mapsForSize.isEmpty, selectedMapType == .procedural {
                proceduralOptionsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mapsForSize: [MapCatalogEntry] {
        MapCatalog.entries(forSide: selectedMapSize.side)
    }

    // MARK: - Jedan element za prikaz: kad ima mapa – kartice; kad nema – samo tekst "Nema mapa" (bez zamjene layouta)
    private static let mapCoverFlowRotation: Double = 14
    private static let mapCoverFlowScaleStep: CGFloat = 0.08
    private static let sizeChangeAnimation: Animation = .easeInOut(duration: 0.38)
    private static let cardSwitchAnimation: Animation = .easeInOut(duration: 0.34)
    /// Nježna tranzicija kad se sadržaj mijenja: nema mapa ↔ kartice, donji bar
    private static let contentCrossfadeAnimation: Animation = .easeInOut(duration: 0.32)

    private var centralMapRow: some View {
        GeometryReader { geo in
            let centralSide = min(
                previewSideBase,
                geo.size.width * 0.65,
                geo.size.height * 0.65
            )
            let count = mapsForSize.count
            let safeIndex = count > 0 ? min(max(0, selectedMapIndex % count), count - 1) : 0
            let sideCard = centralSide * 0.5
            let spacing = max(8, centralSide * 0.06)

            ZStack {
                // Kad nema mapa: samo tekst u istom elementu
                if count == 0 {
                    centralCard(content: Text("Nema mapa").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.8)), side: centralSide)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
                // Kad ima mapa: kartice
                if count > 0 {
                    HStack(spacing: spacing) {
                        ForEach(Array(mapsForSize.enumerated()), id: \.element.id) { index, entry in
                            let isCenter = index == safeIndex
                            centralCard(
                                content: VStack(spacing: 4) {
                                    Text(entry.displayName)
                                        .font(.system(size: isCenter ? 15 : 12, weight: .medium))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text("\(entry.side)×\(entry.side)")
                                        .font(.system(size: isCenter ? 13 : 10, weight: .regular))
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                                .foregroundStyle(.white.opacity(isCenter ? 0.95 : 0.7))
                                .multilineTextAlignment(.center)
                                .padding(8),
                                side: isCenter ? centralSide : sideCard
                            )
                            .rotation3DEffect(
                                .degrees(count > 1 ? Double(index - safeIndex) * Self.mapCoverFlowRotation : 0),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.4
                            )
                            .scaleEffect(count > 1 ? scaleForCoverFlow(offset: index - safeIndex) : 1)
                            .onTapGesture {
                                withAnimation(Self.cardSwitchAnimation) { selectedMapIndex = index }
                            }
                        }
                    }
                    .frame(width: totalRowWidth(count: count, centralSide: centralSide, sideCard: sideCard, spacing: spacing))
                    .offset(x: totalRowWidth(count: count, centralSide: centralSide, sideCard: sideCard, spacing: spacing) / 2 - centerX(count: count, safeIndex: safeIndex, centralSide: centralSide, sideCard: sideCard, spacing: spacing))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(Self.cardSwitchAnimation, value: safeIndex)
                    .animation(Self.sizeChangeAnimation, value: selectedMapSize)
                    .transition(.opacity)
                }
            }
            .animation(Self.contentCrossfadeAnimation, value: count)
        }
        .frame(maxHeight: 520)
        .clipped()
    }

    private func totalRowWidth(count: Int, centralSide: CGFloat, sideCard: CGFloat, spacing: CGFloat) -> CGFloat {
        guard count > 0 else { return centralSide }
        return CGFloat(count - 1) * spacing + centralSide + CGFloat(count - 1) * sideCard
    }

    /// Udaljenost od lijevog ruba reda do sredine odabrane kartice (da je centriramo u ekranu).
    private func centerX(count: Int, safeIndex: Int, centralSide: CGFloat, sideCard: CGFloat, spacing: CGFloat) -> CGFloat {
        guard count > 0 else { return centralSide / 2 }
        return CGFloat(safeIndex) * (sideCard + spacing) + centralSide / 2
    }

    private func centralCard<Content: View>(content: Content, side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .frame(width: side, height: side)
            content
        }
        .frame(width: side, height: side)
    }

    private func scaleForCoverFlow(offset: Int) -> CGFloat {
        max(0.72, 1.0 - CGFloat(abs(offset)) * Self.mapCoverFlowScaleStep)
    }

    // MARK: - Učitaj (Level) | Generiraj (proceduralna) – kad nema mapa u folderu
    private var loadOrGenerateContent: some View {
        HStack(spacing: 10) {
            Button {
                selectedMapType = .level
            } label: {
                Text(LocalizedStrings.string(for: "solo_map_load", language: gameState.appLanguage))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selectedMapType == .level ? .white : .white.opacity(0.6))
                    .frame(minWidth: 80, minHeight: 44)
                    .background(selectedMapType == .level ? Color.green.opacity(0.9) : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            Button {
                selectedMapType = .procedural
            } label: {
                Text(LocalizedStrings.string(for: "solo_map_generate", language: gameState.appLanguage))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selectedMapType == .procedural ? .white : .white.opacity(0.6))
                    .frame(minWidth: 80, minHeight: 44)
                    .background(selectedMapType == .procedural ? Color.green.opacity(0.9) : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Opcije proceduralne generacije
    private var proceduralOptionsContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                genOptionButton(title: "Random vegetacija", isOn: $randomVegetacija)
                genOptionButton(title: "Random radna pozicija", isOn: $randomRadnaPozicija)
                genOptionButton(title: "Random rijeke", isOn: $randomRijeke)
            }
            HStack(spacing: 8) {
                genOptionButton(title: "Random oscilacije terena", isOn: $randomOscilacijeTerena)
                genOptionButton(title: "Random zemlje", isOn: $randomZemlje)
            }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func genOptionButton(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isOn.wrappedValue ? .white : .white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn.wrappedValue ? Color.green.opacity(0.85) : Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
