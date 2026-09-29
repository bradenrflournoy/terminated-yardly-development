// OnboardingCoordinatorScreen.swift

import SwiftUI
import FirebaseFirestore

enum OnboardingStage {
    case welcome
    case roleSelection
    case profileSetup
}

struct OnboardingCoordinatorScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var stage: OnboardingStage = .welcome
    @State private var selectedRole: UserRole? = nil
    @State private var joiningBusiness = false

    var body: some View {
        Group {
            switch stage {
            case .welcome:
                OnboardingScreen {
                    stage = .roleSelection
                }

            case .roleSelection:
                RoleSelectionScreen(
                    onHomeownerSelected: {
                        selectedRole = .homeowner
                        Task {
                            await authVM.updateUserRole(to: .homeowner)
                            stage = .profileSetup
                        }
                    },
                    onTeenCreateBusinessSelected: {
                        selectedRole = .teen
                        joiningBusiness = false
                        Task {
                            await authVM.updateUserRole(to: .teen)
                            stage = .profileSetup
                        }
                    },
                    onTeenJoinOrganizationSelected: {
                        selectedRole = .teen
                        joiningBusiness = true
                        Task {
                            await authVM.updateUserRole(to: .teen)
                            stage = .profileSetup
                        }
                    },
                    onSupervisorSelected: {
                        selectedRole = .supervisor
                        Task {
                            await authVM.updateUserRole(to: .supervisor)
                            stage = .profileSetup
                        }
                    }
                )

            case .profileSetup:
                NavigationStack {
                    ProfileSetupScreen(
                        userRole: selectedRole ?? .teen,
                        joiningBusiness: joiningBusiness,
                        onComplete: {
                            Task {
                                if let userID = authVM.currentUser?.id {
                                    do {
                                        try await Firestore.firestore().collection("users").document(userID).updateData([
                                            "onboardingComplete": true
                                        ])
                                        if var user = authVM.currentUser {
                                            user.onboardingComplete = true
                                            authVM.currentUser = user
                                        }
                                    } catch {
                                        print("Failed to update onboarding flag: \(error.localizedDescription)")
                                    }
                                }
                            }
                        },
                        onBack: {
                            stage = .roleSelection // This allows back button to work
                        }
                    )
                }
            }
        }
        .applyAppBackground()
    }
}
