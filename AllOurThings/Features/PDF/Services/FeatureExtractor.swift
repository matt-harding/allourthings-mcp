//
//  FeatureExtractor.swift
//  AllOurThings
//
//  Extract key features from PDF manuals using Apple Intelligence
//

import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.allourhings.pdf", category: "FeatureExtractor")

class FeatureExtractor {
    static let shared = FeatureExtractor()

    private init() {}

    /// Extracts capabilities and specifications from manual text using Apple Intelligence
    /// - Parameters:
    ///   - manualText: The full manual text to analyze
    ///   - model: The SystemLanguageModel instance to use
    /// - Returns: Array of ItemFeature objects, or empty array if extraction fails or LLM unavailable
    func extractFeatures(from manualText: String, model: SystemLanguageModel) async -> [ItemFeature] {
        logger.info("🔍 [FeatureExtractor] Starting feature extraction")

        // Check model availability
        guard case .available = model.availability else {
            logger.warning("⚠️ [FeatureExtractor] Model not available, skipping extraction")
            return []
        }

        // Limit text to first 4000 characters to avoid overwhelming the model
        let textToAnalyze = String(manualText.prefix(4000))
        logger.info("🔍 [FeatureExtractor] Analyzing \(textToAnalyze.count) characters")

        // Create extraction prompt
        let instructions = """
        You are an expert at analyzing product manuals to extract key information.

        Your task is to extract key features from the following product manual text.

        Identify and categorize features into two types:

        1. CAPABILITIES: Functions, modes, features, and things the product can do
           Examples:
           - "self-cleaning mode"
           - "defrost function"
           - "timer up to 60 minutes"
           - "Bluetooth connectivity"
           - "automatic shut-off"

        2. SPECIFICATIONS: Technical details, measurements, ratings, and physical characteristics
           Examples:
           - "Power: 1200W"
           - "Capacity: 5.5L"
           - "Weight: 3.2kg"
           - "Temperature range: 50-250°C"
           - "Dimensions: 15x20x10 inches"

        IMPORTANT RULES:
        - Extract 8-12 most important features total
        - Be concise and specific (keep each feature under 80 characters)
        - Return ONLY valid JSON, no additional text or explanation
        - Use this exact format:

        [
          {"type": "capability", "text": "feature description"},
          {"type": "specification", "text": "spec description"}
        ]

        Do not include markdown code blocks, just the raw JSON array.
        """

        do {
            // Create one-off session for extraction (no tools needed)
            logger.info("🤖 [FeatureExtractor] Creating extraction session")
            let session = LanguageModelSession(tools: [], instructions: instructions)

            // Get response from model
            logger.info("🤖 [FeatureExtractor] Waiting for model response...")
            let response = try await session.respond(to: textToAnalyze)

            logger.info("✅ [FeatureExtractor] Received response (length: \(response.content.count))")
            logger.debug("📝 [FeatureExtractor] Response: \(response.content)")

            // Parse features from response
            let features = parseFeatures(from: response.content)
            logger.info("✅ [FeatureExtractor] Extracted \(features.count) features")

            return features

        } catch {
            logger.error("❌ [FeatureExtractor] Extraction failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Parses ItemFeature objects from LLM JSON response
    /// - Parameter response: The raw text response from the LLM
    /// - Returns: Array of ItemFeature objects
    private func parseFeatures(from response: String) -> [ItemFeature] {
        logger.info("🔍 [FeatureExtractor] Parsing features from response")

        // Clean up response - remove markdown code blocks if present
        var cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks
        if cleanedResponse.hasPrefix("```json") {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedResponse.hasPrefix("```") {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```", with: "")
        }
        if cleanedResponse.hasSuffix("```") {
            cleanedResponse = String(cleanedResponse.dropLast(3))
        }
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON array in response
        guard let jsonStart = cleanedResponse.firstIndex(of: "["),
              let jsonEnd = cleanedResponse.lastIndex(of: "]") else {
            logger.warning("⚠️ [FeatureExtractor] No JSON array found in response")
            return []
        }

        let jsonString = String(cleanedResponse[jsonStart...jsonEnd])

        // Decode JSON response
        struct FeatureResponse: Codable {
            let type: String
            let text: String
        }

        do {
            guard let jsonData = jsonString.data(using: .utf8) else {
                logger.error("❌ [FeatureExtractor] Failed to convert JSON string to Data")
                return []
            }

            let responses = try JSONDecoder().decode([FeatureResponse].self, from: jsonData)

            let features = responses.compactMap { response -> ItemFeature? in
                guard let type = ItemFeature.FeatureType(rawValue: response.type) else {
                    logger.warning("⚠️ [FeatureExtractor] Unknown feature type: \(response.type)")
                    return nil
                }

                // Truncate text if too long
                let truncatedText = response.text.count > 100
                    ? String(response.text.prefix(100))
                    : response.text

                return ItemFeature(type: type, text: truncatedText)
            }

            logger.info("✅ [FeatureExtractor] Successfully parsed \(features.count) features")

            // Log each feature for debugging
            for (index, feature) in features.enumerated() {
                logger.debug("  \(index + 1). [\(feature.type.rawValue)] \(feature.text)")
            }

            return features

        } catch {
            logger.error("❌ [FeatureExtractor] JSON parsing failed: \(error.localizedDescription)")
            logger.debug("📝 [FeatureExtractor] Failed JSON: \(jsonString)")
            return []
        }
    }
}
