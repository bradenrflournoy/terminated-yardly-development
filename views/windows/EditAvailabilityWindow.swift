// EditAvailabilityWindow.swift

import SwiftUI
import FirebaseFirestore

struct EditAvailabilityWindow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    let predefinedSlots = ["9am–12pm", "12pm–3pm", "3pm–6pm", "6pm–9pm"]

    @State private var selectedDays: Set<String> = []
    @State private var selectedTimeRanges: [String: Set<String>] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let firestore = Firestore.firestore()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Available Days")) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Toggle(day, isOn: Binding(
                            get: { selectedDays.contains(day) },
                            set: { isOn in
                                if isOn {
                                    selectedDays.insert(day)
                                    if selectedTimeRanges[day] == nil {
                                        selectedTimeRanges[day] = []
                                    }
                                } else {
                                    selectedDays.remove(day)
                                    selectedTimeRanges[day] = nil
                                }
                            }
                        ))
                    }
                }

                ForEach(daysOfWeek.filter { selectedDays.contains($0) }, id: \.self) { day in
                    Section(header: Text("\(day) Time Ranges")) {
                        ForEach(predefinedSlots, id: \.self) { slot in
                            Toggle(slot, isOn: Binding(
                                get: { selectedTimeRanges[day, default: []].contains(slot) },
                                set: { isOn in
                                    if isOn {
                                        selectedTimeRanges[day, default: []].insert(slot)
                                    } else {
                                        selectedTimeRanges[day]?.remove(slot)
                                    }
                                }
                            ))
                        }
                    }
                }

                if isSaving {
                    ProgressView("Saving...")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Availability")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    Task {
                        await saveAvailability()
                    }
                }
                .disabled(selectedDays.isEmpty)
            )
        }
        .onAppear {
            Task {
                await loadAvailability()
            }
        }
    }

    private func loadAvailability() async {
        guard let businessID = authVM.currentUser?.businessID else { return }
        do {
            let doc = try await firestore.collection("businesses").document(businessID).getDocument()
            if let data = doc.data(),
               let slots = data["availability"] as? [[String: Any]] {
                for slot in slots {
                    if let day = slot["day"] as? String {
                        selectedDays.insert(day)
                        let ranges = slot["timeRanges"] as? [String] ?? []
                        selectedTimeRanges[day] = Set(ranges)
                    }
                }
            }
        } catch {
            print("Error loading availability: \(error.localizedDescription)")
        }
    }

    private func saveAvailability() async {
        guard let businessID = authVM.currentUser?.businessID else { return }
        isSaving = true

        let availability: [[String: Any]] = selectedDays.sorted().map { day in
            let ranges = Array(selectedTimeRanges[day] ?? [])
            return ["day": day, "timeRanges": ranges]
        }

        if availability.allSatisfy({ ($0["timeRanges"] as? [String])?.isEmpty ?? true }) {
            print("Please select at least one time range.")
            isSaving = false
            return
        }

        do {
            try await firestore.collection("businesses").document(businessID).updateData([
                "availability": availability
            ])
            dismiss()
        } catch {
            errorMessage = "Failed to save availability. Please try again."
            print("Error saving availability: \(error.localizedDescription)")
        }

        isSaving = false
    }
}
