// BusinessOnboardingScreen.swift

import SwiftUI
import FirebaseFirestore

struct BusinessOnboardingScreen: View {
    @State private var page = 0
    @State private var isSaving = false
    let business: BusinessModel
    var onComplete: () -> Void

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(0..<slides.count, id: \.self) { index in
                    VStack(spacing: 20) {
                        Text(slides[index].title)
                            .font(.title)
                            .bold()
                        Text(slides[index].description)
                            .multilineTextAlignment(.center)
                            .padding()
                        Image(systemName: slides[index].icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .padding()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle())

            HStack {
                Spacer()
                Button {
                    if page < slides.count - 1 {
                        withAnimation {
                            page += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .padding()
                    } else {
                        Text(page == slides.count - 1 ? "Continue" : "Next")
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(Color("BGColor"))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(.top)
        }
        .padding(.vertical)
        .applyAppBackground()
    }

    let slides: [BusinessOnboardingSlide] = [
        .init(title: "Welcome to Your Business!", description: "Set up your teen-led yard service with ease.", icon: "briefcase.fill"),
        .init(title: "Add Services", description: "Let homeowners know what you offer and your prices.", icon: "wrench.and.screwdriver"),
        .init(title: "Manage Jobs", description: "Track bookings, availability, and performance metrics.", icon: "chart.bar")
    ]

    private func completeOnboarding() {
        guard let businessID = business.id else { return }
        isSaving = true

        Firestore.firestore().collection("businesses").document(businessID).updateData([
            "hasCompletedOnboarding": true
        ]) { error in
            isSaving = false
            if error == nil {
                onComplete()
            } else {
                print("Failed to complete onboarding: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

struct BusinessOnboardingSlide {
    let title: String
    let description: String
    let icon: String
}
