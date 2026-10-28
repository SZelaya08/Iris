import SwiftUI
import UIKit

struct AjustesView: View {
    // Sobre ti
    @AppStorage("iris.nombre") private var nombre = ""
    @AppStorage("iris.sobreMi") private var sobreMi = ""
    @AppStorage("iris.estilo") private var estilo = ""

    // Resumen de la mañana (hora guardada como segundos desde la medianoche)
    @AppStorage("iris.resumenActivo") private var resumenActivo = true
    @AppStorage("iris.resumenHora") private var resumenHora: Double = 6.5 * 3600

    @EnvironmentObject private var tasks: TaskStore

    // Cerebro de Iris (la clave se guarda en el llavero del iPhone)
    @State private var apiKey = GeminiClient.apiKey
    @State private var probando = false
    @State private var resultadoPrueba: String?
    @AppStorage(LiveActivityManager.settingKey) private var tarjetaGrande = true

    var body: some View {
        ZStack {
            IrisBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cerebro
                    sobreTi
                    resumen
                    conexiones
                    widgetSection

                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // La versión instalada, para saber si ya llegó el último arreglo.
            ToolbarItem(placement: .topBarTrailing) {
                Text("v\(versionInstalada)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(IrisColor.navy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(IrisColor.navy.opacity(0.1)))
                    .accessibilityLabel("Versión \(versionInstalada)")
            }
        }
        .onChange(of: resumenActivo) { _, _ in SummaryNotification.schedule() }
        .onChange(of: resumenHora) { _, _ in SummaryNotification.schedule() }
    }

    private var versionInstalada: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    // MARK: - Secciones

    private var cerebro: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Cerebro de Iris")
            VStack(alignment: .leading, spacing: 14) {
                field("Clave de IA (Groq o Gemini)") {
                    SecureField("Pega aquí tu clave", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(inputBackground)
                        .onChange(of: apiKey) { _, newValue in
                            Keychain.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: GeminiClient.keyAccount)
                            resultadoPrueba = nil
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task { await probar() }
                    } label: {
                        Text(probando ? "Probando…" : "Probar conexión")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(IrisColor.paper)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 40)
                            .background(Capsule().fill(IrisColor.navy))
                    }
                    .disabled(probando || apiKey.isEmpty)
                    .opacity(apiKey.isEmpty ? 0.5 : 1)

                    if let resultadoPrueba {
                        Text(resultadoPrueba)
                            .font(.system(size: 13))
                            .foregroundStyle(resultadoPrueba == "Conectado" ? IrisColor.navy : IrisColor.muted)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let url = URL(string: "https://console.groq.com/keys") {
                    Link(destination: url) {
                        Label("Conseguir una clave gratis en Groq", systemImage: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(IrisColor.navy)
                }
            }
            .padding(16)
            .glass()
            Text("Lo que le escribes a Iris se envía al proveedor de IA (Groq o Google) para que lo procese. Evita compartir contraseñas o datos sensibles. Iris detecta sola qué proveedor usar según la clave.")
                .font(.system(size: 12))
                .foregroundStyle(IrisColor.muted)
                .padding(.leading, 4)
        }
    }

    private func probar() async {
        probando = true
        defer { probando = false }
        do {
            _ = try await GeminiClient.generate(
                system: "Responde solo con un objeto JSON.",
                turns: [.init(role: .user, text: "Responde {\"respuesta\": \"hola\"}")]
            )
            resultadoPrueba = "Conectado"
        } catch {
            // Mostramos el motivo real para poder arreglarlo.
            resultadoPrueba = error.localizedDescription
        }
    }

    private var sobreTi: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Sobre ti")
            VStack(alignment: .leading, spacing: 14) {
                field("¿Cómo quieres que te llame?") {
                    TextField("Tu nombre", text: $nombre)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(inputBackground)
                }
                field("Sobre mí") {
                    MultilineField(
                        text: $sobreMi,
                        placeholder: "Qué estudias o en qué trabajas, tus horarios, lo que haces usualmente…"
                    )
                }
                field("Cómo quiero que trabajes") {
                    MultilineField(
                        text: $estilo,
                        placeholder: "Ej.: avísame un día antes, sé breve en las mañanas, no me escribas después de las 10 p. m.…"
                    )
                }
            }
            .padding(16)
            .glass()
        }
    }

