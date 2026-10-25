import Foundation

/// Every user-visible string in the app goes through here, so all text lives in
/// `Resources/<language>.lproj/Localizable.strings` (and `.stringsdict` for plurals).
///
/// Rules (checked by LocalizationTests):
/// - no string literals in views or logic for anything the user reads: add a key instead
/// - placeholders are positional (`%1$@`, `%2$d`) so translators can reorder them
/// - counts that change the wording go through `Plural` (stringsdict), never "item(s)"
/// - things that must NOT be translated (database values, backup keys, CSV headers, the developer-facing
///   feedback email) do not use this file
enum L10n {
    /// The bundle strings are read from. Tests point this at a single `.lproj` folder.
    static var bundle: Bundle = .main
    /// Tests set this to pick a language without changing the device settings.
    static var localeOverride: Locale?

    /// The app's language (what iOS resolved for this app) with Western digits (0-9) forced for every language.
    static var locale: Locale {
        if let localeOverride { return makeLocale(localeOverride) }
        let language = bundle.preferredLocalizations.first ?? "en"
        if let region = Locale.current.region?.identifier { return makeLocale(Locale(identifier: "\(language)_\(region)")) }
        return makeLocale(Locale(identifier: language))
    }

    static func makeLocale(_ base: Locale) -> Locale {
        var components = Locale.Components(locale: base)
        components.numberingSystem = Locale.NumberingSystem("latn")
        return Locale(components: components)
    }

    static var isRTL: Bool { locale.language.characterDirection == .rightToLeft }

    // MARK: Lookup

    /// Looks `key` up and fills in `args`. A missing key shows as "⚠︎key" so it cannot go unnoticed.
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: "⚠︎\(key)", table: nil)
        return args.isEmpty ? format : String(format: format, locale: locale, arguments: args)
    }

    /// Looks up a plural entry in the `.stringsdict` and formats it for `count`.
    static func plural(_ key: String, _ count: Int) -> String {
        let format = bundle.localizedString(forKey: key, value: "⚠︎\(key)", table: nil)
        return String(format: format, locale: locale, count)
    }

    // MARK: Bidirectional text

    /// Keeps user-supplied text (a vehicle name, say) from reordering the punctuation around it when you
    /// join strings yourself. Not needed for `%@` arguments: Foundation already isolates those in
    /// right-to-left languages. Only applied in right-to-left languages.
    static func isolate(_ text: String) -> String { isRTL ? "\u{2068}\(text)\u{2069}" : text }

    /// Keeps a left-to-right run (an amount such as "₹1,200") together inside right-to-left text.
    static func ltr(_ text: String) -> String { isRTL ? "\u{2066}\(text)\u{2069}" : text }

    // MARK: Formatting

    private static var formatterCache: [String: DateFormatter] = [:]

    /// A date formatter using the locale's own ordering for `template` (for example "dMMMyyyy").
    static func dateFormatter(template: String) -> DateFormatter {
        let id = locale.identifier + "|" + template
        if let cached = formatterCache[id] { return cached }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatterCache[id] = formatter
        return formatter
    }

    /// "9 AM" / "09:00" / "9 ص", whichever the locale uses, for an hour 0-23.
    static func hourLabel(_ hour: Int) -> String {
        let date = Calendar(identifier: .gregorian).date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return dateFormatter(template: "j").string(from: date)
    }
}

// MARK: - Typed accessors (one namespace per screen or feature)

extension L10n {
    enum Common {
        static var save: String { L10n.tr("common.save") }
        static var cancel: String { L10n.tr("common.cancel") }
        static var delete: String { L10n.tr("common.delete") }
        static var done: String { L10n.tr("common.done") }
        static var ok: String { L10n.tr("common.ok") }
        static var skip: String { L10n.tr("common.skip") }
        static var next: String { L10n.tr("common.next") }
        static var errorTitle: String { L10n.tr("common.errorTitle") }
        static var noteTitle: String { L10n.tr("common.noteTitle") }
        static var bike: String { L10n.tr("common.bike") }
        static var car: String { L10n.tr("common.car") }
    }

