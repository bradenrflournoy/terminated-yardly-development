// YardlyApp.swift

import SwiftUI
import FirebaseCore

@main
struct YardlyApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView() // from views/screens/
                .accentColor(Color("AccentColor"))
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
