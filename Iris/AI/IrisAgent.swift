import Foundation

/// El "cerebro" de Iris: arma el contexto (quién eres, tus tareas y recordatorios),
/// le pregunta a Gemini y ejecuta lo que Gemini decide hacer.
@MainActor
struct IrisAgent {
    let tasks: TaskStore
    let reminders: ReminderStore

    struct Reply {
        let text: String
        let actions: [String]   // Frases cortas como "Tarea creada · Comprar pan"
    }

    // MARK: - Conversación

    func respond(history: [ChatMessage]) async throws -> Reply {
        let turns = history.suffix(14).map {
            GeminiClient.Turn(role: $0.fromIris ? .model : .user, text: $0.text)
        }
        let json = try await GeminiClient.generate(system: systemPrompt(), turns: Array(turns), schema: Self.schema)
        return try await perform(json)
    }

    /// El resumen de la mañana con lo que Iris sabe de tu día.
    func morningSummary() async throws -> Reply {
        let request = GeminiClient.Turn(
            role: .user,
            text: "Es la hora de mi resumen de la mañana. Salúdame y cuéntame en pocas líneas lo importante de hoy: tareas para hoy o atrasadas, recordatorios que llegan hoy o en los próximos días, y lo que conviene priorizar. No ejecutes acciones."
        )
        let json = try await GeminiClient.generate(system: systemPrompt(), turns: [request], schema: Self.schema)
        let reply = try decode(json)
        return Reply(text: reply.respuesta, actions: [])
    }

    // MARK: - Contexto para Gemini

    private func systemPrompt() -> String {
        let defaults = UserDefaults.standard
        let nombre = defaults.string(forKey: "iris.nombre").flatMap { $0.isEmpty ? nil : $0 } ?? "la usuaria"
        let sobreMi = defaults.string(forKey: "iris.sobreMi") ?? ""
        let estilo = defaults.string(forKey: "iris.estilo") ?? ""

        let now = Date()
        let hoy = now.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute().locale(Locale(identifier: "es_CO")))

        let taskLines = indexedTasks.map { key, task in
            var line = "\(key): \(task.title)"
            if let due = task.dueDate { line += " (para \(Self.iso.string(from: due)))" }
            if task.isDone { line += " [hecha]" }
            return line
        }
        let reminderLines = indexedReminders.map { key, r in
            "\(key): \(r.title) — \(r.whenText)"
        }

