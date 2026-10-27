import SwiftUI

struct ChatMessage: Identifiable, Equatable, Codable {
    var id = UUID()
    let fromIris: Bool
    let text: String
    var actions: [String] = []
    var date = Date()
}

/// Guarda la conversación en el iPhone para que no se borre al cerrar la app.
enum ChatHistory {
    private static let key = "iris.chat"
    private static let maxSaved = 80

    static func load() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([ChatMessage].self, from: data)
        else { return [] }
        return items
    }

    static func save(_ messages: [ChatMessage]) {
        if let data = try? JSONEncoder().encode(Array(messages.suffix(maxSaved))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Pantalla principal: el chat con Iris.
struct IrisChatView: View {
    @Binding var isTyping: Bool
    let onSettings: () -> Void

    @EnvironmentObject private var tasks: TaskStore
    @EnvironmentObject private var reminders: ReminderStore
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("iris.nombre") private var nombre = ""
    @AppStorage("iris.resumenActivo") private var resumenActivo = true
    @AppStorage("iris.resumenHora") private var resumenHora: Double = 6.5 * 3600
    @AppStorage("iris.ultimoResumen") private var ultimoResumen = ""

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var thinking = false
    @FocusState private var inputFocused: Bool

    private var agent: IrisAgent { IrisAgent(tasks: tasks, reminders: reminders) }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if showsDate(at: index) {
                                Text(dayLabel(message.date))
                                    .font(.system(size: 12))
                                    .foregroundStyle(IrisColor.muted)
                                    .padding(.top, 8)
                            }
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if thinking {
                            TypingBubble()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages) { _, newValue in
                    ChatHistory.save(newValue)
                    if let last = newValue.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: thinking) { _, isThinking in
                    if isThinking {
                        withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            inputBar
                .padding(.horizontal, 16)
                .padding(.bottom, isTyping ? 8 : 92)
        }
        .onAppear {
            if messages.isEmpty {
                messages = ChatHistory.load()
                if messages.isEmpty { messages = [welcome] }
            }
            checkMorningSummary()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Trae lo que hayas hablado con Iris desde Siri.
                let saved = ChatHistory.load()
                if !thinking, saved.count > messages.count { messages = saved }
                checkMorningSummary()
            }
        }
        .onChange(of: inputFocused) { _, focused in
            isTyping = focused
        }
    }

    // MARK: - Partes de la pantalla

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("Iris")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(IrisColor.ink)
                Text(thinking ? "Escribiendo…" : (GeminiClient.apiKey.isEmpty ? "Sin cerebro conectado" : "En línea"))
                    .font(.system(size: 13))
                    .foregroundStyle(IrisColor.muted)
            }
            Spacer()
            SettingsButton(action: onSettings)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            TextField("Escríbele a Iris…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(IrisColor.ink)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(IrisColor.paper)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(IrisColor.navy))
            }
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)
            .accessibilityLabel("Enviar")
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: 54)
        .glass(radius: 27)
    }

    private var canSend: Bool {
        !thinking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var welcome: ChatMessage {
        let saludo = nombre.isEmpty ? "Hola." : "Hola, \(nombre)."
        return ChatMessage(
            fromIris: true,
            text: "\(saludo) Soy Iris. Dime qué tienes que hacer o qué quieres que te recuerde, por ejemplo: \"Recuérdame pagar el internet el 5 de cada mes\" o \"Tengo que entregar el taller el viernes\"."
        )
    }

    // MARK: - Enviar y responder

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        messages.append(ChatMessage(fromIris: false, text: text))
        draft = ""

        Task {
            thinking = true
            defer { thinking = false }
            do {
                let reply = try await agent.respond(history: messages)
                messages.append(ChatMessage(fromIris: true, text: reply.text, actions: reply.actions))
            } catch {
                messages.append(ChatMessage(fromIris: true, text: error.localizedDescription))
            }
        }
    }

    /// Si ya pasó la hora del resumen y hoy no se ha hecho, Iris lo escribe.
    private func checkMorningSummary() {
        guard resumenActivo, !thinking, !GeminiClient.apiKey.isEmpty else { return }
        let now = Date()
        let today = IrisAgent.iso.string(from: now).prefix(10)
        let secondsToday = now.timeIntervalSince(Calendar.current.startOfDay(for: now))
        guard secondsToday >= resumenHora, ultimoResumen != String(today) else { return }

        ultimoResumen = String(today)
        Task {
            await tasks.reload()
            thinking = true
            defer { thinking = false }
            if let reply = try? await agent.morningSummary() {
                messages.append(ChatMessage(fromIris: true, text: reply.text))
            } else {
                ultimoResumen = ""   // Se vuelve a intentar la próxima vez que abras Iris.
            }
        }
    }

    // MARK: - Fechas entre mensajes

    private func showsDate(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(messages[index].date, inSameDayAs: messages[index - 1].date)
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return "Hoy · \(time)" }
        if cal.isDateInYesterday(date) { return "Ayer · \(time)" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "es_CO")))
    }
}

/// Burbuja de mensaje: cristal para Iris, azul para ti.
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if !message.fromIris { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(message.fromIris ? IrisColor.ink : IrisColor.paper)
                    .textSelection(.enabled)

                ForEach(message.actions, id: \.self) { action in
                    HStack(spacing: 8) {
                        Image(systemName: action.hasPrefix("Recordatorio") ? "bell" : "checkmark.square")
                            .font(.system(size: 13))
                        Text(action)
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(IrisColor.navy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(IrisColor.navy.opacity(0.08))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background { bubbleBackground }
            .overlay {
                if message.fromIris {
                    shape.stroke(Color.white.opacity(0.85), lineWidth: 1)
                }
            }
            .shadow(color: IrisColor.ink.opacity(message.fromIris ? 0.07 : 0), radius: 12, x: 0, y: 6)

            if message.fromIris { Spacer(minLength: 40) }
        }
    }

    private var shape: UnevenRoundedRectangle {
        if message.fromIris {
            return UnevenRoundedRectangle(
                topLeadingRadius: 8, bottomLeadingRadius: 22,
                bottomTrailingRadius: 22, topTrailingRadius: 22,
                style: .continuous
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 22,
                bottomTrailingRadius: 8, topTrailingRadius: 22,
                style: .continuous
            )
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.fromIris {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.white.opacity(0.5)))
                .environment(\.colorScheme, .light)
        } else {
            shape.fill(IrisColor.navy)
        }
    }
}

/// Los tres puntitos mientras Iris piensa.
struct TypingBubble: View {
    @State private var phase = 0.0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(IrisColor.navy.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .scaleEffect(1 + 0.3 * sin(phase + Double(i) * 0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glass(radius: 20)
            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .accessibilityLabel("Iris está escribiendo")
    }
}
