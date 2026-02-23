//
//  CastleButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Dvor u donjem izborniku (samo red s gumbima; „nazad” dodaje parent).
//

import SwiftUI

struct CastleButtonExpandedView: View {
    var onSelectWall: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WallBarButtonView(action: onSelectWall)
        }
    }
}
