import SwiftUI

struct TraderDetailReviewsTab: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            HStack {
                Text("Investor Reviews")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()

                Button("Write Review") {
                    // TODO: Show review form
                }
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.accentLightBlue)
            }

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(mockReviews) { review in
                    ReviewRow(review: review)
                }
            }
        }
    }
}

struct ReviewRow: View {
    let review: MockReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.investorName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < review.rating ? "star.fill" : "star")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentOrange)
                    }
                }
            }

            Text(review.comment)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)

            Text(review.date.formatted(date: .abbreviated, time: .omitted))
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Mock Data

struct MockReview: Identifiable {
    let id = UUID()
    let investorName: String
    let rating: Int
    let comment: String
    let date: Date
}

let mockReviews = [
    MockReview(investorName: "Alice Johnson", rating: 5, comment: "Excellent trader with consistent returns. Highly recommended!", date: Date().addingTimeInterval(-86400)),
    MockReview(investorName: "Bob Smith", rating: 4, comment: "Good performance, but sometimes takes high risks.", date: Date().addingTimeInterval(-172800)),
    MockReview(investorName: "Carol Davis", rating: 5, comment: "Best trader I've worked with. Clear communication and great results.", date: Date().addingTimeInterval(-259200))
]

#Preview {
    TraderDetailReviewsTab()
        .padding()
        .background(AppTheme.screenBackground)
}
