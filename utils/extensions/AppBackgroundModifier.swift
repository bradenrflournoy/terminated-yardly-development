// AppBackgroundModifier

import SwiftUI

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color("BGColor")
            content
        }
    }
}

extension View {
    func applyAppBackground() -> some View {
        self.modifier(AppBackgroundModifier())
    }
}
