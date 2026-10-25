import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var filter: Int?
    @State private var route: Route?

    var body: some View {
        _ = model.revision
        let vehicles = (try? model.store.vehicles()) ?? []
        let names = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0.name) })
        let services = ((try? model.store.services()) ?? []).filter { filter == nil || $0.vehicleId == filter }
        let logs = ((try? model.store.quickLogs()) ?? []).filter { filter == nil || $0.vehicleId == filter }
        let entries = TimelineEntry.build(services: services, logs: logs, vehicleNames: names)
        let months = Dictionary(grouping: entries) { String($0.date.prefix(7)) }.sorted { $0.key > $1.key }
        let years = Dictionary(grouping: entries) { String($0.date.prefix(4)) }.mapValues { $0.reduce(0) { $0 + $1.amount } }.sorted { $0.key > $1.key }
        let currency = model.settings.currency

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if vehicles.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                chip(L10n.History.all, selected: filter == nil) { filter = nil }
                                ForEach(vehicles) { v in chip(v.name, selected: filter == v.id) { filter = v.id } }
                            }
                        }
                    }
                    if !years.isEmpty {
                        Text(years.map { "\($0.key): \(Costs.format(currency, $0.value))" }.joined(separator: "   "))
                            .font(.subheadline).foregroundStyle(theme.textSecondary)
                    }
                    if months.isEmpty {
                        EmptyState(title: L10n.History.emptyTitle, message: L10n.History.emptyMessage)
                    }
                    ForEach(months, id: \.key) { month, items in
                        HStack {
                            Text(DateUtil.monthTitle(month)).font(.headline)
                            Spacer()
                            Text(Costs.format(currency, items.reduce(0) { $0 + $1.amount })).font(.headline)
                        }
                        .foregroundStyle(theme.textPrimary)
                        .padding(.top, 8)
                        ForEach(items) { entry in
                            if case .service(let s, _) = entry {
                                Button { route = .serviceForm(vehicleId: s.vehicleId, id: s.id) } label: { TimelineRow(entry: entry, currency: currency) }
                                    .buttonStyle(.plain)
                            } else {
                                TimelineRow(entry: entry, currency: currency)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(theme.background)
            .navigationTitle(L10n.History.title)
            .navigationBarTitleDisplayMode(.inline)
            .themedBars()
            .routeSheets($route)
        }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? theme.accent : theme.surfaceAlt, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
