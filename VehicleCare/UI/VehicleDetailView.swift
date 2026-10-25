import SwiftUI

struct VehicleDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let vehicleId: Int
    @State private var route: Route?
    @State private var confirmDelete = false

    var body: some View {
        _ = model.revision
        let vehicle = try? model.store.vehicle(id: vehicleId)

        return Group {
            if let vehicle {
                content(vehicle)
            } else {
                EmptyState(title: L10n.Detail.notFoundTitle, message: L10n.Detail.notFoundMessage)
            }
        }
        .background(theme.background)
        .navigationTitle(vehicle?.name ?? L10n.Detail.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .themedBars()
        .routeSheets($route)
    }

    @ViewBuilder
    private func content(_ vehicle: Vehicle) -> some View {
        let services = (try? model.store.services(vehicleId: vehicleId)) ?? []
        let logs = (try? model.store.quickLogs(vehicleId: vehicleId)) ?? []
        let reminders = (try? model.store.activeReminders(vehicleId: vehicleId)) ?? []
        let lastTyre = try? model.store.lastQuickLog(vehicleId: vehicleId, kind: .tyreAir)
        let lastPetrol = try? model.store.lastQuickLog(vehicleId: vehicleId, kind: .petrol)
        let isBike = vehicle.type == .bike
        let lastLube = isBike ? (try? model.store.lastQuickLog(vehicleId: vehicleId, kind: .lube)) : nil
        let entries = TimelineEntry.build(services: services, logs: logs)
        let subtitle = [vehicle.make, vehicle.model, vehicle.regNo].filter { !$0.isEmpty }.joined(separator: " · ")

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(theme.textSecondary) }

                Card {
                    Text(L10n.Detail.quickLogTitle).font(.headline).foregroundStyle(theme.textPrimary)
                    Text(L10n.Detail.tyreLast(lastTyre.flatMap { $0 }.map { DateUtil.pretty($0.date) } ?? L10n.Detail.never)).font(.subheadline).foregroundStyle(theme.textSecondary)
                    Text(L10n.Detail.petrolLast(lastPetrol.flatMap { $0 }.map { DateUtil.pretty($0.date) } ?? L10n.Detail.never)).font(.subheadline).foregroundStyle(theme.textSecondary)
                    if isBike {
                        Text(L10n.Detail.chainLubeLast(lastLube.flatMap { $0 }.map { DateUtil.pretty($0.date) } ?? L10n.Detail.never)).font(.subheadline).foregroundStyle(theme.textSecondary)
                    }
                    // two columns; a bike's third action (chain lube) wraps onto a second row
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        Button(L10n.Detail.inflatedTyre) { route = .quickLog(vehicleId: vehicleId, kind: .tyreAir) }.buttonStyle(.app(.secondary))
                        Button(L10n.Detail.filledPetrol) { route = .quickLog(vehicleId: vehicleId, kind: .petrol) }.buttonStyle(.app(.secondary))
                        if isBike {
                            Button(L10n.Detail.lubedChain) { route = .quickLog(vehicleId: vehicleId, kind: .lube) }.buttonStyle(.app(.secondary))
                        }
                    }
                    .padding(.top, 8)
                }

                Button(L10n.Detail.addService) { route = .serviceForm(vehicleId: vehicleId, id: nil) }.buttonStyle(.app())

                if !reminders.isEmpty {
                    Card {
                        Text(L10n.Detail.upcomingReminders).font(.headline).foregroundStyle(theme.textPrimary)
                        ForEach(reminders) { r in
                            Text(verbatim: "\(DateUtil.parseISO(r.fireAt).map { DateUtil.pretty(DateUtil.string($0)) } ?? r.fireAt) · \(ReminderService.title(for: r.kind))")
                                .font(.subheadline).foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                Text(L10n.Detail.history).font(.headline).foregroundStyle(theme.textPrimary).padding(.top, 4)
                if entries.isEmpty {
                    Text(L10n.Detail.nothingLogged).font(.subheadline).foregroundStyle(theme.textSecondary)
                } else {
                    ForEach(entries) { entry in
                        switch entry {
                        case .service(let s, _):
                            Button { route = .serviceForm(vehicleId: vehicleId, id: s.id) } label: {
                                TimelineRow(entry: entry, currency: model.settings.currency)
                            }
                            .buttonStyle(.plain)
                        case .quick(let q, _):
                            TimelineRow(entry: entry, currency: model.settings.currency)
                                .contextMenu {
                                    Button(L10n.Common.delete, role: .destructive) { try? model.store.deleteQuickLog(id: q.id); model.bump() }
                                }
                        }
                    }
                }

                VStack(spacing: 8) {
                    Button(L10n.Detail.edit) { route = .vehicleForm(id: vehicleId) }.buttonStyle(.app(.secondary))
                    Button(L10n.Detail.deleteVehicle) { confirmDelete = true }.buttonStyle(.app(.danger))
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .confirmationDialog(L10n.Detail.deleteTitle(vehicle.name), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.Common.delete, role: .destructive) {
                model.attempt {
                    try await model.deleteVehicle(id: vehicleId)
                    dismiss()
                }
            }
        } message: {
            Text(L10n.Detail.deleteMessage)
        }
    }
}
