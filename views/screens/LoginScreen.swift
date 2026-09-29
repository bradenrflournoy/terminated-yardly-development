// LoginScreen.swift

import SwiftUI

struct LoginScreen: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showSignUp = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text(showSignUp ? "Sign Up" : "Login")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            if showSignUp {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            Button(showSignUp ? "Create Account" : "Log In") {
                Task {
                    if showSignUp {
                        if let validationError = validatePassword(password) {
                            errorMessage = validationError
                            return
                        }
                        do {
                            try await authVM.signUp(email: email, password: password, name: name)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    } else {
                        do {
                            try await authVM.signIn(email: email, password: password)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .padding()
            .background(Color.accentColor)
            .foregroundColor(Color("BGColor"))
            .clipShape(Capsule())

            Button(showSignUp ? "Already have an account? Log in" : "Don't have an account? Sign up") {
                showSignUp.toggle()
                errorMessage = nil
            }
            .font(.footnote)
        }
        .padding()
        .applyAppBackground()
    }

    private func validatePassword(_ password: String) -> String? {
        if password.count < 8 {
            return "Password must be at least 8 characters."
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            return "Password must include at least one uppercase letter."
        }
        if password.rangeOfCharacter(from: .lowercaseLetters) == nil {
            return "Password must include at least one lowercase letter."
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            return "Password must include at least one number."
        }
        return nil
    }
}
