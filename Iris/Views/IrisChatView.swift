import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let fromIris: Bool
    let text: String
}

/// Pantalla principal: el chat con Iris.
/// En esta primera versión Iris todavía no tiene "cerebro" (IA);
/// eso se conecta en la siguiente versión.
struct IrisChatView: View {
    @Binding var isTyping: Bool
    let onSettings: () -> Void

    @AppStorage("iris.nombre") private var nombre = ""
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text("Hoy · \(Date().formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 12))
                            .foregroundStyle(IrisColor.muted)
                            .padding(.top, 8)

                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages) { _, newValue in
                    if let last = newValue.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            inputBar
                .padding(.horizontal, 16)
                .padding(.bottom, isTyping ? 8 : 92)
        }
        .onAppear {
            if messages.isEmpty { messages = [welcome] }
        }
        .onChange(of: inputFocused) { _, focused in
            isTyping = focused
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("Iris")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(IrisColor.ink)
                Text("En línea")
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
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("Enviar")
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: 54)
        .glass(radius: 27)
    }

    private var welcome: ChatMessage {
        let saludo = nombre.isEmpty ? "Hola." : "Hola, \(nombre)."
        return ChatMessage(
            fromIris: true,
            text: "\(saludo) Soy Iris. Por ahora puedes manejar tus tareas y recordatorios desde las pestañas de abajo. Muy pronto podré entender lo que me escribas y hacerlo por ti."
        )
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(fromIris: false, text: text))
        draft = ""

        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            messages.append(ChatMessage(
                fromIris: true,
                text: "Todavía no tengo mi cerebro conectado, así que aún no puedo entenderte. En la próxima versión podré crear tareas y recordatorios con solo pedírmelo."
            ))
        }
    }
}

/// Burbuja de mensaje: cristal para Iris, azul para ti.
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if !message.fromIris { Spacer(minLength: 60) }

            Text(message.text)
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(message.fromIris ? IrisColor.ink : IrisColor.paper)
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
                .overlay(shape.fill(Color.white.opacity(0.35)))
        } else {
            shape.fill(IrisColor.navy)
        }
    }
}
