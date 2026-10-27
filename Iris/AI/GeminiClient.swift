import Foundation

/// Habla con la API de Gemini (plan gratuito).
struct GeminiClient {
    /// Modelos gratuitos, en orden de preferencia. Si uno no está disponible
    /// para la cuenta, Iris prueba el siguiente y recuerda el que funcionó.
    static let models = [
        "gemini-3.5-flash-lite",
        "gemini-3.1-flash-lite",
        "gemini-flash-lite-latest",
        "gemini-flash-latest"
    ]
    static let keyAccount = "gemini.apiKey"
    private static let workingModelKey = "iris.geminiModelActivo"

    struct Turn {
        enum Role: String { case user, model }
        let role: Role
        let text: String
    }

    enum Failure: LocalizedError {
        case noKey
        case badKey(String)
        case quota
        case network
        case server(String)
        case unreadable
        case modelUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .noKey:
                return "Todavía no tengo mi cerebro conectado. Agrega tu clave de IA en Ajustes › Cerebro de Iris."
            case .badKey(let message):
                return "No se aceptó la clave de IA (\(message)). Revísala en Ajustes › Cerebro de Iris."
            case .quota:
                return "Por ahora se acabó el cupo gratis de la IA. Vuelve a intentarlo en un rato o mañana."
            case .network:
                return "No pude conectarme. Revisa tu internet e inténtalo de nuevo."
            case .server(let message):
                return "La IA respondió con un error: \(message)"
            case .unreadable:
                return "No entendí la respuesta de la IA. ¿Me lo repites?"
            case .modelUnavailable(let message):
                return "El modelo de IA no está disponible: \(message)"
            }
        }
    }

    static var apiKey: String { Keychain.load(keyAccount) }

    /// El modelo que funcionó la última vez va primero.
    private static var modelsToTry: [String] {
        let saved = UserDefaults.standard.string(forKey: workingModelKey) ?? ""
        return saved.isEmpty ? models : [saved] + models.filter { $0 != saved }
    }

    /// Envía la conversación y devuelve el texto JSON que responde Gemini.
    static func generate(system: String, turns: [Turn]) async throws -> String {
        let key = apiKey
        guard !key.isEmpty else { throw Failure.noKey }

        // Claves de Groq ("gsk_…") van a Groq; las demás, a Gemini.
        if GroqClient.isGroqKey(key) {
            return try await GroqClient.generate(key: key, system: system, turns: turns)
        }

        var lastError: Error = Failure.unreadable
        for model in modelsToTry {
            do {
                let text = try await call(model: model, key: key, system: system, turns: turns)
                UserDefaults.standard.set(model, forKey: workingModelKey)
                return text
            } catch Failure.modelUnavailable(let message) {
                lastError = Failure.server(message)
                continue   // Probamos con el siguiente modelo.
            }
        }
        throw lastError
    }

    /// Primero usa la "Interactions API" (la nueva, que acepta las claves "AQ.").
    /// Si no está disponible, prueba la forma anterior ("generateContent").
    private static func call(model: String, key: String, system: String, turns: [Turn]) async throws -> String {
        do {
            return try await callInteractions(model: model, key: key, system: system, turns: turns)
        } catch Failure.modelUnavailable {
            return try await callGenerateContent(model: model, key: key, system: system, turns: turns)
        }
    }

    // MARK: - Interactions API (nueva)

    private static func callInteractions(model: String, key: String, system: String, turns: [Turn]) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions") else {
            throw Failure.unreadable
        }
        let body: [String: Any] = [
            "model": model,
            "system_instruction": system,
            "input": transcript(turns),
            "store": false
        ]
        let json = try await post(url: url, key: key, body: body)

        // La respuesta trae "steps"; el texto está en los pasos "model_output".
        var texts: [String] = []
        for step in json["steps"] as? [[String: Any]] ?? [] where (step["type"] as? String) == "model_output" {
            for item in step["content"] as? [[String: Any]] ?? [] where (item["type"] as? String) == "text" {
                if let text = item["text"] as? String { texts.append(text) }
            }
        }
        // Formato alterno ("outputs"), por si Google lo cambia.
        if texts.isEmpty {
            for item in json["outputs"] as? [[String: Any]] ?? [] where (item["type"] as? String) == "text" {
                if let text = item["text"] as? String { texts.append(text) }
            }
        }
        let text = texts.joined()
        guard !text.isEmpty else { throw Failure.unreadable }
        return text
    }

    /// La conversación como texto: la Interactions API recibe una sola entrada.
    private static func transcript(_ turns: [Turn]) -> String {
        let trimmed = Array(turns.drop(while: { $0.role == .model }))
        guard trimmed.count > 1 else { return trimmed.last?.text ?? "" }
        let previous = trimmed.dropLast().map { ($0.role == .user ? "Ella" : "Iris") + ": " + $0.text }
        return """
        Conversación hasta ahora:
        \(previous.joined(separator: "\n"))

        Su nuevo mensaje:
        \(trimmed.last?.text ?? "")
        """
    }

    // MARK: - generateContent (anterior)

    private static func callGenerateContent(model: String, key: String, system: String, turns: [Turn]) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw Failure.modelUnavailable("modelo inválido")
        }
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": mergedContents(turns),
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        let json = try await post(url: url, key: key, body: body)

        guard let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else { throw Failure.unreadable }

        // Se ignoran las partes de "pensamiento" del modelo, si las hay.
        let text = parts
            .filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw Failure.unreadable }
        return text
    }

    // MARK: - Envío y errores

    private static func post(url: URL, key: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 40)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard status == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "código \(status)"
            let lower = message.lowercased()
            switch status {
            case _ where lower.contains("prepayment") || lower.contains("billing"):
                throw Failure.server("tu cuenta de Google tiene facturación sin saldo. Crea la clave con una cuenta que no tenga facturación.")
            case 400 where lower.contains("api key"),
                 401, 403:
                throw Failure.badKey(message)
            case 429:
                throw Failure.quota
            case 404:
                throw Failure.modelUnavailable(message)
            case 400 where lower.contains("model") && (lower.contains("not found") || lower.contains("not supported")):
                throw Failure.modelUnavailable(message)
            default:
                throw Failure.server(message)
            }
        }
        return json ?? [:]
    }

    /// Gemini pide que la conversación empiece con el usuario
    /// y que no haya dos mensajes seguidos del mismo lado.
    private static func mergedContents(_ turns: [Turn]) -> [[String: Any]] {
        var result: [(role: Turn.Role, text: String)] = []
        for turn in turns.drop(while: { $0.role == .model }) {
            if let last = result.last, last.role == turn.role {
                result[result.count - 1].text += "\n\n" + turn.text
            } else {
                result.append((turn.role, turn.text))
            }
        }
        return result.map { ["role": $0.role.rawValue, "parts": [["text": $0.text]]] }
    }
}
