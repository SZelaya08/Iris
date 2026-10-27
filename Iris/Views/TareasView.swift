import SwiftUI
import UIKit

/// Lista de tareas. Es la misma que se ve en el widget de la pantalla de bloqueo.
struct TareasView: View {
    let onSettings: () -> Void

    @EnvironmentObject private var store: TaskStore
    @State private var showNewTask = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(title: "Tareas", onSettings: onSettings) {
                        Label {
                            Text("\(store.pendingCount) pendientes · también en tu pantalla de bloqueo")
                        } icon: {
                            Image(systemName: "lock")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }

                    if store.access != .granted {
                        accessCard
                    } else if store.tasks.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: group.name)
                                VStack(spacing: 0) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, task in
                                        if index > 0 { ThinDivider() }
                                        TaskRow(task: task)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .glass()
                            }
                        }

                        if store.tasks.contains(where: { $0.isDone }) {
                            Button("Borrar las terminadas") {
                                withAnimation { store.clearDone() }
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(IrisColor.navy)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 180)
            }

            Button {
                showNewTask = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(IrisColor.paper)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(IrisColor.navy))
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: IrisColor.navy.opacity(0.3), radius: 12, x: 0, y: 10)
            }
            .accessibilityLabel("Nueva tarea")
            .padding(.trailing, 24)
            .padding(.bottom, 100)
            .opacity(store.access == .granted ? 1 : 0)
            .disabled(store.access != .granted)
        }
        .sheet(isPresented: $showNewTask) {
            NewTaskSheet()
                .presentationDetents([.medium])
        }
    }

    /// Iris guarda las tareas en Recordatorios: hay que dar permiso una vez.
    private var accessCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(IrisColor.navy)
            Text("Conecta tus tareas")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(IrisColor.ink)
            Text(store.access == .denied
                 ? "Iris no tiene permiso para usar Recordatorios. Actívalo en Configuración › Iris › Recordatorios › Acceso total."
                 : "Iris guarda tus tareas en una lista llamada \"Iris\" en la app Recordatorios. Así también aparecen en tu pantalla de bloqueo.")
                .font(.system(size: 14))
                .foregroundStyle(IrisColor.muted)
                .multilineTextAlignment(.center)
            Button {
                if store.access == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    Task { await store.requestAccess() }
                }
            } label: {
                Text(store.access == .denied ? "Abrir Configuración" : "Dar permiso")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(IrisColor.paper)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(IrisColor.navy))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .glass()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(IrisColor.navy)
            Text("No tienes tareas pendientes")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(IrisColor.ink)
            Text("Toca + para agregar una.")
                .font(.system(size: 14))
                .foregroundStyle(IrisColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glass()
    }
}

struct TaskRow: View {
    let task: TaskItem
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { store.toggle(task) }
            } label: {
                ZStack {
                    if task.isDone {
                        Circle().fill(IrisColor.navy)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(IrisColor.paper)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .overlay(Circle().stroke(IrisColor.navy, lineWidth: 1.8))
                    }
                }
                .frame(width: 26, height: 26)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, -8)
            .accessibilityLabel(task.isDone ? "Marcar como pendiente: \(task.title)" : "Marcar como hecha: \(task.title)")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 16))
                    .foregroundStyle(task.isDone ? Color(hex: 0x5A6A80) : IrisColor.ink)
                    .strikethrough(task.isDone, color: Color(hex: 0x5A6A80))
                if let due = task.dueDate {
                    Text(dueText(due))
                        .font(.system(size: 13))
                        .foregroundStyle(IrisColor.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { store.delete(task) }
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }

    private func dueText(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return "Hoy · \(time)" }
        if cal.isDateInTomorrow(date) { return "Mañana · \(time)" }
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "es_CO")))
        return "\(day.prefix(1).uppercased() + day.dropFirst()) · \(time)"
    }
}

struct NewTaskSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hasDate = false
    @State private var date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("¿Qué tienes que hacer?", text: $title)
                    .focused($focused)
                Toggle("Con fecha", isOn: $hasDate.animation())
                if hasDate {
                    DatePicker("Para", selection: $date)
                        .environment(\.locale, Locale(identifier: "es_CO"))
                }
            }
            .navigationTitle("Nueva tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        store.add(title: title, dueDate: hasDate ? date : nil)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}
