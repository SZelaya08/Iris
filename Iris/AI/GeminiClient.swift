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
        case badKey
        case quota
        case network
        case server(String)
        case unreadable
        case modelUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .noKey:
                return "Todavía no tengo mi cerebro conectado. Agrega tu clave de Gemini en Ajustes › Cerebro de Iris."
            case .badKey:
                return "Google no aceptó la clave de Gemini. Revísala en Ajustes › Cerebro de Iris."
            case .quota:
                return "Por hoy se acabó el cupo gratis de Gemini. Vuelve a intentarlo en un rato o mañana."
            case .network:
                return "No pude conectarme. Revisa tu internet e inténtalo de nuevo."
            case .server(let message):
                return "Gemini respondió con un error: \(message)"
            case .unreadable:
                return "No entendí la respuesta de Gemini. ¿Me lo repites?"
            case .modelUnavailable(let message):
                return "El modelo de Gemini no está disponible: \(message)"
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

    private static func call(model: String, key: String, system: String, turns: [Turn]) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw Failure.modelUnavailable("modelo inválido")
        }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": mergedContents(turns),
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

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
            case 400 where lower.contains("api key"),
                 401, 403:
                throw Failure.badKey
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

        guard let candidates = json?["candidates"] as? [[String: Any]],
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
