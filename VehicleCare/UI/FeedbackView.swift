import MessageUI
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct FeedbackAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int
}

/// Copies a photo or video chosen in the photo picker into a temporary file.
private struct PickedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            PickedFile(url: try AttachmentStorage.copy(received.file, as: received.file.lastPathComponent))
        }
    }
}

private enum AttachmentStorage {
    static var directory: URL { FileManager.default.temporaryDirectory.appendingPathComponent("feedback-attachments", isDirectory: true) }

    /// Copies into a fresh sub-folder so two files with the same name never collide.
    static func copy(_ source: URL, as name: String) throws -> URL {
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(Feedback.sanitizedFileName(name))
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func cleanUp() { try? FileManager.default.removeItem(at: directory) }
}

/// Wraps the system mail composer, which supports attachments.
private struct MailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let attachments: [FeedbackAttachment]
    let onFinish: (MFMailComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([AppInfo.feedbackEmail])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        for a in attachments {
            if let data = try? Data(contentsOf: a.url, options: .mappedIfSafe) {
                vc.addAttachmentData(data, mimeType: Feedback.mimeType(forFileName: a.name), fileName: a.name)
            }
        }
        return vc
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(result)
        }
    }
}

struct FeedbackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var category: FeedbackCategory = .bug
    @State private var message = ""
    @State private var includeDeviceInfo = true
    @State private var attachments: [FeedbackAttachment] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var showMail = false
    @State private var showMailUnavailable = false
    @State private var showShare = false
    @State private var problem: String?

    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var body_: String { Feedback.body(message: message, includeDeviceInfo: includeDeviceInfo, info: DeviceInfo.current) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.Feedback.type, selection: $category) {
                        ForEach(FeedbackCategory.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    TextField(L10n.Feedback.messagePlaceholder, text: $message, axis: .vertical)
                        .lineLimit(5...12)
                } header: {
                    Text(L10n.Feedback.messageHeader)
                } footer: {
                    Text(L10n.Feedback.messageFooter(AppInfo.feedbackEmail))
                }

                Section {
                    ForEach(attachments) { a in
                        HStack {
                            Image.app(.attachment).foregroundStyle(theme.textSecondary)
                            VStack(alignment: .leading) {
                                Text(a.name).lineLimit(1)
                                Text(Feedback.formattedSize(a.size)).font(.footnote).foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                            Button { remove(a) } label: { Image.app(.removeCircle).foregroundStyle(theme.textSecondary) }
                                .buttonStyle(.plain)
                                .accessibilityLabel(L10n.Feedback.remove(a.name))
                        }
                    }
                    PhotosPicker(selection: $photoItems, maxSelectionCount: Feedback.maxAttachments, matching: .any(of: [.images, .videos])) {
                        Label(L10n.Feedback.addMedia, icon: .addPhoto)
                    }
                    Button { showFileImporter = true } label: { Label(L10n.Feedback.addFile, icon: .addFile) }
                } header: {
                    Text(L10n.Feedback.attachmentsHeader)
                } footer: {
                    Text(L10n.Feedback.attachmentsFooter(L10n.Plural.files(Feedback.maxAttachments), Feedback.formattedSize(Feedback.maxTotalBytes)))
                }

                Section {
                    Toggle(L10n.Feedback.deviceInfo, isOn: $includeDeviceInfo)
                } footer: {
                    Text(L10n.Feedback.deviceInfoFooter)
                }

            }
            .themedForm()
            .navigationTitle(L10n.Feedback.title)
            .navigationBarTitleDisplayMode(.inline)
            .themedBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.cancel) { close() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.Feedback.send, action: send).disabled(trimmedMessage.isEmpty) }
            }
            .onChange(of: photoItems) { _, items in loadPhotos(items) }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { addFiles(urls) }
            }
            .sheet(isPresented: $showMail) {
                MailComposer(subject: Feedback.subject(category), body: body_, attachments: attachments) { result in
                    showMail = false
                    if result == .sent {
                        model.notice = L10n.Feedback.thanks
                        close()
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: ["To: \(AppInfo.feedbackEmail)\nSubject: \(Feedback.subject(category))\n\n\(body_)"] + attachments.map(\.url))
            }
            .confirmationDialog(L10n.Feedback.noMailTitle, isPresented: $showMailUnavailable, titleVisibility: .visible) {
                Button(L10n.Feedback.shareOther) { showShare = true }
                Button(L10n.Feedback.copyEmail) { UIPasteboard.general.string = AppInfo.feedbackEmail }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Feedback.noMailMessage)
            }
            .alert(L10n.Feedback.attachmentTitle, isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(problem ?? "")
            }
        }
    }

    private func send() {
        if MFMailComposeViewController.canSendMail() { showMail = true } else { showMailUnavailable = true }
    }

    private func close() {
        AttachmentStorage.cleanUp()
        dismiss()
    }

    private func remove(_ attachment: FeedbackAttachment) {
        try? FileManager.default.removeItem(at: attachment.url)
        attachments.removeAll { $0 == attachment }
    }

    private func add(_ url: URL, named name: String) {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        switch Feedback.check(existingSizes: attachments.map(\.size), newSize: size) {
        case .ok:
            attachments.append(FeedbackAttachment(url: url, name: name, size: size))
        case .tooMany:
            problem = L10n.Feedback.tooMany(L10n.Plural.files(Feedback.maxAttachments))
            try? FileManager.default.removeItem(at: url)
        case .tooLarge:
            problem = L10n.Feedback.tooLarge(name, Feedback.formattedSize(Feedback.maxTotalBytes))
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                guard let picked = try? await item.loadTransferable(type: PickedFile.self) else {
                    problem = L10n.Feedback.loadFailed
                    continue
                }
                add(picked.url, named: picked.url.lastPathComponent)
            }
            photoItems = []
        }
    }

    private func addFiles(_ urls: [URL]) {
        for source in urls {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            do {
                add(try AttachmentStorage.copy(source, as: source.lastPathComponent), named: Feedback.sanitizedFileName(source.lastPathComponent))
            } catch {
                problem = L10n.Feedback.readFailed(source.lastPathComponent)
            }
        }
    }
}
