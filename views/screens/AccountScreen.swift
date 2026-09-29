// AccountScreen.swift

import SwiftUI

struct AccountScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showFAQ = false
    @State private var showContact = false
    @State private var showTOS = false
    @State private var showPrivacy = false
    @State private var showLogoutConfirmation = false
    @State private var showPreferences = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let user = authVM.currentUser {
                        // Profile card
                        VStack(alignment: .leading, spacing: 10) {
                            if let imageURL = user.profileImageURL, let url = URL(string: imageURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                }
                            }

                            Text(user.name)
                                .font(.title2)
                                .bold()
                            Text(user.role.rawValue.capitalized)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        Divider()

                        // Role-specific actions
                        Group {
                            if user.role == .homeowner && user.pendingBusinessMembership != true {
                                NavigationLink(destination: BusinessSetupScreen().environmentObject(authVM)) {
                                    HStack {
                                        Image(systemName: "building.2")
                                            .foregroundColor(.accentColor)

                                        Text("Create or Join a Business")
                                            .foregroundColor(.primary)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                            }
                            
                            NavigationLink(destination: EditUserAndProfileScreen().environmentObject(authVM)) {
                                HStack {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.accentColor)

                                    Text("Edit User and Profile")
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }

                            NavigationLink(destination: JobHistoryScreen()) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.accentColor)

                                    Text("Job History")
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }

                            NavigationLink(destination: PreferencesScreen()) {
                                HStack {
                                    Image(systemName: "gearshape")
                                        .foregroundColor(.accentColor)

                                    Text("Preferences")
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal)

                        DisclosureGroup {
                            VStack(spacing: 12) {
                                Button {
                                    showContact = true
                                } label: {
                                    Text("Contact Us")
                                        .underline()
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.gray)
                                }
                                
                                Button {
                                    showFAQ = true
                                } label: {
                                    Text("FAQ")
                                        .underline()
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.gray)
                                }

                                Button {
                                    showTOS = true
                                } label: {
                                    Text("Terms of Service")
                                        .underline()
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.gray)
                                }

                                Button {
                                    showPrivacy = true
                                } label: {
                                    Text("Privacy Policy")
                                        .underline()
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.gray)
                                }
                            }
                        } label: {
                            Label {
                                Text("Resources")
                                    .foregroundColor(.primary) // Black/white depending on theme
                            } icon: {
                                Image(systemName: "book")
                                    .foregroundColor(Color("AccentColor")) // Green icon
                            }
                            .font(.headline)
                        }
                        .accentColor(.gray)
                        .padding(.horizontal)
                        
                        Button {
                            showLogoutConfirmation = true
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .background(Color(.systemGray6))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .confirmationDialog("Are you sure you want to log out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                            Button("Log Out", role: .destructive) {
                                do {
                                    try authVM.signOut()
                                } catch {
                                    print("Sign out failed: \(error.localizedDescription)")
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .applyAppBackground()
        }
        .sheet(isPresented: $showFAQ) {
            FAQWindow()
        }
        .sheet(isPresented: $showContact) {
            ContactUsWindow()
        }
        .sheet(isPresented: $showTOS) {
            TermsOfServiceWindow()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyWindow()
        }
    }
}
