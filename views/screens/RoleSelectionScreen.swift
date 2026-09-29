// RoleSelectionScreen.swift

import SwiftUI

struct RoleSelectionScreen: View {
    var onHomeownerSelected: () -> Void
    var onTeenCreateBusinessSelected: () -> Void
    var onTeenJoinOrganizationSelected: () -> Void
    var onSupervisorSelected: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("Select Your Role")
                .font(.title)
                .bold()
            
            Button(action: onHomeownerSelected) {
                Text("Homeowner")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(Color("BGColor"))
                    .cornerRadius(10)
            }
            
            // Teen Worker: Two distinct options
            VStack(spacing: 10) {
                Button("Create a New Business") {
                    onTeenCreateBusinessSelected()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(Color("BGColor"))
                .cornerRadius(10)

                Button("Join an Existing Organization") {
                    onTeenJoinOrganizationSelected()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(Color("BGColor"))
                .cornerRadius(10)
            }

            Button(action: onSupervisorSelected) {
                Text("Supervisor")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(Color("BGColor"))
                    .cornerRadius(10)
            }
        }
        .padding()
        .applyAppBackground()
    }
}
