//
//  ChoresView.swift
//  Home Management
//
//  Created by Jared Nash on 1/22/26.
//
import SwiftUI

struct ChoresView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Chores")
                .font(.largeTitle)
                .bold()

            Text("Coming soon — chores module prototype next.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Chores")
    }
}

#Preview {
    NavigationStack { ChoresView() }
}
