import SwiftUI

struct VehicleFormView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let vehicleId: Int?

    @State private var type: VehicleType = .bike
    @State private var name = ""
    @State private var make = ""
    @State private var vehicleModel = ""
    @State private var regNo = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Picker(L10n.VehicleForm.type, selection: $type) {
                    ForEach(VehicleType.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Section {
                    TextField(L10n.VehicleForm.name, text: $name)
                    TextField(L10n.VehicleForm.make, text: $make)
                    TextField(L10n.VehicleForm.model, text: $vehicleModel)
                    TextField(L10n.VehicleForm.regNo, text: $regNo).textInputAutocapitalization(.characters)
                }
            }
            .themedForm()
            .navigationTitle(vehicleId == nil ? L10n.VehicleForm.newTitle : L10n.VehicleForm.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .themedBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save, action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let vehicleId, let v = try? model.store.vehicle(id: vehicleId) else { return }
        loaded = true
        type = v.type; name = v.name; make = v.make; vehicleModel = v.model; regNo = v.regNo
    }

    private func save() {
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespaces) }
        let input = VehicleInput(type: type, name: trim(name), make: trim(make), model: trim(vehicleModel), regNo: trim(regNo))
        do {
            try model.saveVehicle(id: vehicleId, input)
            dismiss()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
