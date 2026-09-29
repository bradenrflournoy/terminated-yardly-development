// ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let user = authVM.currentUser {
                if user.onboardingComplete {
                    MainTabScreen()
                } else {
                    OnboardingCoordinatorScreen()
                }
            } else {
                LoginScreen()
            }
        }
        .environmentObject(authVM) // apply to all branches
    }
}
