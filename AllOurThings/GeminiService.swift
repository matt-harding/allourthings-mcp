import Foundation

// MARK: - Gemini API Service

class GeminiService {
    static let shared = GeminiService()
    private init() {}

    private let baseURL = Constants.API.geminiBaseURL

    // MARK: - Generate Response

    func generateResponse(prompt: String) async throws -> String {
        guard let apiKey = KeychainHelper.shared.getGeminiKey() else {
            throw GeminiError.noAPIKey
        }

        // Build URL with API key
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        // Build request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to get error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("Gemini API Error: \(message)")
                throw GeminiError.apiErrorWithMessage(statusCode: httpResponse.statusCode, message: message)
            }
            throw GeminiError.apiError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.parseError
        }

        return text
    }

    // MARK: - Test API Key

    func testAPIKey(_ key: String) async -> Bool {
        // Temporarily save the key
        let existingKey = KeychainHelper.shared.getGeminiKey()
        _ = KeychainHelper.shared.saveGeminiKey(key)

        // Try a simple request
        do {
            _ = try await generateResponse(prompt: "Say 'OK' if you can read this.")
            return true
        } catch {
            print("API Key Test Failed: \(error.localizedDescription)")
            // Restore old key if test failed
            if let oldKey = existingKey {
                _ = KeychainHelper.shared.saveGeminiKey(oldKey)
            } else {
                KeychainHelper.shared.deleteGeminiKey()
            }
            return false
        }
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case apiErrorWithMessage(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key found. Please add your Gemini API key in Settings (tap the gear icon)."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code):
            return "API request failed (status \(code)). This usually means your API key is invalid or has expired. Please check Settings."
        case .apiErrorWithMessage(let code, let message):
            return "API error (\(code)): \(message). Please check your API key in Settings."
        case .parseError:
            return "Failed to parse response from server"
        }
    }
}
