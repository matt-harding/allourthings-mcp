import Foundation
import NaturalLanguage

// MARK: - Semantic Search Helper using NLEmbedding

class SemanticSearchHelper {
    static let shared = SemanticSearchHelper()
    private init() {}

    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    enum SearchError: Error {
        case embeddingNotAvailable
        case failedToGenerateEmbedding
    }

    // MARK: - Search Sections

    func searchSections(
        query: String,
        in sections: [ManualSection],
        maxResults: Int = 5,
        minSimilarity: Double = 0.2
    ) throws -> [ScoredSection] {
        guard let embedding = embedding else {
            throw SearchError.embeddingNotAvailable
        }

        guard let queryVector = embedding.vector(for: query) else {
            throw SearchError.failedToGenerateEmbedding
        }

        var scoredSections: [ScoredSection] = []

        for section in sections {
            // Create searchable text for section
            let sectionText = "\(section.heading) \(section.content.prefix(500))"

            guard let sectionVector = embedding.vector(for: sectionText) else {
                continue
            }

            // Calculate similarity
            let similarity = cosineSimilarity(queryVector, sectionVector)

            if similarity >= minSimilarity {
                scoredSections.append(ScoredSection(section: section, score: similarity))
            }
        }

        // Sort by similarity and take top results
        return scoredSections
            .sorted { $0.score > $1.score }
            .prefix(maxResults)
            .map { $0 }
    }

    // MARK: - Helper: Cosine Similarity

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }
}

// MARK: - Scored Results

struct ScoredSection {
    let section: ManualSection
    let score: Double

    var percentageScore: Double {
        score * 100
    }
}
