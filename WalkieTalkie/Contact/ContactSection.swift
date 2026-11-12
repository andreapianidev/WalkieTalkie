//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - ContactSection.swift
//  WalkieTalkie

import SwiftUI
import MessageUI
import UIKit

/// "Scrivimi" nelle impostazioni: problema, idea o due righe, verso la mail di
/// Andrea. Chi scrive invece di lasciare una stella e' un utente che si puo'
/// ancora aiutare, e in fondo al messaggio ci sono versione, sistema e modello,
/// cosi' non serve chiederli dopo. I dati si vedono nella mail prima di inviarla.
enum ContactTopic: String, Identifiable, CaseIterable {
    case bug, idea, chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug: return "contact_bug".localized
        case .idea: return "contact_idea".localized
        case .chat: return "contact_chat".localized
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .idea: return "lightbulb.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        }
    }

    var subject: String {
        let tag: String
        switch self {
        case .bug: tag = "contact_subject_bug".localized
        case .idea: tag = "contact_subject_idea".localized
        case .chat: tag = "contact_subject_chat".localized
        }
        return "Talky \(Contact.appVersion): \(tag)"
    }
}

enum Contact {
    static let address = "andreapiani.dev@gmail.com"
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6748584483?action=write-review")!

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    static var body: String {
        var model = utsname()
        uname(&model)
        let machine = withUnsafeBytes(of: &model.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        let tier = UserDefaults.standard.bool(forKey: "fastboot_isProUser") ? "Pro" : "Free"
        let lang = Locale.preferredLanguages.first ?? "?"
        return "\n\n\n---\nTalky \(appVersion) · iOS \(UIDevice.current.systemVersion) · \(machine) · \(lang) · \(tier)"
    }

    static func mailtoURL(for topic: ContactTopic) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = address
        c.queryItems = [URLQueryItem(name: "subject", value: topic.subject),
                        URLQueryItem(name: "body", value: body)]
        return c.url
    }
}

struct ContactSection: View {
    @State private var composing: ContactTopic?
    @State private var showNoMail = false
    @State private var showThanks = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(Color("PrimaryTextColor"))
                Text("contact_title".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
            }

            Text("contact_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(Color("PrimaryTextColor").opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(ContactTopic.allCases) { topic in
                    row(topic.title, icon: topic.icon) { open(topic) }
                    Divider()
                }
                row("contact_rate".localized, icon: "star.fill") {
                    UIApplication.shared.open(Contact.reviewURL)
                }
                Divider()
                row(Thanks.title, icon: "heart.fill") { showThanks = true }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color("SurfaceColor")))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color("SurfaceColor")))
        .sheet(isPresented: $showThanks) { ThanksSheet() }
        .sheet(item: $composing) { topic in
            MailComposer(subject: topic.subject, body: Contact.body)
                .ignoresSafeArea()
        }
        .alert("contact_no_mail_title".localized, isPresented: $showNoMail) {
            Button("contact_copy_address".localized) { UIPasteboard.general.string = Contact.address }
            Button("paywall.close".localized, role: .cancel) {}
        } message: {
            Text(String(format: "contact_no_mail_body".localized, Contact.address))
        }
    }

    private func open(_ topic: ContactTopic) {
        if MFMailComposeViewController.canSendMail() {
            composing = topic
        } else if let url = Contact.mailtoURL(for: topic) {
            // Gmail o un'altra app di posta impostata come predefinita. Si prova
            // ad aprire invece di chiedere `canOpenURL`, che senza dichiarare lo
            // schema in Info.plist risponde no anche quando un'app c'e'.
            UIApplication.shared.open(url) { opened in
                if !opened { showNoMail = true }
            }
        } else {
            showNoMail = true
        }
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Color("PrimaryTextColor"))
                    .frame(width: 24)
                Text(title)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor"))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.4))
            }
            .padding()
        }
    }
}

/// Chi ha reso Talky migliore (Thanks.swift): nome, perche', e il link a
/// dove l'ha fatto.
private struct ThanksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(Thanks.all) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            if let link = entry.link {
                                Link(entry.who, destination: link).font(.headline)
                            } else {
                                Text(entry.who).font(.headline)
                            }
                            Text(entry.why)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(Thanks.intro)
                }
            }
            .navigationTitle(Thanks.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("paywall.close".localized) { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct MailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.setToRecipients([Contact.address])
        mail.setSubject(subject)
        mail.setMessageBody(body, isHTML: false)
        mail.mailComposeDelegate = context.coordinator
        return mail
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
