import MapKit
import SwiftUI

struct ChaptersView: View {
    let chapters: [LifeChapter]
    var onSelectChapter: ((LifeChapter) -> Void)?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        if chapters.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chapters) { chapter in
                        ChapterCard(
                            chapter: chapter,
                            dateFormatter: dateFormatter
                        )
                        .onTapGesture {
                            onSelectChapter?(chapter)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Chapter Card

struct ChapterCard: View {
    let chapter: LifeChapter
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = chapter.label {
                Text(label)
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Text(dateRange)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if chapter.changeScore > 0 {
                Text("\(String(format: "%.0f", chapter.changeScore / 1000))km shift")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private var dateRange: String {
        let start = dateFormatter.string(from: chapter.startsAt)
        if let end = chapter.endsAt {
            return "\(start) — \(dateFormatter.string(from: end))"
        }
        return "\(start) — Now"
    }
}
