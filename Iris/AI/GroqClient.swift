import Foundation

/// Habla con Groq (plan gratuito, sin tarjeta). Se usa cuando la clave empieza por "gsk_".
enum GroqClient {
    /// Modelos gratuitos, en orden de preferencia. Si uno deja de existir,
    /// Iris prueba el siguiente y recuerda el que funcionó.
    static let models = [
        "llama-3.3-70b-versatile",
        "openai/gpt-oss-120b",
        "qwen/qwen3-32b",
        "llama-3.1-8b-instant"
    ]
    private static let workingModelKey = "iris.groqModelActivo"

    static func isGroqKey(_ key: String) -> Bool {
        key.hasPrefix("gsk_")
    }

    private static var modelsToTry: [String] {
        let saved = UserDefaults.standard.string(forKey: workingModelKey) ?? ""
        return saved.isEmpty ? models : [saved] + models.filter { $0 != saved }
    }

    static func generate(key: String, system: String, turns: [GeminiClient.Turn]) async throws -> String {
        var lastError: Error = GeminiClient.Failure.unreadable
        for model in modelsToTry {
            do {
                let text = try await call(model: model, key: key, system: system, turns: turns)
                UserDefaults.standard.set(model, forKey: workingModelKey)
                return text
            } catch GeminiClient.Failure.modelUnavailable(let message) {
                lastError = GeminiClient.Failure.server(message)
                continue
            }
        }
        throw lastError
    }

    private static func call(model: String, key: String, system: String, turns: [GeminiClient.Turn]) async throws -> String {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw GeminiClient.Failure.unreadable
        }

        var messages: [[String: String]] = [["role": "system", "content": system]]
        for turn in turns.drop(while: { $0.role == .model }) {
            messages.append(["role": turn.role == .user ? "user" : "assistant", "content": turn.text])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.4,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: url, timeoutInterval: 40)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiClient.Failure.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard status == 200 else {
            let error = json?["error"] as? [String: Any]
            let message = (error?["message"] as? String) ?? "código \(status)"
            let code = (error?["code"] as? String) ?? ""
            switch status {
            case 401, 403:
                throw GeminiClient.Failure.badKey(message)
            case 429:
                throw GeminiClient.Failure.quota
            case 404:
                throw GeminiClient.Failure.modelUnavailable(message)
            case 400 where code.contains("model") || message.lowercased().contains("decommissioned") || message.lowercased().contains("does not exist"):
                throw GeminiClient.Failure.modelUnavailable(message)
            default:
                throw GeminiClient.Failure.server(message)
            }
        }

        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String,
              !text.isEmpty
        else { throw GeminiClient.Failure.unreadable }
        return text
    }
}
