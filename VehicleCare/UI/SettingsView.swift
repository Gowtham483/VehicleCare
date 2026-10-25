import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    @State private var route: Route?
    @State private var shareItems: [URL] = []
    @State private var showShare = false
    @State private var showImporter = false
    @State private var pendingBackup: BackupFile?
    @State private var confirmReplace = false
    @State private var confirmReset = false
    @State private var currency = ""
    @State private var busy = false

    var body: some View {
        _ = model.revision
        let settings = model.settings

        return NavigationStack {
            Form {
                Section {
                    AppearancePicker()
                } header: {
                    Text(L10n.Settings.appearanceSection)
                } footer: {
                    Text(L10n.Settings.deviceThemeFooter)
                }

                Section(L10n.Settings.remindersSection) {
                    Stepper(L10n.Settings.tyreInterval(L10n.Plural.days(settings.tyreIntervalDays)), value: binding(\.tyreIntervalDays), in: 1...365)
                    Stepper(L10n.Settings.petrolInterval(L10n.Plural.days(settings.petrolIntervalDays)), value: binding(\.petrolIntervalDays), in: 1...365)
                    Stepper(L10n.Settings.lubeInterval(L10n.Plural.days(settings.lubeIntervalDays)), value: binding(\.lubeIntervalDays), in: 1...365)
                    Stepper(L10n.Settings.leadDays(L10n.Plural.days(settings.serviceLeadDays)), value: binding(\.serviceLeadDays), in: 0...60)
                    Picker(L10n.Settings.notifyAt, selection: binding(\.notifyHour)) {
                        ForEach(0..<24, id: \.self) { Text(L10n.hourLabel($0)).tag($0) }
                    }
                    Button(L10n.Settings.testNotification) {
                        model.attempt {
                            let ok = await model.reminders.sendTest()
                            model.notice = ok ? L10n.Notice.testOk : L10n.Notice.testOff
                        }
                    }
                }

                Section {
                    HStack {
                        Text(L10n.Settings.currency)
                        Spacer()
                        TextField(L10n.Settings.currencyPlaceholder, text: $currency).multilineTextAlignment(.trailing).frame(width: 60)
                            .onSubmit(commitCurrency)
                    }
                    Button(L10n.Settings.tour) { route = .tour }
                } header: {
                    Text(L10n.Settings.generalSection)
                } footer: {
                    Text(L10n.Settings.retentionFooter(L10n.Plural.months(settings.retentionMonths)))
                }

                Section {
                    Button(L10n.Settings.export) { run { try BackupFiles.exportJSON(from: model.store) } }
                    Button(L10n.Settings.importData) { showImporter = true }
                    Button(L10n.Settings.exportCSV) { run { try BackupFiles.exportCSVs(from: model.store) } }
                } header: {
                    Text(L10n.Settings.backupSection)
                } footer: {
                    Text(L10n.Settings.backupFooter)
                }

                Section {
                    Button { route = .feedback } label: { Label(L10n.Settings.feedback, icon: .feedback) }
                    ShareLink(item: URL(string: AppInfo.appStoreURL)!, subject: Text(AppInfo.name), message: Text(AppInfo.shareMessage)) {
                        Label(L10n.Settings.share, icon: .share)
                    }
                } header: {
                    Text(L10n.Settings.supportSection)
                } footer: {
                    Text(L10n.Settings.supportFooter)
                }

                Section {
                    Button(L10n.Settings.reset, role: .destructive) { confirmReset = true }
                } header: {
                    Text(L10n.Settings.dangerSection)
                }

                Section {
                    LabeledContent(L10n.Settings.version, value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                }
            }
            .themedForm()
            .disabled(busy)
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .themedBars()
            .routeSheets($route)
            .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .data]) { result in
                handlePicked(result)
            }
            .confirmationDialog(L10n.Transfer.importTitle, isPresented: Binding(get: { pendingBackup != nil && !confirmReplace }, set: { if !$0 && !confirmReplace { pendingBackup = nil } }), titleVisibility: .visible) {
                Button(L10n.Transfer.merge) { importPending(.merge) }
                Button(L10n.Transfer.replaceAll, role: .destructive) { confirmReplace = true }
                Button(L10n.Common.cancel, role: .cancel) { pendingBackup = nil }
            } message: {
                if let b = pendingBackup {
                    let s = Backup.summary(b)
                    Text(L10n.Transfer.importMessage(L10n.Transfer.summary(L10n.Plural.vehicles(s.vehicles), L10n.Plural.services(s.services), L10n.Plural.quickLogs(s.quickLogs))))
                }
            }
            .alert(L10n.Transfer.replaceTitle, isPresented: $confirmReplace) {
                Button(L10n.Transfer.replaceConfirm, role: .destructive) { importPending(.replace) }
                Button(L10n.Common.cancel, role: .cancel) { pendingBackup = nil }
            } message: {
                Text(L10n.Transfer.replaceMessage)
            }
            .confirmationDialog(L10n.Transfer.resetTitle, isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L10n.Transfer.resetConfirm, role: .destructive) { model.attempt { try await model.resetAll() } }
            } message: {
                Text(L10n.Transfer.resetMessage)
            }
            .onAppear { currency = model.settings.currency }
            .onDisappear(perform: commitCurrency)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Int> {
        Binding(get: { model.settings[keyPath: keyPath] }, set: { value in model.update { $0[keyPath: keyPath] = value } })
    }

    private func commitCurrency() {
        let trimmed = currency.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { currency = model.settings.currency } else if trimmed != model.settings.currency { model.update { $0.currency = String(trimmed.prefix(4)) } }
    }

    /// Builds the file(s) and opens the share sheet.
    private func run(_ work: () throws -> some Any) {
        do {
            let result = try work()
            shareItems = (result as? [URL]) ?? [result as! URL]
            showShare = true
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func handlePicked(_ result: Result<URL, Error>) {
        do {
            let data = try BackupFiles.read(try result.get())
            switch Backup.validate(data) {
            case .success(let backup): pendingBackup = backup
            case .failure(let error): model.notice = L10n.Transfer.cantImport(error.message)
            }
        } catch {
            model.errorMessage = L10n.Transfer.unreadable
        }
    }

    private func importPending(_ mode: ImportMode) {
        guard let backup = pendingBackup else { return }
        pendingBackup = nil
        busy = true
        model.attempt {
            defer { busy = false }
            let added = try await model.importBackup(backup, mode: mode)
            currency = model.settings.currency
            model.notice = L10n.Transfer.added(L10n.Plural.vehicles(added.vehicles), L10n.Plural.services(added.services), L10n.Plural.quickLogs(added.quickLogs))
        }
    }
}
