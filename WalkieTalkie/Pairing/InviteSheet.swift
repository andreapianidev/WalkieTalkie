//creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - InviteSheet.swift
//  WalkieTalkie

import SwiftUI
import CoreImage.CIFilterBuiltins

/// Il walkie serve solo se anche l'altro ha Talky, e l'invito Multipeer
/// raggiunge solo chi l'ha gia' installata. Qui chi e' accanto inquadra il
/// codice con la fotocamera, oppure riceve il link, e arriva allo Store.
struct InviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    static let storeURL = URL(string: "https://apps.apple.com/app/id6748584483")!

    var body: some View {
        NavigationView {
            VStack(spacing: 22) {
                Text("invite_title".localized)
                    .font(.title2.bold())
                    .foregroundColor(Color("PrimaryTextColor"))
                    .multilineTextAlignment(.center)

                if let qr = Self.qrImage {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        .accessibilityLabel("invite_qr_caption".localized)
                }

                Text("invite_qr_caption".localized)
                    .font(.body)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    showShare = true
                } label: {
                    Label("invite_share".localized, systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color("PrimaryTextColor")))
                }
                .padding(.horizontal, 24)

                Text("invite_then".localized)
                    .font(.footnote)
                    .foregroundColor(Color("PrimaryTextColor").opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .background(Color("BackgroundColor").ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("paywall.close".localized) { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: [
                    String(format: "invite_message".localized, Self.storeURL.absoluteString)
                ])
            }
        }
        .navigationViewStyle(.stack)
    }

    private static let qrImage: UIImage? = {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(storeURL.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }()
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
