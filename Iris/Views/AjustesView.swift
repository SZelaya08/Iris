import SwiftUI

struct AjustesView: View {
    // Sobre ti
    @AppStorage("iris.nombre") private var nombre = ""
    @AppStorage("iris.sobreMi") private var sobreMi = ""
    @AppStorage("iris.estilo") private var estilo = ""

    // Resumen de la mañana (hora guardada como segundos desde la medianoche)
    @AppStorage("iris.resumenActivo") private var resumenActivo = true
    @AppStorage("iris.resumenHora") private var resumenHora: Double = 6.5 * 3600

    // Widget (se guarda donde el widget lo pueda leer)
    @State private var widget = SharedStore.loadWidgetSettings()

    var body: some View {
        ZStack {
            IrisBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sobreTi
                    resumen
                    conexiones
                    widgetSection

                    Text("Iris \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.system(size: 12))
                        .foregroundStyle(IrisColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: widget) { _, newValue in
            SharedStore.saveWidgetSettings(newValue)
        }
    }

    // MARK: - Secciones

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
            Text("El resumen empezará a llegar cuando conectemos el cerebro de Iris.")
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
                Toggle("Mostrar en la pantalla de bloqueo", isOn: $widget.enabled.animation())
                    .frame(minHeight: 56)
                if widget.enabled {
                    ThinDivider()
                    Stepper(value: $widget.count, in: 1...3) {
                        HStack {
                            Text("Tareas a mostrar")
                            Spacer()
                            Text("\(widget.count)")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(minHeight: 56)
                    ThinDivider()
                    Toggle("Ocultar las terminadas", isOn: $widget.hideDone)
                        .frame(minHeight: 56)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(IrisColor.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .glass()
            Text("Para agregarlo: mantén presionada la pantalla de bloqueo › Personalizar › Pantalla de bloqueo › toca la zona de widgets › Iris.")
                .font(.system(size: 12))
                .foregroundStyle(IrisColor.muted)
                .padding(.leading, 4)
        }
    }

    // MARK: - Piezas

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
