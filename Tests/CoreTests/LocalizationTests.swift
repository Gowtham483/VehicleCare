import XCTest
@testable import Core

/// Reads the real `.strings` / `.stringsdict` files from the source tree.
private enum Files {
    static let root = TestLocalization.resources.deletingLastPathComponent().deletingLastPathComponent()
    static let languages = ["en", "ar"]

    static func strings(_ language: String) -> [String: String] {
        let url = TestLocalization.folder(language).appendingPathComponent("Localizable.strings")
        return (NSDictionary(contentsOf: url) as? [String: String]) ?? [:]
    }

    static func plurals(_ language: String) -> [String: [String: Any]] {
        let url = TestLocalization.folder(language).appendingPathComponent("Localizable.stringsdict")
        return (NSDictionary(contentsOf: url) as? [String: [String: Any]]) ?? [:]
    }

    static func swiftFiles(under folders: [String]) -> [URL] {
        var found: [URL] = []
        for folder in folders {
            let dir = root.appendingPathComponent(folder)
            let items = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
            found += items.filter { $0.pathExtension == "swift" }
        }
        return found
    }

    static func text(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
}

private func matches(_ pattern: String, in text: String) -> [[String]] {
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).map { m in
        (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
        }
    }
}

// MARK: - The string files themselves

final class StringFileTests: CoreTestCase {
    func testFilesLoad() {
        for language in Files.languages {
            XCTAssertFalse(Files.strings(language).isEmpty, "\(language) Localizable.strings missing or unreadable")
            XCTAssertFalse(Files.plurals(language).isEmpty, "\(language) Localizable.stringsdict missing or unreadable")
        }
    }

    func testSameKeysInEveryLanguage() {
        let en = Set(Files.strings("en").keys)
        for language in Files.languages where language != "en" {
            let other = Set(Files.strings(language).keys)
            XCTAssertEqual(en.subtracting(other), [], "\(language) is missing keys")
            XCTAssertEqual(other.subtracting(en), [], "\(language) has keys English does not")
        }
        let pluralsEN = Set(Files.plurals("en").keys)
        for language in Files.languages where language != "en" {
            XCTAssertEqual(pluralsEN, Set(Files.plurals(language).keys), "\(language) plural keys differ")
        }
    }

    func testNoEmptyTranslations() {
        for language in Files.languages {
            for (key, value) in Files.strings(language) {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(language): \(key) is empty")
            }
        }
    }

    func testPlaceholdersMatchAcrossLanguages() {
        let pattern = #"%(?:(\d+)\$)?(@|d|lld|f)"#
        func placeholders(_ text: String) -> [String] {
            matches(pattern, in: text).map { "\($0[1].isEmpty ? "-" : $0[1]):\($0[2])" }.sorted()
        }
        let en = Files.strings("en")
        for language in Files.languages where language != "en" {
            for (key, english) in en {
                guard let translated = Files.strings(language)[key] else { continue }
                XCTAssertEqual(placeholders(english), placeholders(translated), "\(language): placeholders of \(key) differ from English")
            }
        }
        // More than one placeholder in a string must be positional so translators can reorder them.
        for (key, text) in en {
            let found = matches(pattern, in: text)
            if found.count > 1 { XCTAssertTrue(found.allSatisfy { !$0[1].isEmpty }, "\(key) has several placeholders but not all are positional") }
        }
    }

