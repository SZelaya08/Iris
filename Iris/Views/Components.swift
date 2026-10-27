import SwiftUI

/// Fondo azul claro con reflejos suaves, igual al diseño.
struct IrisBackground: View {
    var body: some View {
        ZStack {
            IrisColor.ground
            Circle()
                .fill(IrisColor.powder)
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .opacity(0.75)
                .offset(x: -140, y: -330)
            Circle()
                .fill(IrisColor.sky)
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .opacity(0.5)
                .offset(x: 150, y: 220)
            Circle()
                .fill(IrisColor.mist)
                .frame(width: 230, height: 230)
                .blur(radius: 60)
                .opacity(0.8)
                .offset(x: -150, y: 80)
        }
        .ignoresSafeArea()
    }
}

/// Efecto de cristal: material translúcido, borde blanco y sombra suave.
struct GlassBackground: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.fill(Color.white.opacity(0.5)))
                    .environment(\.colorScheme, .light)
            }
            .overlay(shape.strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
            .shadow(color: IrisColor.ink.opacity(0.07), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func glass(radius: CGFloat = 22) -> some View {
        modifier(GlassBackground(radius: radius))
    }
}

/// El ícono de Iris en miniatura (cuadro azul con la flor de cristal).
struct AppMark: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.224, style: .continuous)
                .fill(IrisColor.navy)
            FlowerMark(lineWidth: max(1, size / 40), color: .white.opacity(0.75), fill: .white.opacity(0.28))
                .padding(size * 0.1)
            Circle()
                .fill(IrisColor.paper)
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(y: size * 0.026)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Encabezado grande con título, subtítulo y el botón de Ajustes.
struct ScreenHeader<Subtitle: View>: View {
    let title: String
    let onSettings: () -> Void
    @ViewBuilder var subtitle: Subtitle

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(IrisColor.ink)
                subtitle
                    .font(.system(size: 13))
                    .foregroundStyle(IrisColor.muted)
            }
            Spacer()
            SettingsButton(action: onSettings)
        }
    }
}

struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(IrisColor.navy)
                .frame(width: 44, height: 44)
                .glass(radius: 22)
        }
        .accessibilityLabel("Ajustes")
    }
}

/// Título pequeño en mayúsculas sobre cada grupo.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(1)
            .foregroundStyle(IrisColor.muted)
            .padding(.leading, 4)
    }
}

/// Línea divisoria fina dentro de las tarjetas.
struct ThinDivider: View {
    var body: some View {
        Rectangle()
            .fill(IrisColor.navy.opacity(0.1))
            .frame(height: 1)
    }
}
