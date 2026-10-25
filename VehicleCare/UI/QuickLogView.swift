import SwiftUI

struct QuickLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let vehicleId: Int
    let kind: QuickKind

    @State private var date = Date()
    @State private var cost = ""
    @State private var litres = ""
    @State private var note = ""
    @State private var remind = true
    @State private var days = ""

    private var defaultDays: Int {
        switch kind {
        case .tyreAir: return model.settings.tyreIntervalDays
        case .petrol: return model.settings.petrolIntervalDays
        case .lube: return model.settings.lubeIntervalDays
        }
    }

    private var screenTitle: String {
        switch kind {
        case .tyreAir: return L10n.Detail.inflatedTyre
        case .petrol: return L10n.Detail.filledPetrol
        case .lube: return L10n.Detail.lubedChain
        }
    }

    /// Fuel and chain lube can have a cost; a tyre check cannot.
    private var hasCost: Bool { kind != .tyreAir }
    private var daysValue: Int? { Costs.parseInt(days).flatMap { (1...365).contains($0) ? $0 : nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(L10n.Quick.date, selection: $date, in: ...Date(), displayedComponents: .date)
                    if hasCost {
                        HStack {
                            Text(L10n.Quick.amount(model.settings.currency))
                            Spacer()
                            TextField(L10n.Quick.optional, text: $cost).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                        }
                    }
                    if kind == .petrol {
                        HStack {
                            Text(L10n.Quick.litres)
                            Spacer()
                            TextField(L10n.Quick.optional, text: $litres).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                        }
                    }
                    TextField(L10n.Quick.note, text: $note)
                }
                Section {
                    Toggle(L10n.Quick.remind, isOn: $remind)
                    if remind {
                        HStack {
                            Text(L10n.Quick.afterDays)
                            Spacer()
                            TextField(L10n.Quick.daysPlaceholder, text: $days).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 70)
                        }
                        if daysValue == nil { Text(L10n.Quick.daysError).font(.footnote).foregroundStyle(.red) }
                    }
                }
            }
            .themedForm()
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .themedBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save, action: save).disabled(remind && daysValue == nil)
                }
            }
            .onAppear { if days.isEmpty { days = String(defaultDays) } }
        }
    }

    private func save() {
        let input = QuickLogInput(
            vehicleId: vehicleId, kind: kind, date: DateUtil.string(date),
            cost: hasCost && !cost.trimmingCharacters(in: .whitespaces).isEmpty ? Costs.parseAmount(cost) : nil,
            litres: kind == .petrol && !litres.trimmingCharacters(in: .whitespaces).isEmpty ? Costs.parseAmount(litres) : nil,
            note: note.trimmingCharacters(in: .whitespaces))
        let name = (try? model.store.vehicle(id: vehicleId))?.name ?? "your vehicle"
        let remindDays = remind ? daysValue : nil
        model.attempt {
            if let message = try await model.logQuick(input, remindAfterDays: remindDays, vehicleName: name) { model.notice = message }
            dismiss()
        }
    }
}
