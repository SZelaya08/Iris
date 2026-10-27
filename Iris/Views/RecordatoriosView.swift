import SwiftUI

/// Recordatorios a largo plazo. Cada uno llega como notificación al iPhone.
struct RecordatoriosView: View {
    let onSettings: () -> Void

    @EnvironmentObject private var store: ReminderStore
    @State private var showNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: "Recordatorios", onSettings: onSettings) {
                    Text("Te llegan como notificación")
                }

                if store.notificationsDenied {
                    Text("Las notificaciones están desactivadas. Actívalas en Configuración › Notificaciones › Iris para que te lleguen los avisos.")
                        .font(.system(size: 14))
                        .foregroundStyle(IrisColor.ink)
                        .padding(14)
                        .glass()
                }

                if !store.repeating.isEmpty {
                    group("Se repiten", store.repeating)
                }
                if !store.oneTime.isEmpty {
                    group("Una sola vez", store.oneTime)
                }

                Button {
                    showNew = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Nuevo recordatorio")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(IrisColor.navy)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .glass()
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    FlowerMark(lineWidth: 1.6)
                        .frame(width: 22, height: 22)
                    Text("También puedes decirle a Iris \"Recuérdame…\" y aparecerá aquí.")
                        .font(.system(size: 14))
                        .foregroundStyle(IrisColor.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(IrisColor.navy.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .sheet(isPresented: $showNew) {
            NewReminderSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private func group(_ title: String, _ items: [ReminderItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            VStack(spacing: 10) {
                ForEach(items) { item in
                    ReminderCard(item: item)
                }
            }
        }
    }
}

struct ReminderCard: View {
    let item: ReminderItem
    @EnvironmentObject private var store: ReminderStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.repeats ? "repeat" : "calendar")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(IrisColor.navy)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(IrisColor.navy.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(IrisColor.ink)
                Text(item.whenText)
                    .font(.system(size: 13))
                    .foregroundStyle(IrisColor.muted)
            }
            Spacer(minLength: 8)

            Text(item.remainingText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(IrisColor.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(IrisColor.navy.opacity(0.08)))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glass()
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { store.delete(item) }
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }
}

struct NewReminderSheet: View {
    @EnvironmentObject private var store: ReminderStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var rule: RepeatRule = .none
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("¿Qué te recuerdo?", text: $title)
                    .focused($focused)
                DatePicker("Cuándo", selection: $date, in: Date()...)
                    .environment(\.locale, Locale(identifier: "es_CO"))
                Picker("Repetir", selection: $rule) {
                    ForEach(RepeatRule.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
            }
            .navigationTitle("Nuevo recordatorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let item = ReminderItem(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date,
                            repeatRule: rule
                        )
                        Task {
                            await store.add(item)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}