    enum Onboarding {
        static var skipAccessibility: String { L10n.tr("onboarding.skipAccessibility") }
        static var addFirstVehicle: String { L10n.tr("onboarding.addFirstVehicle") }
        static var gotIt: String { L10n.tr("onboarding.gotIt") }
        static var servicesTitle: String { L10n.tr("onboarding.servicesTitle") }
        static var servicesText: String { L10n.tr("onboarding.servicesText") }
        static var quickTitle: String { L10n.tr("onboarding.quickTitle") }
        static var quickText: String { L10n.tr("onboarding.quickText") }
        static var remindersTitle: String { L10n.tr("onboarding.remindersTitle") }
        static var remindersText: String { L10n.tr("onboarding.remindersText") }
        static var backupTitle: String { L10n.tr("onboarding.backupTitle") }
        static var backupText: String { L10n.tr("onboarding.backupText") }
        static var startTitle: String { L10n.tr("onboarding.startTitle") }
        static var startText: String { L10n.tr("onboarding.startText") }
    }

    enum Vehicles {
        static var title: String { L10n.tr("vehicles.title") }
        static var emptyTitle: String { L10n.tr("vehicles.emptyTitle") }
        static var emptyMessage: String { L10n.tr("vehicles.emptyMessage") }
        static var add: String { L10n.tr("vehicles.add") }
        static func lastService(_ date: String) -> String { L10n.tr("vehicles.lastService", date) }
        static var noneYet: String { L10n.tr("vehicles.noneYet") }
        static func nextReminder(_ date: String) -> String { L10n.tr("vehicles.nextReminder", date) }
        static var none: String { L10n.tr("vehicles.none") }
        static func totalSpent(_ amount: String) -> String { L10n.tr("vehicles.totalSpent", amount) }
    }

    enum Detail {
        static var notFoundTitle: String { L10n.tr("detail.notFoundTitle") }
        static var notFoundMessage: String { L10n.tr("detail.notFoundMessage") }
        static var navTitle: String { L10n.tr("detail.navTitle") }
        static var quickLogTitle: String { L10n.tr("detail.quickLogTitle") }
        static func tyreLast(_ date: String) -> String { L10n.tr("detail.tyreLast", date) }
        static func petrolLast(_ date: String) -> String { L10n.tr("detail.petrolLast", date) }
        static var never: String { L10n.tr("detail.never") }
        static var inflatedTyre: String { L10n.tr("detail.inflatedTyre") }
        static var filledPetrol: String { L10n.tr("detail.filledPetrol") }
        static var lubedChain: String { L10n.tr("detail.lubedChain") }
        static func chainLubeLast(_ date: String) -> String { L10n.tr("detail.chainLubeLast", date) }
        static var addService: String { L10n.tr("detail.addService") }
        static var upcomingReminders: String { L10n.tr("detail.upcomingReminders") }
        static var history: String { L10n.tr("detail.history") }
        static var nothingLogged: String { L10n.tr("detail.nothingLogged") }
        static var edit: String { L10n.tr("detail.edit") }
        static var deleteVehicle: String { L10n.tr("detail.deleteVehicle") }
        static func deleteTitle(_ name: String) -> String { L10n.tr("detail.deleteTitle", name) }
        static var deleteMessage: String { L10n.tr("detail.deleteMessage") }
    }

    enum VehicleForm {
        static var type: String { L10n.tr("vehicleForm.type") }
        static var newTitle: String { L10n.tr("vehicleForm.newTitle") }
        static var editTitle: String { L10n.tr("vehicleForm.editTitle") }
        static var name: String { L10n.tr("vehicleForm.name") }
        static var make: String { L10n.tr("vehicleForm.make") }
        static var model: String { L10n.tr("vehicleForm.model") }
        static var regNo: String { L10n.tr("vehicleForm.regNo") }
    }

