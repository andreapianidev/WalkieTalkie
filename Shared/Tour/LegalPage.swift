//creato da Andrea Piani - 04/11/26 - https://www.andreapiani.com - LegalPage.swift
//  WalkieTalkie
//

import Foundation

/// Privacy, termini e assistenza stanno su andreapiani.com dal 4/11/2026: la regola e'
/// che le pagine legali di un'app vivano su un dominio nostro, non su vercel.app.
/// Le pagine esistono in inglese, italiano e spagnolo; le altre lingue vanno sull'inglese.
enum LegalPage: String {
    case privacy, terms

    var url: URL {
        let lingua = Bundle.main.preferredLocalizations.first?.prefix(2) ?? "en"
        let cartella = (lingua == "it" || lingua == "es") ? "\(lingua)/" : ""
        return URL(string: "https://www.andreapiani.com/talky/\(cartella)\(rawValue)/")!
    }
}
