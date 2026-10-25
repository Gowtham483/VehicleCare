import SwiftUI
import UIKit

struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 0.5))
    }
}

enum AppButtonKind { case primary, secondary, danger }

struct AppButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    let kind: AppButtonKind

    func makeBody(configuration: Configuration) -> some View {
        let background: Color = switch kind {
        case .primary: theme.accent
        case .secondary: theme.surfaceAlt
        case .danger: theme.danger
        }
        let foreground: Color = switch kind {
        case .primary: theme.onAccent
        case .secondary: theme.textPrimary
        case .danger: theme.surface
        }
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static func app(_ kind: AppButtonKind = .primary) -> AppButtonStyle { AppButtonStyle(kind: kind) }
}

struct EmptyState<Action: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let message: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundStyle(theme.textPrimary)
            Text(message).font(.subheadline).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
            action.padding(.top, 8)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyState where Action == EmptyView {
    init(title: String, message: String) { self.init(title: title, message: message) { EmptyView() } }
}

/// Wraps `UIActivityViewController`, the system share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Form chrome shared by all forms: themed background and a Cancel button.
private struct FormChrome: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(theme.background).keyboardFriendly()
    }
}

extension View {
    func themedForm() -> some View { modifier(FormChrome()) }
}

// MARK: - Timeline

enum TimelineEntry: Identifiable {
    case service(Service, vehicleName: String?)
    case quick(QuickLog, vehicleName: String?)

    var id: String {
        switch self {
        case .service(let s, _): return "s\(s.id)"
        case .quick(let q, _): return "q\(q.id)"
        }
    }
    var date: String {
        switch self {
        case .service(let s, _): return s.date
        case .quick(let q, _): return q.date
        }
    }
    var amount: Double {
        switch self {
        case .service(let s, _): return s.totalCost
        case .quick(let q, _): return q.cost ?? 0
        }
    }

    static func build(services: [Service], logs: [QuickLog], vehicleNames: [Int: String]? = nil) -> [TimelineEntry] {
        let entries = services.map { TimelineEntry.service($0, vehicleName: vehicleNames?[$0.vehicleId]) }
            + logs.map { TimelineEntry.quick($0, vehicleName: vehicleNames?[$0.vehicleId]) }
        return entries.sorted { $0.date > $1.date }
    }
}

struct TimelineRow: View {
    @Environment(\.theme) private var theme
    let entry: TimelineEntry
    let currency: String

    var body: some View {
        var title = ""
        var detail = ""
        var vehicle: String?
        switch entry {
        case .service(let s, let name):
            title = s.title; detail = s.notes; vehicle = name
        case .quick(let q, let name):
            switch q.kind {
            case .tyreAir: title = L10n.History.tyreChecked
            case .petrol: title = L10n.History.petrolFilled
            case .lube: title = L10n.History.chainLubed
            }
            detail = [q.litres.map { L10n.History.litresValue(Costs.format("", $0)) }, q.note.isEmpty ? nil : q.note].compactMap { $0 }.joined(separator: " · ")
            vehicle = name
        }
        return Card {
            HStack {
                Text(title).font(.headline).foregroundStyle(theme.textPrimary).lineLimit(1)
                Spacer()
                if entry.amount > 0 { Text(Costs.format(currency, entry.amount)).font(.headline).foregroundStyle(theme.textPrimary) }
            }
            Text(DateUtil.pretty(entry.date) + (vehicle.map { " · \(L10n.isolate($0))" } ?? "")).font(.subheadline).foregroundStyle(theme.textSecondary)
            if !detail.isEmpty { Text(detail).font(.subheadline).foregroundStyle(theme.textSecondary).lineLimit(2) }
        }
    }
}

// MARK: - Navigation routes

/// Sheets presented from several screens.
enum Route: Identifiable {
    case vehicleForm(id: Int?)
    case serviceForm(vehicleId: Int, id: Int?)
    case quickLog(vehicleId: Int, kind: QuickKind)
    case tour
    case feedback

    var id: String {
        switch self {
        case .vehicleForm(let id): return "vehicle-\(id.map(String.init) ?? "new")"
        case .serviceForm(let v, let id): return "service-\(v)-\(id.map(String.init) ?? "new")"
        case .quickLog(let v, let kind): return "quick-\(v)-\(kind.rawValue)"
        case .tour: return "tour"
        case .feedback: return "feedback"
        }
    }
}

private struct RouteSheets: ViewModifier {
    @Binding var route: Route?
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.sheet(item: $route) { route in
            switch route {
            case .vehicleForm(let id): VehicleFormView(vehicleId: id)
            case .serviceForm(let vehicleId, let id): ServiceFormView(vehicleId: vehicleId, serviceId: id)
            case .quickLog(let vehicleId, let kind): QuickLogView(vehicleId: vehicleId, kind: kind)
            case .feedback: FeedbackView()
            case .tour: OnboardingView(doneLabel: L10n.Onboarding.gotIt, onSkip: { self.route = nil }, onDone: { self.route = nil })
            }
        }
    }
}

extension View {
    func routeSheets(_ route: Binding<Route?>) -> some View { modifier(RouteSheets(route: route)) }
}
