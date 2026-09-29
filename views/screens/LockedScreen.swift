// LockedScreen.swift

import SwiftUI

struct LockedScreen: View {
    var reason: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)

            Text("Access Restricted")
                .font(.title2)
                .bold()
            
            Divider()

            Text("This section is locked unless you are part of a registered business.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Text(reason)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            NavigationLink(destination: ActiveJobsScreen()) {
                Label("View Active Jobs", systemImage: "briefcase.fill")
                    .buttonStyle(filled: .orange)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .navigationTitle("Locked")
        .navigationBarTitleDisplayMode(.inline)
        .applyAppBackground()
    }
}
