import SwiftUI

private struct PartRow: Identifiable {
    let id = UUID()
    var name = ""
    var price = ""
    var qty = "1"

    var asInput: PartInput? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let q = Costs.parseAmount(qty)
        return PartInput(name: trimmed, price: Costs.parseAmount(price), qty: q > 0 ? q : 1)
    }
}

struct ServiceFormView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let vehicleId: Int
    let serviceId: Int?

    @State private var title = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var labour = ""
    @State private var parts = [PartRow()]
    @State private var remind = false
    @State private var nextDue = DateUtil.addMonths(Date(), 6)
    @State private var confirmDelete = false
    @State private var loaded = false

    private var partInputs: [PartInput] { parts.compactMap(\.asInput) }
    private var total: Double { Costs.serviceTotal(labour: Costs.parseAmount(labour), parts: partInputs) }
    private var currency: String { model.settings.currency }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.Service.titleField, text: $title)
                    DatePicker(L10n.Service.date, selection: $date, displayedComponents: .date)
                    TextField(L10n.Service.notes, text: $notes, axis: .vertical).lineLimit(3...8)
                }

                Section(L10n.Service.costSection) {
                    HStack {
                        Text(L10n.Service.labour(currency))
                        Spacer()
                        TextField("0", text: $labour).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                    }
                }

                Section(L10n.Service.partsSection) {
                    ForEach($parts) { $row in
                        HStack(spacing: 8) {
                            TextField(L10n.Service.part, text: $row.name)
                            TextField(L10n.Service.price, text: $row.price).keyboardType(.decimalPad).frame(width: 70).multilineTextAlignment(.trailing)
                            Text("×").foregroundStyle(theme.textSecondary)
                            TextField(L10n.Service.qty, text: $row.qty).keyboardType(.decimalPad).frame(width: 40).multilineTextAlignment(.trailing)
                        }
                    }
                    .onDelete { parts.remove(atOffsets: $0); if parts.isEmpty { parts = [PartRow()] } }
                    Button(L10n.Service.addPart) { parts.append(PartRow()) }
                    HStack {
                        Text(L10n.Service.partsTotal).foregroundStyle(theme.textSecondary)
                        Spacer()
                        Text(Costs.format(currency, Costs.partsTotal(partInputs)))
                    }
                }

                Section {
                    HStack {
                        Text(L10n.Service.total).font(.headline)
                        Spacer()
                        Text(Costs.format(currency, total)).font(.title3.bold())
                    }
                }

                Section {
                    Toggle(L10n.Service.nextToggle, isOn: $remind)
                    if remind {
                        DatePicker(L10n.Service.nextDue, selection: $nextDue, in: Date()..., displayedComponents: .date)
                        HStack {
                            ForEach([3, 6, 12], id: \.self) { months in
                                Button(L10n.Service.inMonths(L10n.Plural.months(months))) { nextDue = DateUtil.addMonths(date, months) }.buttonStyle(.bordered)
                            }
                        }
                    }
                } header: {
                    Text(L10n.Service.nextHeader)
                } footer: {
                    if remind {
                        Text(L10n.Service.nextFooter(L10n.Plural.days(model.settings.serviceLeadDays), L10n.hourLabel(model.settings.notifyHour)))
                    }
                }

                if serviceId != nil {
                    Section { Button(L10n.Service.deleteButton, role: .destructive) { confirmDelete = true } }
                }
            }
            .themedForm()
            .navigationTitle(serviceId == nil ? L10n.Service.newTitle : L10n.Service.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .themedBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save, action: save).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(L10n.Service.deleteTitle, isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L10n.Common.delete, role: .destructive, action: delete)
            } message: {
                Text(L10n.Service.deleteMessage)
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let serviceId, let s = try? model.store.service(id: serviceId) else { return }
        loaded = true
        title = s.title
        date = DateUtil.parse(s.date) ?? Date()
        notes = s.notes
        labour = s.labourCost == 0 ? "" : Costs.editableText(s.labourCost)
        if let due = s.nextDueDate, let d = DateUtil.parse(due) { remind = true; nextDue = d }
        let stored = (try? model.store.parts(serviceId: serviceId)) ?? []
        if !stored.isEmpty {
            parts = stored.map { PartRow(name: $0.name, price: Costs.editableText($0.price), qty: Costs.editableText($0.qty)) }
        }
    }

    private func save() {
        let input = ServiceInput(
            vehicleId: vehicleId, date: DateUtil.string(date), title: title.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), labourCost: Costs.parseAmount(labour), parts: partInputs,
            nextDueDate: remind ? DateUtil.string(nextDue) : nil)
        let name = (try? model.store.vehicle(id: vehicleId))?.name ?? "Your vehicle"
        model.attempt {
            if let message = try await model.saveService(input, id: serviceId, vehicleName: name) { model.notice = message }
            dismiss()
        }
    }

    private func delete() {
        guard let serviceId, let service = try? model.store.service(id: serviceId) else { return }
        model.attempt {
            try await model.deleteService(service)
            dismiss()
        }
    }
}
