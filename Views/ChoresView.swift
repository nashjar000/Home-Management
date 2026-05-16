//
//  ChoresView.swift
//  Home Management
//
//  Created by Jared Nash on 1/22/26.
//
import SwiftUI

struct ChoresView: View {
    var body: some View {
        NavigationStack {
            ChoresListView()
        }
    }
}

#Preview {
    NavigationStack { ChoresListView() }
}