    enum Service {
        static var newTitle: String { L10n.tr("service.newTitle") }
        static var editTitle: String { L10n.tr("service.editTitle") }
        static var titleField: String { L10n.tr("service.titleField") }
        static var date: String { L10n.tr("service.date") }
        static var notes: String { L10n.tr("service.notes") }
        static var costSection: String { L10n.tr("service.costSection") }
        static func labour(_ currency: String) -> String { L10n.tr("service.labour", currency) }
        static var partsSection: String { L10n.tr("service.partsSection") }
        static var part: String { L10n.tr("service.part") }
        static var price: String { L10n.tr("service.price") }
        static var qty: String { L10n.tr("service.qty") }
        static var addPart: String { L10n.tr("service.addPart") }
        static var partsTotal: String { L10n.tr("service.partsTotal") }
        static var total: String { L10n.tr("service.total") }
        static var nextToggle: String { L10n.tr("service.nextToggle") }
        static var nextDue: String { L10n.tr("service.nextDue") }
        static var nextHeader: String { L10n.tr("service.nextHeader") }
        static func nextFooter(_ daysBefore: String, _ time: String) -> String { L10n.tr("service.nextFooter", daysBefore, time) }
        static func inMonths(_ months: String) -> String { L10n.tr("service.inMonths", months) }
        static var deleteButton: String { L10n.tr("service.deleteButton") }
        static var deleteTitle: String { L10n.tr("service.deleteTitle") }
        static var deleteMessage: String { L10n.tr("service.deleteMessage") }
    }

    enum Quick {
        static var date: String { L10n.tr("quick.date") }
        static func amount(_ currency: String) -> String { L10n.tr("quick.amount", currency) }
        static var litres: String { L10n.tr("quick.litres") }
        static var optional: String { L10n.tr("quick.optional") }
        static var note: String { L10n.tr("quick.note") }
        static var remind: String { L10n.tr("quick.remind") }
        static var afterDays: String { L10n.tr("quick.afterDays") }
        static var daysPlaceholder: String { L10n.tr("quick.daysPlaceholder") }
        static var daysError: String { L10n.tr("quick.daysError") }
    }

    enum History {
        static var title: String { L10n.tr("history.title") }
        static var emptyTitle: String { L10n.tr("history.emptyTitle") }
        static var emptyMessage: String { L10n.tr("history.emptyMessage") }
        static var all: String { L10n.tr("history.all") }
        static var tyreChecked: String { L10n.tr("history.tyreChecked") }
        static var petrolFilled: String { L10n.tr("history.petrolFilled") }
        static var chainLubed: String { L10n.tr("history.chainLubed") }
        static func litresValue(_ litres: String) -> String { L10n.tr("history.litresValue", litres) }
    }