    private var resumen: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Resumen de la mañana")
            VStack(spacing: 0) {
                Toggle("Enviarme el resumen", isOn: $resumenActivo)
                    .frame(minHeight: 56)
                if resumenActivo {
                    ThinDivider()
                    DatePicker("Hora", selection: resumenHoraBinding, displayedComponents: .hourAndMinute)
                        .frame(minHeight: 56)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(IrisColor.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .glass()
            Text("A esa hora te llega un aviso. Al abrir Iris, ella te escribe el resumen con tus tareas y recordatorios del día.")
                .font(.system(size: 12))
                .foregroundStyle(IrisColor.muted)
                .padding(.leading, 4)
        }
    }

    private var conexiones: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Conexiones")
            VStack(spacing: 0) {
                connectionRow(icon: "envelope", title: "Correo")
                ThinDivider()
                connectionRow(icon: "calendar", title: "Calendario")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .glass()
        }
    }

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Widget de bloqueo")
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 18))
                        .foregroundStyle(IrisColor.navy)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tus tareas")
                            .font(.system(size: 16))
                        Text("Se guardan en Recordatorios › lista Iris")
                            .font(.system(size: 13))
                            .foregroundStyle(IrisColor.muted)
                    }
                    Spacer()
                    accessBadge
                }
                .frame(minHeight: 60)
                ThinDivider()
                Toggle(isOn: $tarjetaGrande) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tarjeta grande de tareas")
                            .font(.system(size: 16))
                        Text("Hasta 6 tareas en la pantalla de bloqueo y en la Dynamic Island")
                            .font(.system(size: 13))
                            .foregroundStyle(IrisColor.muted)
                    }
                }
                .frame(minHeight: 64)
                .onChange(of: tarjetaGrande) { _, _ in
                    Task { await LiveActivityManager.sync(tasks: tasks.tasks) }
                }
            }
            .foregroundStyle(IrisColor.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .glass()
            Text("Para agregarlo: mantén presionada la pantalla de bloqueo › Personalizar › Pantalla de bloqueo › toca la zona de widgets › Iris.")
                .font(.system(size: 12))
                .foregroundStyle(IrisColor.muted)
                .padding(.leading, 4)
            Text("La tarjeta grande se apaga sola después de unas 8 horas (así lo exige iOS). Se vuelve a encender cada vez que abres Iris.")
                .font(.system(size: 12))
                .foregroundStyle(IrisColor.muted)
                .padding(.leading, 4)
            Text("Para elegir cuántas tareas muestra, ocultar las terminadas o esconder la lista: mantén presionado el widget › Editar widget.")
                .font(.system(size: 12))
                .foregroundStyle(IrisColor.muted)
                .padding(.leading, 4)
        }
    }

    // MARK: - Piezas

    @ViewBuilder
    private var accessBadge: some View {
        switch tasks.access {
        case .granted:
            Label("Conectado", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(IrisColor.navy)
        case .unknown:
            Button("Dar permiso") {
                Task { await tasks.requestAccess() }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(IrisColor.paper)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(IrisColor.navy))
        case .denied:
            Button("Abrir Configuración") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(IrisColor.navy)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(IrisColor.ink)
            content()
                .font(.system(size: 15))
                .foregroundStyle(IrisColor.ink)
        }
    }

    private func connectionRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(IrisColor.navy)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(IrisColor.ink)
            Spacer()
            Text("Próximamente")
                .font(.system(size: 14))
                .foregroundStyle(IrisColor.muted)
        }
        .frame(minHeight: 60)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(IrisColor.navy.opacity(0.15), lineWidth: 1)
            )
    }

    private var resumenHoraBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.startOfDay(for: Date()).addingTimeInterval(resumenHora)
            },
            set: { newDate in
                let start = Calendar.current.startOfDay(for: newDate)
                resumenHora = newDate.timeIntervalSince(start)
            }
        )
    }
}

/// Campo de texto de varias líneas con el estilo de cristal.
struct MultilineField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color(hex: 0x5A6A80))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
        }
        .frame(minHeight: 96)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(IrisColor.navy.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
