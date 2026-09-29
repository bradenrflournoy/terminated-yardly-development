// TermsOfServiceWindow.swift

import SwiftUI

struct TermsOfServiceWindow: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Terms of Service")
                        .font(.title2)
                        .bold()

                    Group {
                        Text("Effective Date: January 18, 2025")
                        Text("Last Updated: January 18, 2025")
                        Text("""
                        Welcome to Yardly ("we," "us," or "our"). These Terms of Service ("Terms") govern your use of our website and services. By accessing or using our website, you agree to be bound by these Terms. If you do not agree with these Terms, please refrain from using our website and services.
                        """)
                    }

                    Group {
                        Text("1. Use of the Website")
                            .font(.headline)
                        Text("By accessing or using our website, you agree to the following:")
                        Text("• You will use the website only for lawful purposes and in compliance with all applicable laws and regulations.")
                        Text("• You will not use the website to distribute spam, malware, or any harmful or unauthorized content.")
                        Text("• You will not attempt to interfere with the operation or security of the website.")
                    }

                    Group {
                        Text("2. Intellectual Property")
                            .font(.headline)
                        Text("All content, trademarks, logos, and other intellectual property displayed on the website are the property of Yardly or its respective owners. You may not copy, modify, distribute, or use any of the content for commercial purposes without our prior written consent.")
                    }

                    Group {
                        Text("3. Limitation of Liability")
                            .font(.headline)
                        Text("To the fullest extent permitted by law, Yardly is not liable for any damages arising from your use of our website or services, including but not limited to direct, indirect, incidental, punitive, or consequential damages.")
                        Text("This limitation of liability applies to any loss or damage caused by errors, interruptions, or inaccuracies in our services, as well as unauthorized access to your data or information.")
                    }

                    Group {
                        Text("4. User-Generated Content")
                            .font(.headline)
                        Text("By submitting any content to our website, such as messages or feedback, you grant Yardly a non-exclusive, royalty-free, perpetual, and worldwide license to use, modify, reproduce, and distribute your content as necessary for the operation of the website and services.")
                        Text("You are solely responsible for the content you submit and agree not to post any content that is unlawful, harmful, or infringes on the rights of others.")
                    }

                    Group {
                        Text("5. Modifications to the Website and Services")
                            .font(.headline)
                        Text("We reserve the right to modify, suspend, or discontinue our website and services at any time without notice. Yardly is not liable for any disruption or unavailability of the website or services.")
                    }

                    Group {
                        Text("6. Updates to the Terms")
                            .font(.headline)
                        Text("We reserve the right to update these Terms at any time. When we make changes, we will revise the \"Effective Date\" at the top of this page. It is your responsibility to review these Terms periodically to stay informed about any updates.")
                    }

                    Group {
                        Text("7. Governing Law")
                            .font(.headline)
                        Text("These Terms are governed by and construed in accordance with the laws of [Insert Your State/Country], without regard to its conflict of law principles.")
                    }

                    Group {
                        Text("8. Contact Us")
                            .font(.headline)
                        Text("If you have any questions about these Terms or require assistance, please visit the \"Contact Us\" section of the account tab to get in touch.")
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
        }
    }
}
