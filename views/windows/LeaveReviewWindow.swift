// LeaveReviewWindow.swift

import SwiftUI
import FirebaseFirestore

struct LeaveReviewWindow: View {
    let businessID: String
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var communicationRating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var hasReviewed = false
    @State private var message: String? = nil

    private let firestoreService = FirestoreService()

    var body: some View {
        VStack(spacing: 16) {
            Text("Leave a Review")
                .font(.title2)
                .bold()

            if hasReviewed {
                Text("You've already submitted a review for this business.")
                    .foregroundColor(.red)
            } else {
                // Public Rating
                VStack(spacing: 8) {
                    Text("Overall Rating")
                        .font(.headline)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    rating = star
                                }
                        }
                    }
                }

                // Communication Rating
                VStack(spacing: 8) {
                    Text("Communication Rating")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= communicationRating ? "star.fill" : "star")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    communicationRating = star
                                }
                        }
                    }
                }

                TextField("Write a comment (optional)...", text: $comment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)

                if let message = message {
                    Text(message)
                        .foregroundColor(message.contains("success") ? .green : .red)
                }

                Button(action: submitReview) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit Review")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(Color("BGColor"))
                            .cornerRadius(10)
                    }
                }
            }

            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: 400)
        .task {
            await checkIfReviewed()
        }
    }

    private func checkIfReviewed() async {
        guard let userID = authVM.currentUser?.id else { return }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("reviews")
                .whereField("reviewerID", isEqualTo: userID)
                .whereField("businessID", isEqualTo: businessID)
                .getDocuments()
            hasReviewed = !snapshot.documents.isEmpty
        } catch {
            print("Error checking for existing review: \(error.localizedDescription)")
        }
    }

    private func submitReview() {
        guard let reviewerID = authVM.currentUser?.id, rating > 0, communicationRating > 0 else {
            message = "Please select both a business rating and a communication rating."
            return
        }

        isSubmitting = true

        let review = ReviewModel(
            id: nil,
            reviewerID: reviewerID,
            businessID: businessID,
            rating: rating,
            communicationRating: communicationRating,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: Date()
        )

        Task {
            do {
                try await firestoreService.leaveReview(review)
                message = "Review submitted successfully."
                dismiss()
            } catch {
                message = "Failed to submit review."
            }
            isSubmitting = false
        }
    }
}
