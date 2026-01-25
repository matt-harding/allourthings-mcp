import Foundation
import NaturalLanguage

enum ManualTopic: String, CaseIterable, Hashable {
    case overview
    case safety
    case setupInstallation
    case operationControls
    case maintenanceCleaning
    case troubleshooting
    case specifications
    case partsAccessories
    case warrantySupport

    var displayName: String {
        switch self {
        case .overview:
            return "Overview"
        case .safety:
            return "Safety"
        case .setupInstallation:
            return "Setup & Installation"
        case .operationControls:
            return "Operation & Controls"
        case .maintenanceCleaning:
            return "Maintenance & Cleaning"
        case .troubleshooting:
            return "Troubleshooting"
        case .specifications:
            return "Specifications"
        case .partsAccessories:
            return "Parts & Accessories"
        case .warrantySupport:
            return "Warranty & Support"
        }
    }

    var matchText: String {
        switch self {
        case .overview:
            return "overview introduction product description features purpose"
        case .safety:
            return "safety warning caution hazard important instructions"
        case .setupInstallation:
            return "setup installation assembly mounting placement requirements"
        case .operationControls:
            return "operation controls usage settings modes buttons display"
        case .maintenanceCleaning:
            return "maintenance cleaning care storage service upkeep"
        case .troubleshooting:
            return "troubleshooting problems issues fixes errors"
        case .specifications:
            return "specifications technical data dimensions weight power ratings"
        case .partsAccessories:
            return "parts accessories components included package contents"
        case .warrantySupport:
            return "warranty support contact service guarantee"
        }
    }
}

final class ManualTopicTagger {
    static let shared = ManualTopicTagger()
    private init() {}

    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    func tagSections(
        _ sections: [ManualSection],
        similarityThreshold: Double = 0.22
    ) -> [ManualTopic: [ManualSection]] {
        guard let embedding = embedding else { return [:] }

        let sectionVectors = sections.compactMap { section -> (ManualSection, [Double])? in
            let text = sectionText(for: section)
            guard let vector = embedding.vector(for: text) else { return nil }
            return (section, vector)
        }

        var results: [ManualTopic: [ManualSection]] = [:]

        for topic in ManualTopic.allCases {
            guard let topicVector = embedding.vector(for: topic.matchText) else { continue }

            for (section, sectionVector) in sectionVectors {
                let similarity = cosineSimilarity(topicVector, sectionVector)
                if similarity >= similarityThreshold {
                    results[topic, default: []].append(section)
                }
            }

            results[topic]?.sort { $0.sectionIndex < $1.sectionIndex }
        }

        return results
    }

    private func sectionText(for section: ManualSection) -> String {
        let summaryText = section.summary.isEmpty ? "" : " \(section.summary)"
        let contentPreview = String(section.content.prefix(800))
        return "\(section.heading)\(summaryText) \(contentPreview)"
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }
}
