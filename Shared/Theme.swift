import SwiftUI

extension Color {
    /// Crea un color a partir de un número hexadecimal, por ejemplo 0x1E3557.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Paleta de Iris: azul mate con cristal.
enum IrisColor {
    static let navy = Color(hex: 0x1E3557)    // azul principal
    static let ink = Color(hex: 0x14223A)     // texto principal
    static let muted = Color(hex: 0x4A5B73)   // texto secundario
    static let ground = Color(hex: 0xE9EEF5)  // fondo
    static let powder = Color(hex: 0xA8C5E2)  // reflejo claro
    static let sky = Color(hex: 0x8DB3E2)     // reflejo medio
    static let mist = Color(hex: 0xC9D9EC)    // reflejo suave
    static let paper = Color(hex: 0xF4F6F9)   // blanco cálido
    static let off = Color(hex: 0xC4CEDB)     // interruptor apagado
}

/// La flor de Iris dibujada con tres pétalos (los mismos del logo).
struct FlowerMark: View {
    var lineWidth: CGFloat = 1.5
    var color: Color = IrisColor.navy
    var fill: Color = .clear

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Ellipse()
                        .fill(fill)
                        .overlay(Ellipse().stroke(color, lineWidth: lineWidth))
                        .frame(width: s * 0.25, height: s * 0.383)
                        .offset(y: -s * 0.179)
                        .rotationEffect(.degrees(Double(i) * 120))
                }
            }
            .frame(width: s, height: s)
            .offset(y: s * 0.033)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
