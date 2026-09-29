// FAQWindow.swift

import SwiftUI

struct FAQWindow: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Frequently Asked Questions")
                        .font(.title2)
                        .bold()

                    Group {
                        Text("**Q: How do I book a service?**")
                        Text("A: Navigate to the Home tab, choose a service, and follow the prompts.")

                        Text("**Q: How do I cancel a booking?**")
                        Text("A: Go to the Active Jobs section and swipe left on a job to cancel.")

                        Text("**Q: How can I contact my service provider?**")
                        Text("A: Use the Messages tab to chat directly with your business.")
                    }
                    .font(.body)
                    .padding(.bottom, 8)
                }
                .padding()
            }
            .navigationTitle("FAQ")
        }
    }
}
