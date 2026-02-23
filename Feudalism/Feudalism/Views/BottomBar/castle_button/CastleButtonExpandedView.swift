//
//  CastleButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Dvor u donjem izborniku: Zid, Market („nazad” dodaje parent).
//

import SwiftUI

struct CastleButtonExpandedView: View {
    var onSelectWall: () -> Void
    var onSelectMarket: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WallBarButtonView(action: onSelectWall)
            MarketBarButtonView(action: onSelectMarket)
        }
    }
}
