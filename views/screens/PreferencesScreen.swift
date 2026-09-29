// PreferencesScreen.swift

import SwiftUI

struct PreferencesScreen: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Toggle("Dark Mode", isOn: $isDarkMode)
            }

            // Add more sections if needed
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Preferences")
        .applyAppBackground()
    }
}
