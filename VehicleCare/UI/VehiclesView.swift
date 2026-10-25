import SwiftUI

struct VehiclesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var route: Route?

    var body: some View {
        _ = model.revision
        let vehicles = (try? model.store.vehicles()) ?? []
        let reminders = (try? model.store.activeReminders()) ?? []

        return NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if vehicles.isEmpty {
                        EmptyState(title: L10n.Vehicles.emptyTitle, message: L10n.Vehicles.emptyMessage) {
                            Button(L10n.Vehicles.add) { route = .vehicleForm(id: nil) }.buttonStyle(.app()).frame(maxWidth: 240)
                        }
                    } else {
                        ForEach(vehicles) { vehicle in
                            NavigationLink(value: vehicle.id) {
                                VehicleCard(vehicle: vehicle, nextReminder: reminders.first { $0.vehicleId == vehicle.id }, currency: model.settings.currency)
                            }
                            .buttonStyle(.plain)
                        }
                        Button(L10n.Vehicles.add) { route = .vehicleForm(id: nil) }.buttonStyle(.app(.secondary))
                    }
                }
                .padding()
            }
            .background(theme.background)
            .navigationTitle(L10n.Vehicles.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { VehicleDetailView(vehicleId: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { route = .vehicleForm(id: nil) } label: { Image.app(.add) }.accessibilityLabel(L10n.Vehicles.add)
                }
            }
            .themedBars()
            .routeSheets($route)
            .onAppear {
                if model.pendingAddVehicle {
                    model.pendingAddVehicle = false
                    route = .vehicleForm(id: nil)
                }
            }
        }
    }
}

private struct VehicleCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let vehicle: Vehicle
    let nextReminder: Reminder?
    let currency: String

    var body: some View {
        let last = try? model.store.services(vehicleId: vehicle.id).first
        let spent = (try? model.store.totalSpent(vehicleId: vehicle.id)) ?? 0
        let subtitle = [vehicle.make, vehicle.model, vehicle.regNo].filter { !$0.isEmpty }.joined(separator: " · ")

        Card {
            HStack(spacing: 12) {
                Image.app(.vehicle(vehicle.type)).font(.title2).foregroundStyle(theme.accent)
                VStack(alignment: .leading) {
                    Text(vehicle.name).font(.headline).foregroundStyle(theme.textPrimary)
                    Text(subtitle.isEmpty ? vehicle.type.label : subtitle).font(.subheadline).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image.app(.forward).font(.footnote).foregroundStyle(theme.textSecondary)
            }
            Text(L10n.Vehicles.lastService(last.map { DateUtil.pretty($0.date) } ?? L10n.Vehicles.noneYet)).font(.subheadline).foregroundStyle(theme.textSecondary)
            Text(L10n.Vehicles.nextReminder(nextReminder.flatMap { DateUtil.parseISO($0.fireAt) }.map { DateUtil.pretty(DateUtil.string($0)) } ?? L10n.Vehicles.none))
                .font(.subheadline).foregroundStyle(theme.textSecondary)
            Text(L10n.Vehicles.totalSpent(Costs.format(currency, spent))).font(.subheadline).foregroundStyle(theme.textSecondary)
        }
    }
}