    func testEveryKeyInTheFilesIsUsedByL10nAndViceVersa() {
        let source = Files.text(Files.root.appendingPathComponent("VehicleCare/Core/L10n.swift"))
        let used = Set(matches(#"(?:tr|plural)\("([^"]+)""#, in: source).map { $0[1] })
        let defined = Set(Files.strings("en").keys).union(Files.plurals("en").keys)
        XCTAssertEqual(used.subtracting(defined), [], "L10n refers to keys that are not in the string files")
        XCTAssertEqual(defined.subtracting(used), [], "string-file keys that no L10n accessor uses")
    }

    func testEveryAccessorIsUsedSomewhereInTheApp() {
        let l10n = Files.root.appendingPathComponent("VehicleCare/Core/L10n.swift")
        var namespace = ""
        var accessors: [String] = []
        for line in Files.text(l10n).components(separatedBy: "\n") {
            if let m = matches(#"^    enum (\w+) \{"#, in: line).first { namespace = m[1] }
            if let m = matches(#"^        static (?:var|func) (\w+)"#, in: line).first, !namespace.isEmpty { accessors.append("\(namespace).\(m[1])") }
        }
        let others = Files.swiftFiles(under: ["VehicleCare"]).filter { $0 != l10n }.map(Files.text).joined(separator: "\n")
        let unused = accessors.filter { !others.contains("L10n.\($0)") && !$0.hasPrefix("Plural.") }
        XCTAssertEqual(unused, [], "accessors never used by the app")
        let pluralUnused = accessors.filter { $0.hasPrefix("Plural.") }.filter { !others.contains("L10n.\($0)") }
        XCTAssertEqual(pluralUnused, [], "plural accessors never used by the app")
    }

    func testPluralCategoriesAreCompleteForEachLanguage() {
        let needed: [String: Set<String>] = ["en": ["one", "other"], "ar": ["zero", "one", "two", "few", "many", "other"]]
        for language in Files.languages {
            for (key, entry) in Files.plurals(language) {
                guard let variants = entry["count"] as? [String: String] else { XCTFail("\(language) \(key) has no count rule"); continue }
                let categories = Set(variants.keys).subtracting(["NSStringFormatSpecTypeKey", "NSStringFormatValueTypeKey"])
                XCTAssertEqual(categories, needed[language], "\(language) \(key) has the wrong plural categories")
                for category in ["few", "many", "other"] where categories.contains(category) {
                    XCTAssertTrue(variants[category]?.contains("%d") == true, "\(language) \(key).\(category) should show the number")
                }
            }
        }
    }
}

// MARK: - Nothing hard-coded in the code

final class NoHardCodedTextTests: CoreTestCase {
    /// Calls whose first argument is text the user reads.
    private let uiCalls = #"(?:\b(?:Text|Button|Label|TextField|Toggle|Picker|Stepper|Section|LabeledContent|DatePicker|ShareLink)|\.navigationTitle|\.accessibilityLabel|\.alert|\.confirmationDialog)\("((?:[^"\\\n]|\\.)*)""#

    func testNoLiteralTextPassedToUIControls() {
        var offenders: [String] = []
        for file in Files.swiftFiles(under: ["VehicleCare/UI", "VehicleCare/Services"]) + [Files.root.appendingPathComponent("VehicleCare/VehicleCareApp.swift")] {
            for m in matches(uiCalls, in: Files.text(file)) {
                let literal = m[1]
                // Symbols and numbers ("×", "0", "₹" is a currency sign) are not words, so they need no translation.
                if literal.range(of: #"\p{L}"#, options: .regularExpression) != nil, !literal.hasPrefix("\\(") {
                    offenders.append("\(file.lastPathComponent): \"\(literal)\"")
                }
            }
        }
        XCTAssertEqual(offenders, [], "user-visible text must come from L10n, not a literal")
    }

    func testCoreAndServicesDoNotBuildSentencesInline() {
        // User-facing sentences in logic code must also use L10n. These files are checked for message-like literals.
        var offenders: [String] = []
        let skip: Set<String> = ["L10n.swift", "Database.swift", "AppInfo.swift", "Feedback.swift", "DeviceInfo+Current.swift"]
        for file in Files.swiftFiles(under: ["VehicleCare/Core", "VehicleCare/Services"]) where !skip.contains(file.lastPathComponent) {
            for line in Files.text(file).components(separatedBy: "\n") {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("//") || code.contains("SELECT") || code.contains("INSERT") || code.contains("UPDATE")
                    || code.contains("DELETE") || code.contains("CREATE") || code.contains("PRAGMA") { continue }
                for m in matches(#""((?:[^"\\\n]|\\.)*)""#, in: code) {
                    // a sentence: starts with a capital and has a space-separated word after it
                    if m[1].range(of: #"^[A-Z][a-z]+ [a-z]+|^[A-Z][a-z]{2,}$"#, options: .regularExpression) != nil {
                        offenders.append("\(file.lastPathComponent): \(m[1])")
                    }
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }
}

// MARK: - Language behaviour

final class LanguageBehaviourTests: CoreTestCase {
    func testEnglishPlurals() {
        XCTAssertEqual(L10n.Plural.days(1), "1 day")
        XCTAssertEqual(L10n.Plural.days(14), "14 days")
        XCTAssertEqual(L10n.Plural.vehicles(0), "0 vehicles")
        XCTAssertEqual(L10n.Settings.tyreInterval(L10n.Plural.days(14)), "Tyre air: every 14 days")
    }

    func testArabicUsesAllSixPluralForms() {
        TestLocalization.use("ar")
        XCTAssertEqual(L10n.Plural.days(0), "0 يوم")
        XCTAssertEqual(L10n.Plural.days(1), "يوم واحد")
        XCTAssertEqual(L10n.Plural.days(2), "يومان")
        XCTAssertEqual(L10n.Plural.days(5), "5 أيام")
        XCTAssertEqual(L10n.Plural.days(11), "11 يومًا")
        XCTAssertEqual(L10n.Plural.days(100), "100 يوم")
        XCTAssertEqual(L10n.Plural.vehicles(2), "مركبتان")
        XCTAssertEqual(L10n.Plural.files(3), "3 ملفات")
    }

    func testPluralNumbersUseWesternDigitsInArabic() {
        TestLocalization.use("ar")
        let text = L10n.Plural.days(14) + L10n.Settings.retentionFooter(L10n.Plural.months(24))
        XCTAssertTrue(onlyWesternDigits(text), text)
        XCTAssertTrue(text.contains("14") && text.contains("24"))
    }

    func testDirection() {
        XCTAssertFalse(L10n.isRTL)
        XCTAssertEqual(L10n.isolate("Duke"), "Duke")
        XCTAssertEqual(L10n.ltr("₹1,200"), "₹1,200")
        TestLocalization.use("ar")
        XCTAssertTrue(L10n.isRTL)
        XCTAssertEqual(L10n.isolate("Duke"), "\u{2068}Duke\u{2069}")
        XCTAssertEqual(L10n.ltr("₹1,200"), "\u{2066}₹1,200\u{2069}")
    }

    func testAmountsKeepTheirSymbolAndDigitsInArabic() {
        XCTAssertEqual(Costs.format("₹", 1200), "₹1,200")
        TestLocalization.use("ar")
        let text = Costs.format("₹", 1200)
        XCTAssertTrue(text.hasPrefix("\u{2066}") && text.hasSuffix("\u{2069}"), "amount should be a bidi-isolated run")
        XCTAssertTrue(text.contains("₹"))
        XCTAssertTrue(onlyWesternDigits(text), text)
        XCTAssertTrue(text.contains("1") && text.contains("200"))
    }

    func testDatesFollowTheLanguageButKeepWesternDigits() {
        XCTAssertEqual(DateUtil.pretty("2026-10-24"), "Oct 24, 2026")
        XCTAssertEqual(DateUtil.monthTitle("2026-10"), "October 2026")
        TestLocalization.use("ar")
        for text in [DateUtil.pretty("2026-10-24"), DateUtil.monthTitle("2026-10")] {
            XCTAssertTrue(onlyWesternDigits(text), text)
            XCTAssertNotNil(text.range(of: #"\p{Arabic}"#, options: .regularExpression), "month name should be Arabic: \(text)")
        }
        XCTAssertEqual(DateUtil.string(DateUtil.parse("2026-10-24")!), "2026-10-24", "storage format must not change with language")
    }

    func testHourLabelUsesWesternDigits() {
        XCTAssertEqual(L10n.hourLabel(9).filter(\.isNumber), "9")
        TestLocalization.use("ar")
        XCTAssertTrue(onlyWesternDigits(L10n.hourLabel(21)))
        XCTAssertTrue(L10n.hourLabel(21).contains("9"))
    }

    func testFileSizesUseWesternDigits() {
        TestLocalization.use("ar")
        XCTAssertTrue(onlyWesternDigits(Feedback.formattedSize(20 * 1024 * 1024)), Feedback.formattedSize(20 * 1024 * 1024))
    }

    func testBackupErrorsAreTranslatedButKeepTechnicalNames() {
        TestLocalization.use("ar")
        guard case .failure(let error) = Backup.validate(Data(#"{"app":"other"}"#.utf8)) else { return XCTFail() }
        XCTAssertEqual(stripIsolates(error.message), Files.strings("ar")["backupError.notBackup"]!.replacingOccurrences(of: "%@", with: "Vehicle Care"))
        XCTAssertTrue(error.message.contains("\u{2068}Vehicle Care\u{2069}"), "the brand name inside Arabic text is isolated")

        let bad = #"{"app":"vehicle-care","schemaVersion":1,"exportedAt":"x","vehicles":[],"services":[{"id":1}],"serviceParts":[],"quickLogs":[],"reminders":[],"settings":{}}"#
        guard case .failure(let field) = Backup.validate(Data(bad.utf8)) else { return XCTFail() }
        XCTAssertTrue(field.message.contains("services"), field.message)
    }

    func testReminderTextIsTranslated() {
        XCTAssertEqual(ReminderService.title(for: .tyreAir), "Check tyre pressure")
        TestLocalization.use("ar")
        XCTAssertEqual(ReminderService.title(for: .tyreAir), "افحص ضغط الإطارات")
        XCTAssertEqual(stripIsolates(L10n.Reminder.tyreBody("Duke")), "حان وقت فحص هواء إطارات Duke.")
        XCTAssertTrue(L10n.Reminder.tyreBody("Duke").contains("\u{2068}Duke\u{2069}"), "a user-typed vehicle name is isolated so punctuation cannot jump sides")
    }

    func testDeveloperFacingFeedbackEmailStaysEnglish() {
        TestLocalization.use("ar")
        XCTAssertEqual(Feedback.subject(.bug), "[Vehicle Care] Bug report")
        let body = Feedback.body(message: "مرحبا", includeDeviceInfo: true,
                                 info: DeviceInfo(appVersion: "1.0.0-beta.5", build: "1", osVersion: "18.6", deviceModel: "iPhone17,1"))
        XCTAssertTrue(body.contains("App: Vehicle Care 1.0.0-beta.5 (1)") && body.contains("Device: iPhone17,1"))
        XCTAssertNotEqual(FeedbackCategory.bug.label, "Something is broken", "the category the user picks is translated")
    }

    func testShareMessageIsTranslated() {
        XCTAssertTrue(AppInfo.shareMessage.hasPrefix("I use Vehicle Care"))
        TestLocalization.use("ar")
        XCTAssertTrue(AppInfo.shareMessage.contains("Vehicle Care"))
        XCTAssertFalse(AppInfo.shareMessage.hasPrefix("I use"))
    }

    func testNoMissingKeyMarkersInCommonScreens() {
        for language in Files.languages {
            TestLocalization.use(language)
            let samples = [L10n.Common.save, L10n.Vehicles.title, L10n.Settings.title, L10n.Feedback.send,
                           L10n.Onboarding.startText, L10n.Notice.testOff, L10n.History.emptyMessage,
                           L10n.Transfer.summary("a", "b", "c"), L10n.Feedback.tooLarge("x", "y"), L10n.BackupError.invalidField("f", "t", 3)]
            for text in samples { XCTAssertFalse(text.contains("⚠︎"), "\(language): \(text)") }
        }
    }
}

// MARK: - Typed numbers

final class NumberInputTests: CoreTestCase {
    func testArabicIndicDigitsAreRead() {
        XCTAssertEqual(Costs.parseAmount("١٢٫٥"), 12.5)
        XCTAssertEqual(Costs.parseAmount("۱۲"), 12)      // Persian digits
        XCTAssertEqual(Costs.parseAmount("١٬٢٣٤"), 1234)  // Arabic thousands separator is dropped
        XCTAssertEqual(Costs.parseAmount("12,5"), 12.5)
        XCTAssertEqual(Costs.parseAmount("\u{200F}٧٥"), 75) // right-to-left mark from the keyboard
        XCTAssertEqual(Costs.parseAmount("abc", fallback: 3), 3)
    }

    func testWholeNumbers() {
        XCTAssertEqual(Costs.parseInt("١٤"), 14)
        XCTAssertEqual(Costs.parseInt(" 21 "), 21)
        XCTAssertNil(Costs.parseInt("1.5"))
        XCTAssertNil(Costs.parseInt(""))
    }

    func testEditableTextIsPlainAscii() {
        XCTAssertEqual(Costs.editableText(1234.5), "1234.5")
        XCTAssertEqual(Costs.editableText(300), "300")
        TestLocalization.use("ar")
        XCTAssertEqual(Costs.editableText(1234.5), "1234.5", "text fields are always editable as plain numbers")
        XCTAssertEqual(Costs.parseAmount(Costs.editableText(1234.5)), 1234.5)
    }
}

/// Foundation wraps `%@` substitutions in bidi isolates (U+2068/U+2069) in right-to-left languages.
private func stripIsolates(_ text: String) -> String {
    text.replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2068}", with: "").replacingOccurrences(of: "\u{2069}", with: "")
}

private func onlyWesternDigits(_ text: String) -> Bool {
    text.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.allSatisfy { $0.value < 128 }
}
