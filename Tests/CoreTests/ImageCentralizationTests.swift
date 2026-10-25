import XCTest
@testable import Core

/// All images come from `UI/AppImages.swift`. These checks read the source tree.
final class ImageCentralizationTests: CoreTestCase {
    private let root = TestLocalization.resources.deletingLastPathComponent().deletingLastPathComponent()
    private var appImages: URL { root.appendingPathComponent("VehicleCare/UI/AppImages.swift") }

    private func swiftFiles() -> [URL] {
        let items = FileManager.default.enumerator(at: root.appendingPathComponent("VehicleCare"), includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return items.filter { $0.pathExtension == "swift" }
    }

    private func text(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }

    func testNoImageNamesOutsideTheCentralFile() {
        let pattern = try! NSRegularExpression(pattern: #"systemName:|systemImage:|\bImage\("|UIImage\(named|UIImage\(systemName|NSImage"#)
        var offenders: [String] = []
        for file in swiftFiles() where file != appImages {
            let source = text(file)
            let hits = pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)).count
            if hits > 0 { offenders.append("\(file.lastPathComponent) (\(hits))") }
        }
        XCTAssertEqual(offenders, [], "use Image.app(_:) / UIImage.app(_:) / Label(_, icon:) from AppImages.swift instead")
    }

    /// `case .name: return "symbol"` lines of `AppIcon.symbolName`.
    private func symbolTable() -> [String: String] {
        let source = text(appImages)
        let regex = try! NSRegularExpression(pattern: #"case \.(\w+): return "([^"]+)""#)
        var table: [String: String] = [:]
        for m in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            table[String(source[Range(m.range(at: 1), in: source)!])] = String(source[Range(m.range(at: 2), in: source)!])
        }
        return table
    }

    private func declaredCases() -> Set<String> {
        let source = text(appImages)
        let enumBody = source[source.range(of: "enum AppIcon")!.upperBound..<source.range(of: "var symbolName")!.lowerBound]
        let regex = try! NSRegularExpression(pattern: #"^\s*case ([\w, ]+)$"#, options: .anchorsMatchLines)
        var names = Set<String>()
        let body = String(enumBody)
        for m in regex.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
            for name in body[Range(m.range(at: 1), in: body)!].split(separator: ",") { names.insert(name.trimmingCharacters(in: .whitespaces)) }
        }
        return names
    }

    func testEveryIconHasASymbolName() {
        XCTAssertFalse(declaredCases().isEmpty)
        XCTAssertEqual(declaredCases(), Set(symbolTable().keys))
    }

    func testEverySymbolIsRealAndAvailableOnIOS17() throws {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist")
        guard let plist = NSDictionary(contentsOf: url), let symbols = plist["symbols"] as? [String: String] else {
            throw XCTSkip("the SF Symbols catalogue is not available on this machine")
        }
        for (icon, name) in symbolTable() {
            guard let introduced = symbols[name] else { XCTFail("\(icon): \"\(name)\" is not an SF Symbol"); continue }
            // iOS 17 (the app's minimum) corresponds to the 2023 symbol release
            XCTAssertLessThanOrEqual(Double(introduced) ?? 9999, 2023.9, "\(icon): \"\(name)\" needs a newer iOS than 17")
        }
    }

    func testEveryIconIsUsedByTheApp() {
        let others = swiftFiles().filter { $0 != appImages }.map(text).joined(separator: "\n")
        // bike and car are reached through AppIcon.vehicle(_:)
        for icon in symbolTable().keys where !["bike", "car"].contains(icon) {
            let used = others.range(of: #"(icon: |\.app\(|\? |: )\.\#(icon)\b"#, options: .regularExpression) != nil
            XCTAssertTrue(used, "AppIcon.\(icon) is not used anywhere")
        }
        XCTAssertTrue(others.contains(".vehicle("), "vehicle icons should come from AppIcon.vehicle(_:)")
    }
}