        return """
        Eres Iris, la asistente personal de \(nombre) dentro de su app de iPhone. Hablas en español, con calidez y de forma breve, como una amiga organizada. Te diriges a ella como \(nombre).

        Fecha y hora actual: \(hoy) (zona horaria \(TimeZone.current.identifier)). Hoy en formato ISO: \(Self.iso.string(from: now)).

        Lo que \(nombre) cuenta de sí misma:
        \(sobreMi.isEmpty ? "(no ha escrito nada todavía)" : sobreMi)

        Cómo quiere que trabajes:
        \(estilo.isEmpty ? "(sin indicaciones especiales)" : estilo)

        Sus tareas (lista "Tareas", se ven en su pantalla de bloqueo):
        \(taskLines.isEmpty ? "(ninguna)" : taskLines.joined(separator: "\n"))

        Sus recordatorios a largo plazo (le llegan como notificación):
        \(reminderLines.isEmpty ? "(ninguno)" : reminderLines.joined(separator: "\n"))

        Qué puedes hacer, usando "acciones":
        - crear_tarea: algo que tiene que hacer, con "fecha" opcional.
        - completar_tarea / borrar_tarea: usa "id" con la clave de la lista (por ejemplo T2).
        - crear_recordatorio: algo que debe recordarle en un momento concreto. Necesita "fecha" y "repetir" (none, daily, weekly, monthly o yearly).
        - borrar_recordatorio: usa "id" con la clave de la lista (por ejemplo R1).

        Reglas:
        - Si te pide "recuérdame…" con un momento concreto, crea un recordatorio. Si solo dice que tiene que hacer algo, crea una tarea.
        - Las fechas van en formato yyyy-MM-ddTHH:mm, en su hora local. Calcula bien expresiones como "mañana", "el viernes" o "en 2 horas" a partir de la fecha actual.
        - Si para un recordatorio no dice la hora, usa 9:00 a. m. y díselo en la respuesta.
        - Si algo no está claro (por ejemplo, cuál tarea quiere borrar), pregúntale y no hagas acciones.
        - En "respuesta" confirma en una o dos frases lo que hiciste. No inventes tareas ni recordatorios que no existen.
        - Todavía no tienes acceso a su correo, calendario ni WhatsApp. Si te pregunta por eso, díselo con honestidad.
        """
    }

    /// Claves cortas (T1, T2…) para que Gemini se refiera a cada tarea.
    private var indexedTasks: [(String, TaskItem)] {
        tasks.tasks.sorted(by: TaskItem.sortOrder).enumerated().map { ("T\($0.offset + 1)", $0.element) }
    }

    private var indexedReminders: [(String, ReminderItem)] {
        (reminders.repeating + reminders.oneTime).enumerated().map { ("R\($0.offset + 1)", $0.element) }
    }

    // MARK: - Ejecutar acciones

    private struct Decoded: Decodable {
        struct Action: Decodable {
            let tipo: String
            let titulo: String?
            let fecha: String?
            let repetir: String?
            let id: String?
        }
        let respuesta: String
        let acciones: [Action]?
    }

    private func decode(_ json: String) throws -> Decoded {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Decoded.self, from: data)
        else { throw GeminiClient.Failure.unreadable }
        return decoded
    }

    private func perform(_ json: String) async throws -> Reply {
        let decoded = try decode(json)
        let taskMap = Dictionary(uniqueKeysWithValues: indexedTasks)
        let reminderMap = Dictionary(uniqueKeysWithValues: indexedReminders)
        var done: [String] = []

        for action in decoded.acciones ?? [] {
            let title = action.titulo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let date = action.fecha.flatMap { Self.iso.date(from: $0) }

            switch action.tipo {
            case "crear_tarea" where !title.isEmpty:
                tasks.add(title: title, dueDate: date)
                done.append("Tarea creada · \(title)")

            case "completar_tarea":
                if let id = action.id, let task = taskMap[id] {
                    tasks.setDone(task, done: true)
                    done.append("Tarea hecha · \(task.title)")
                }

            case "borrar_tarea":
                if let id = action.id, let task = taskMap[id] {
                    tasks.delete(task)
                    done.append("Tarea borrada · \(task.title)")
                }

            case "crear_recordatorio" where !title.isEmpty:
                if let date {
                    let rule = RepeatRule(rawValue: action.repetir ?? "none") ?? .none
                    await reminders.add(ReminderItem(title: title, date: date, repeatRule: rule))
                    done.append("Recordatorio creado · \(title)")
                }

            case "borrar_recordatorio":
                if let id = action.id, let reminder = reminderMap[id] {
                    reminders.delete(reminder)
                    done.append("Recordatorio borrado · \(reminder.title)")
                }

            default:
                break
            }
        }

        return Reply(text: decoded.respuesta, actions: done)
    }

    // MARK: - Formato de respuesta que le pedimos a Gemini

    static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "respuesta": ["type": "STRING"],
            "acciones": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "tipo": [
                            "type": "STRING",
                            "enum": ["crear_tarea", "completar_tarea", "borrar_tarea", "crear_recordatorio", "borrar_recordatorio"]
                        ],
                        "titulo": ["type": "STRING"],
                        "fecha": ["type": "STRING", "description": "yyyy-MM-ddTHH:mm en hora local"],
                        "repetir": ["type": "STRING", "enum": ["none", "daily", "weekly", "monthly", "yearly"]],
                        "id": ["type": "STRING", "description": "Clave como T1 o R2"]
                    ],
                    "required": ["tipo"]
                ]
            ]
        ],
        "required": ["respuesta", "acciones"]
    ]

    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()
}