    enum Settings {
        static var title: String { L10n.tr("settings.title") }
        static var remindersSection: String { L10n.tr("settings.remindersSection") }
        static func tyreInterval(_ interval: String) -> String { L10n.tr("settings.tyreInterval", interval) }
        static func petrolInterval(_ interval: String) -> String { L10n.tr("settings.petrolInterval", interval) }
        static func lubeInterval(_ interval: String) -> String { L10n.tr("settings.lubeInterval", interval) }
        static func leadDays(_ interval: String) -> String { L10n.tr("settings.leadDays", interval) }
        static var notifyAt: String { L10n.tr("settings.notifyAt") }
        static var testNotification: String { L10n.tr("settings.testNotification") }
        static var generalSection: String { L10n.tr("settings.generalSection") }
        static var currency: String { L10n.tr("settings.currency") }
        static var currencyPlaceholder: String { L10n.tr("settings.currencyPlaceholder") }
        static var tour: String { L10n.tr("settings.tour") }
        static func retentionFooter(_ period: String) -> String { L10n.tr("settings.retentionFooter", period) }
        static var backupSection: String { L10n.tr("settings.backupSection") }
        static var export: String { L10n.tr("settings.export") }
        static var importData: String { L10n.tr("settings.importData") }
        static var exportCSV: String { L10n.tr("settings.exportCSV") }
        static var backupFooter: String { L10n.tr("settings.backupFooter") }
        static var supportSection: String { L10n.tr("settings.supportSection") }
        static var feedback: String { L10n.tr("settings.feedback") }
        static var share: String { L10n.tr("settings.share") }
        static var supportFooter: String { L10n.tr("settings.supportFooter") }
        static var dangerSection: String { L10n.tr("settings.dangerSection") }
        static var reset: String { L10n.tr("settings.reset") }
        static var version: String { L10n.tr("settings.version") }
        static var appearanceSection: String { L10n.tr("settings.appearanceSection") }
        static var deviceTheme: String { L10n.tr("settings.deviceTheme") }
        static var deviceThemeFooter: String { L10n.tr("settings.deviceThemeFooter") }
        static var lightTheme: String { L10n.tr("settings.lightTheme") }
        static var darkTheme: String { L10n.tr("settings.darkTheme") }
    }

    enum Transfer {
        static var importTitle: String { L10n.tr("transfer.importTitle") }
        static var merge: String { L10n.tr("transfer.merge") }
        static var replaceAll: String { L10n.tr("transfer.replaceAll") }
        static func importMessage(_ summary: String) -> String { L10n.tr("transfer.importMessage", summary) }
        static func summary(_ vehicles: String, _ services: String, _ quickLogs: String) -> String { L10n.tr("transfer.summary", vehicles, services, quickLogs) }
        static func added(_ vehicles: String, _ services: String, _ quickLogs: String) -> String { L10n.tr("transfer.added", vehicles, services, quickLogs) }
        static var replaceTitle: String { L10n.tr("transfer.replaceTitle") }
        static var replaceConfirm: String { L10n.tr("transfer.replaceConfirm") }
        static var replaceMessage: String { L10n.tr("transfer.replaceMessage") }
        static func cantImport(_ reason: String) -> String { L10n.tr("transfer.cantImport", reason) }
        static var unreadable: String { L10n.tr("transfer.unreadable") }
        static var resetTitle: String { L10n.tr("transfer.resetTitle") }
        static var resetConfirm: String { L10n.tr("transfer.resetConfirm") }
        static var resetMessage: String { L10n.tr("transfer.resetMessage") }
    }

    enum Feedback {
        static var title: String { L10n.tr("feedback.title") }
        static var type: String { L10n.tr("feedback.type") }
        static var categoryBug: String { L10n.tr("feedback.categoryBug") }
        static var categoryIdea: String { L10n.tr("feedback.categoryIdea") }
        static var categoryOther: String { L10n.tr("feedback.categoryOther") }
        static var messageHeader: String { L10n.tr("feedback.messageHeader") }
        static var messagePlaceholder: String { L10n.tr("feedback.messagePlaceholder") }
        static func messageFooter(_ email: String) -> String { L10n.tr("feedback.messageFooter", email) }
        static var attachmentsHeader: String { L10n.tr("feedback.attachmentsHeader") }
        static func attachmentsFooter(_ files: String, _ size: String) -> String { L10n.tr("feedback.attachmentsFooter", files, size) }
        static var addMedia: String { L10n.tr("feedback.addMedia") }
        static var addFile: String { L10n.tr("feedback.addFile") }
        static func remove(_ name: String) -> String { L10n.tr("feedback.remove", name) }
        static var deviceInfo: String { L10n.tr("feedback.deviceInfo") }
        static var deviceInfoFooter: String { L10n.tr("feedback.deviceInfoFooter") }
        static var send: String { L10n.tr("feedback.send") }
        static var thanks: String { L10n.tr("feedback.thanks") }
        static var noMailTitle: String { L10n.tr("feedback.noMailTitle") }
        static var shareOther: String { L10n.tr("feedback.shareOther") }
        static var copyEmail: String { L10n.tr("feedback.copyEmail") }
        static var noMailMessage: String { L10n.tr("feedback.noMailMessage") }
        static var attachmentTitle: String { L10n.tr("feedback.attachmentTitle") }
        static func tooMany(_ files: String) -> String { L10n.tr("feedback.tooMany", files) }
        static func tooLarge(_ name: String, _ total: String) -> String { L10n.tr("feedback.tooLarge", name, total) }
        static var loadFailed: String { L10n.tr("feedback.loadFailed") }
        static func readFailed(_ name: String) -> String { L10n.tr("feedback.readFailed", name) }
    }

