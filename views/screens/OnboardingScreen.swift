// OnboardingScreen.swift

import SwiftUI

struct OnboardingScreen: View {
    @State private var page = 0
    var onContinue: () -> Void

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
                if page < slides.count - 1 {
                    Button("Next") {
                        withAnimation {
                            page += 1
                        }
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(Color("BGColor"))
                    .clipShape(Capsule())
                } else {
                    Button("Continue") {
                        onContinue()
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(Color("BGColor"))
                    .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.top)
        }
        .padding(.vertical)
        .applyAppBackground()
    }

    let slides: [OnboardingSlide] = [
        .init(title: "Welcome to Yardly!", description: "A place for homeowners and teens to connect for yard work.", icon: "leaf.fill"),
        .init(title: "Create Your Profile", description: "Add a photo and some details to get started.", icon: "person.crop.circle.badge.plus"),
        .init(title: "Understand the Rules", description: "Teens must operate responsibly. Supervisors oversee accounts.", icon: "checkmark.seal")
    ]
}

struct OnboardingSlide {
    let title: String
    let description: String
    let icon: String
}
