//creato da Andrea Piani - 03/11/26 - https://www.andreapiani.com - RadioSplit.swift
//  Talky
//
//  La radio a due pannelli per gli schermi larghi: display interno dell'iPhone
//  Duo e iPad. A sinistra la testa di comando (stato, bande, display, tasti),
//  a destra lo schermo (spettro e cascata, barre, tasto per parlare).
//
//  Sul Duo lo spazio fra i due pannelli e' la cerniera: la si legge anche a
//  telefono aperto piatto (`includeInactive`), cosi' piegandolo non si sposta
//  niente. Appoggiato sul tavolo (cerniera orizzontale) lo schermo va sopra,
//  da guardare, e i comandi sotto, vicino alle dita.

import SwiftUI

struct RadioSplit<Controls: View, Scope: View>: View {
    @ViewBuilder var controls: Controls
    @ViewBuilder var scope: Scope

    /// Spazio fra i pannelli quando non c'e' una cerniera (iPad).
    private let gutter: CGFloat = 28
    /// Larghezza della colonna singola, come sul telefono.
    private let columnWidth: CGFloat = 720

    var body: some View {
        GeometryReader { proxy in
            switch Hinge.of(proxy) {
            case .horizontal(let line):
                // Appoggiato: lo schermo sopra la piega, i comandi sotto.
                VStack(spacing: 0) {
                    scopePanel
                        .frame(height: max(0, line.minY - gutter / 2))
                    Color.clear.frame(height: line.height + gutter)
                    controlPanel
                }
            case .vertical(let line):
                HStack(spacing: 0) {
                    controlPanel
                        .frame(width: max(0, line.minX - gutter / 2))
                    Color.clear.frame(width: line.width + gutter)
                    scopePanel
                }
            case .none where proxy.size.width > proxy.size.height:
                // iPad in orizzontale: due pannelli affiancati.
                HStack(spacing: gutter) {
                    controlPanel
                    scopePanel
                }
                .padding(.horizontal, gutter / 2)
            case .none:
                // iPad in verticale: una colonna, e lo schermo si prende
                // l'altezza che sul telefono non c'e'.
                VStack(spacing: 0) {
                    controls
                    scope
                        .environment(\.talkyScopeFills, true)
                        .padding(.vertical, 16)
                }
                .frame(maxWidth: columnWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// I comandi al centro del loro pannello, non incollati in alto.
    private var controlPanel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            controls
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Lo schermo riempie il pannello; il tasto per parlare, che non si
    /// allunga, resta centrato.
    private var scopePanel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            scope
                .environment(\.talkyScopeFills, true)
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScopeFillsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Lo schermo (spettro, cascata, barre) prende tutta l'altezza libera
    /// invece della sua altezza da telefono.
    var talkyScopeFills: Bool {
        get { self[ScopeFillsKey.self] }
        set { self[ScopeFillsKey.self] = newValue }
    }
}

/// Altezza della finestra sotto la quale il layout si stringe (iPhone SE/8 e
/// simili). Si misura sulla finestra dell'app e non sullo schermo: sul Duo i
/// display sono due, e su iPad la finestra puo' essere piu' piccola dello schermo.
private struct CompactHeightKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var talkyCompactHeight: Bool {
        get { self[CompactHeightKey.self] }
        set { self[CompactHeightKey.self] = newValue }
    }
}

/// Dove passa la cerniera del Duo nello spazio della vista.
enum Hinge {
    case none
    /// A libro: la riga verticale della piega.
    case vertical(CGRect)
    /// Appoggiato sul tavolo: la riga orizzontale.
    case horizontal(CGRect)

    static func of(_ proxy: GeometryProxy) -> Hinge {
        #if canImport(SwiftUICore, _version: 8.0.85.27)
        if #available(iOS 27.1, *) {
            // Anche quella non attiva: a telefono piatto ha larghezza zero ma
            // sta gia' dove sara' la piega, e il layout non salta piegandolo.
            let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
            if let line = regions.first?.frame, !line.isNull, line.width > 0 || line.height > 0 {
                return line.height >= line.width ? .vertical(line) : .horizontal(line)
            }
        }
        #endif
        return .none
    }
}

/// Il contenitore di navigazione dei fogli. `NavigationStack` si adatta alle
/// pose del Duo e ai fogli su iPad; su iOS 15 resta `NavigationView` a pila.
struct TalkyNavigation<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
                .navigationViewStyle(.stack)
        }
    }
}
