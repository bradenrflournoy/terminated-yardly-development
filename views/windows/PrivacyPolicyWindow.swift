// PrivacyPolicyWindow.swift

import SwiftUI

struct PrivacyPolicyWindow: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .bold()

                    Group {
                        Text("Effective Date: January 18, 2025")
                        Text("Last Updated: January 18, 2025")

                        Text("Yardly (\"we,\" \"us,\" or \"our\") is currently a project under development by individuals, not yet registered as a formal business entity. We value your privacy and are committed to protecting any personal data you provide. This Privacy Policy outlines how we collect, use, disclose, and safeguard your information when you visit our website or interact with our services.")

                        Text("If you do not agree with the terms of this policy, please refrain from using our website.")
                    }

                    Group {
                        Text("1. Who We Are")
                            .font(.headline)
                        Text("Yardly is a pre-launch project developed by a group of individuals. While we are not a formally registered business, we are committed to handling your data responsibly and transparently. Should Yardly become a registered entity, this Privacy Policy will be updated to reflect that change.")
                    }

                    Group {
                        Text("2. Information We Collect")
                            .font(.headline)

                        Text("2.1. Information You Provide Directly")
                        Text("- Contact Form Submissions: Your name, email address, and message content when you use our contact form.")
                        Text("- Interest Form Submissions: Your email address and preferences when you sign up for updates and early access.")

                        Text("2.2. Automatically Collected Information")
                        Text("- Usage Data: Your IP address, browser type, operating system, referring URLs, and pages viewed.")
                        Text("- Cookies and Tracking Technologies: Small data files stored on your device to track activity and improve user experience.")
                    }

                    Group {
                        Text("3. How We Use Your Information")
                            .font(.headline)
                        Text("We use the information we collect for the following purposes:")
                        Text("- To respond to inquiries submitted via the contact form.")
                        Text("- To send updates, news, and launch announcements for Yardly.")
                        Text("- To improve our website functionality and user experience.")
                    }

                    Group {
                        Text("4. Data Responsibility")
                            .font(.headline)
                        Text("As a non-registered project, your data is handled securely and only by the individuals directly involved in developing Yardly. We do not share your information with external entities unless legally required to do so.")
                    }

                    Group {
                        Text("5. Your Rights")
                            .font(.headline)
                        Text("As this is a pre-launch project, you still have rights over your data:")
                        Text("- Access and Correction: Request a copy of the data we have collected and correct inaccuracies.")
                        Text("- Erasure: Request the deletion of your personal data.")
                        Text("To exercise these rights, please navigate to the \"Contact Us\" section on our website and submit your request using the provided form.")
                    }

                    Group {
                        Text("6. Data Security")
                            .font(.headline)
                        Text("We implement industry-standard measures to protect your data. However, no method of transmission or storage is completely secure. While we strive to protect your personal information, we cannot guarantee absolute security.")
                    }

                    Group {
                        Text("7. Updates to This Privacy Policy")
                            .font(.headline)
                        Text("As Yardly develops into a registered business, this Privacy Policy will be updated to reflect the new structure. Updates will be posted on this page with a revised \"Effective Date.\" We encourage you to review this policy periodically.")
                    }

                    Group {
                        Text("8. Contact Us")
                            .font(.headline)
                        Text("If you have any questions or concerns about this Privacy Policy, please visit the \"Contact Us\" section of the account tab to get in touch with us.")
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
        }
    }
}
