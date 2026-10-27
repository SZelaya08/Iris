import SwiftUI

enum IrisTab: CaseIterable {
    case iris, tareas, recordatorios

    var label: String {
        switch self {
        case .iris: return "Iris"
        case .tareas: return "Tareas"
        case .recordatorios: return "Recordatorios"
        }
    }
}

struct RootView: View {
    @State private var tab: IrisTab = .iris
    @State private var showSettings = false
    @State private var isTyping = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                IrisBackground()

                Group {
                    switch tab {
                    case .iris:
                        IrisChatView(isTyping: $isTyping, onSettings: openSettings)
                    case .tareas:
                        TareasView(onSettings: openSettings)
                    case .recordatorios:
                        RecordatoriosView(onSettings: openSettings)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if !isTyping {
                    IrisTabBar(selection: $tab)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isTyping)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSettings) {
                AjustesView()
            }
        }
        // Al tocar el widget se abre directamente la pestaña de Tareas.
        .onOpenURL { url in
            if url.host == "tareas" {
                showSettings = false
                tab = .tareas
            }
        }
    }

    private func openSettings() {
        showSettings = true
    }
}

/// Barra de pestañas flotante de cristal: tres secciones del mismo ancho.
struct IrisTabBar: View {
    @Binding var selection: IrisTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(IrisTab.allCases, id: \.self) { item in
                let active = item == selection
                Button {
                    selection = item
                } label: {
                    VStack(spacing: 2) {
                        icon(for: item)
                            .frame(width: 22, height: 22)
                        Text(item.label)
                            .font(.system(size: 11, weight: active ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .foregroundStyle(active ? IrisColor.navy : IrisColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if active {
                            Capsule().fill(IrisColor.navy.opacity(0.1))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 66)
        .glass(radius: 33)
    }

    @ViewBuilder
    private func icon(for item: IrisTab) -> some View {
        switch item {
        case .iris:
            FlowerMark(lineWidth: 1.6, color: selection == item ? IrisColor.navy : IrisColor.muted)
        case .tareas:
            Image(systemName: "checkmark.square")
                .font(.system(size: 19))
        case .recordatorios:
            Image(systemName: "bell")
                .font(.system(size: 19))
        }
    }
}
