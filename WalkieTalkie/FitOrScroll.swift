//creato da Andrea Piani - 26/09/26 - https://www.andreapiani.com - FitOrScroll.swift
//  WalkieTalkie
//

import SwiftUI

/// Contenitore per le schermate costruite come una colonna di blocchi a misura
/// fissa separati da `Spacer`.
///
/// Quando il contenuto ci sta, occupa tutta l'altezza disponibile e gli `Spacer`
/// interni si distribuiscono esattamente come prima. Quando non ci sta (iPhone 8
/// e SE a 667 pt, SE di prima generazione a 568 pt, testo ingrandito) la colonna
/// scorre invece di finire sotto la tab bar: prima i bottoni in fondo, per
/// esempio "Riavvia ricerca" in Connessioni e i "+" per invitare in Esplora,
/// erano semplicemente irraggiungibili (recensioni App Store, iPhone 8).
///
/// Il comportamento con `minHeight` è stato misurato con un render offscreen:
/// contenuto corto, lo `Spacer` spinge l'ultimo blocco in fondo; contenuto
/// lungo, la colonna supera l'altezza e scorre.
struct FitOrScroll<Content: View>: View {
    /// Blocca lo scorrimento, per esempio mentre si tiene premuto il PTT: un
    /// trascinamento del dito non deve diventare uno scroll.
    var scrollDisabled: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
            }
            .modifier(FitOrScrollBehavior(scrollDisabled: scrollDisabled))
        }
    }
}

private struct FitOrScrollBehavior: ViewModifier {
    let scrollDisabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            // Se il contenuto ci sta non c'e' niente da scorrere, quindi niente
            // rimbalzo: la schermata resta ferma come prima.
            content
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(scrollDisabled)
        } else if #available(iOS 16.0, *) {
            content.scrollDisabled(scrollDisabled)
        } else {
            content
        }
    }
}
