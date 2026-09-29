// ReviewSummaryView.swift

import SwiftUI
import FirebaseFirestore

struct ReviewSummaryView: View {
    let businessID: String

    @State private var reviews: [ReviewModel] = []
    @State private var isLoading = true
    @State private var averageRating: Double? = nil

    var body: some View {
        VStack(spacing: 16) {
            Text("Customer Reviews")
                .font(.title2)
                .bold()

            if isLoading {
                ProgressView("Loading reviews...")
            } else if reviews.isEmpty {
                Text("No reviews yet.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                // Average Rating
                if let average = averageRating {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(round(average)) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                        }
                        Text(String(format: "%.1f", average))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("(\(reviews.count))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Scrollable Reviews
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(reviews.filter { !$0.comment.trimmingCharacters(in: .whitespaces).isEmpty }) { review in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                    }
                                }
                                Text(review.comment)
                                    .font(.body)
                                Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Divider()
                        }
                    }
                }
                .frame(height: 200) // Set desired scrollable height
            }
        }
        .padding()
        .task {
            await loadReviewsAndAverage()
        }
    }

    private func loadReviewsAndAverage() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("reviews")
                .whereField("businessID", isEqualTo: businessID)
                .order(by: "timestamp", descending: true)
                .getDocuments()

            let allReviews = snapshot.documents.compactMap { try? $0.data(as: ReviewModel.self) }

            reviews = allReviews

            let ratings = allReviews.map { Double($0.rating) }
            if !ratings.isEmpty {
                averageRating = ratings.reduce(0, +) / Double(ratings.count)
            }
        } catch {
            print("Error loading reviews: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