    enum Share {
        static func message(_ appName: String) -> String { L10n.tr("share.message", appName) }
    }

    enum Reminder {
        static var tyreTitle: String { L10n.tr("reminder.tyreTitle") }
        static var petrolTitle: String { L10n.tr("reminder.petrolTitle") }
        static var lubeTitle: String { L10n.tr("reminder.lubeTitle") }
        static var serviceTitle: String { L10n.tr("reminder.serviceTitle") }
        static func tyreBody(_ vehicle: String) -> String { L10n.tr("reminder.tyreBody", vehicle) }
        static func petrolBody(_ vehicle: String) -> String { L10n.tr("reminder.petrolBody", vehicle) }
        static func lubeBody(_ vehicle: String) -> String { L10n.tr("reminder.lubeBody", vehicle) }
        static func serviceBody(_ vehicle: String, _ title: String, _ date: String) -> String { L10n.tr("reminder.serviceBody", vehicle, title, date) }
        static var testBody: String { L10n.tr("reminder.testBody") }
    }

    enum Notice {
        static var servicePassed: String { L10n.tr("notice.servicePassed") }
        static var serviceNoNotifications: String { L10n.tr("notice.serviceNoNotifications") }
        static var quickNoNotifications: String { L10n.tr("notice.quickNoNotifications") }
        static var testOk: String { L10n.tr("notice.testOk") }
        static var testOff: String { L10n.tr("notice.testOff") }
    }

    enum BackupError {
        static var notJSON: String { L10n.tr("backupError.notJSON") }
        static func notBackup(_ appName: String) -> String { L10n.tr("backupError.notBackup", appName) }
        static var noVersion: String { L10n.tr("backupError.noVersion") }
        static var newer: String { L10n.tr("backupError.newer") }
        static func missing(_ name: String) -> String { L10n.tr("backupError.missing", name) }
        static func invalidIn(_ name: String) -> String { L10n.tr("backupError.invalidIn", name) }
        static var unreadable: String { L10n.tr("backupError.unreadable") }
        static func invalidField(_ field: String, _ table: String, _ entry: Int) -> String { L10n.tr("backupError.invalidField", field, table, entry) }
        static var dangling: String { L10n.tr("backupError.dangling") }
    }

    enum App {
        static func startupError(_ appName: String, _ detail: String) -> String { L10n.tr("app.startupError", appName, detail) }
    }

    /// Counts that change the wording (one day / 3 days). Backed by Localizable.stringsdict.
    enum Plural {
        static func days(_ count: Int) -> String { L10n.plural("plural.days", count) }
        static func months(_ count: Int) -> String { L10n.plural("plural.months", count) }
        static func vehicles(_ count: Int) -> String { L10n.plural("plural.vehicles", count) }
        static func services(_ count: Int) -> String { L10n.plural("plural.services", count) }
        static func quickLogs(_ count: Int) -> String { L10n.plural("plural.quickLogs", count) }
        static func files(_ count: Int) -> String { L10n.plural("plural.files", count) }
    }
}
