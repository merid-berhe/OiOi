//
//  ContentView.swift
//  OiOi
//
//  Created by Merid Berhe on 10.04.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = UserViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                } else if let user = viewModel.currentUser {
                    Text("Welcome, \(user.name)!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(user.email)
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                } else {
                    Text("Welcome to OiOi")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Button("Load User") {
                        viewModel.fetchUser()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Home")
        }
        .onAppear {
            viewModel.fetchUser()
        }
    }
}

#Preview {
    ContentView()
}
