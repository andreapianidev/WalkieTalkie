//creato da Andrea Piani - 02/08/26 - https://www.andreapiani.com - OnboardingView.swift
//  macTalky
//
//  Onboarding al primo avvio, replicato dallo spirito di quello iOS ma in
//  forma di sheet desktop: 4 pagine (Walkie, Rete+Microfono, Live, Radio+Pro).
//  Localizzato in-code in 14 lingue (le 13 dell'App Store + malese, come iOS).

import SwiftUI

// MARK: - Localizzazione onboarding

/// Stringhe dell'onboarding per lingua. Chiave = code ISO 639-1 (+ script per il cinese).
private enum OBString {
    case welcomeTitle, welcomeBody
    case networkTitle, networkBody, networkTip, micGranted
    case liveTitle, liveBody
    case radioTitle, radioBody
    case proNote
    case next, back, start

    var text: String {
        let lang = Self.languageKey
        return Self.table[lang]?[self] ?? Self.table["en"]![self]!
    }

    private static var languageKey: String {
        let locale = Locale.current
        let code = locale.language.languageCode?.identifier ?? "en"
        if code == "zh" {
            let script = locale.language.script?.identifier ?? "Hans"
            return script == "Hant" ? "zh-Hant" : "zh-Hans"
        }
        return code
    }

    private static let table: [String: [OBString: String]] = [
        "en": [
            .welcomeTitle: "Your Mac is now a walkie-talkie",
            .welcomeBody: "Hold the big TALK key (or the Space bar) to speak. Release to listen. One voice at a time, like a real radio.",
            .networkTitle: "No internet. No accounts.",
            .networkBody: "Talky finds Talky devices (iPhone, Android, Mac) on your Wi-Fi network automatically. Grant microphone access to transmit your voice.",
            .networkTip: "All devices must be on the same Wi-Fi network. There's nothing to pair: everyone starts on the public channel and finds each other on their own.",
            .micGranted: "Microphone authorized",
            .liveTitle: "Real radio, live",
            .liveBody: "Shortwave, CB 27 MHz and POC channels from real receivers and servers around the world, with the receiver's spectrum and waterfall. Listen only, 5 free minutes a day, unlimited with Talky Pro.",
            .radioTitle: "343 world radio stations",
            .radioBody: "Switch to the Radio module for verified stations from 50+ countries, with favorites, filters and media keys.",
            .proNote: "Talky Pro and the Themes Pack are shared with the iOS app: one purchase unlocks iPhone, iPad and Mac.",
            .next: "Continue", .back: "Back", .start: "Start",
        ],
        "it": [
            .welcomeTitle: "Il tuo Mac ora è un walkie-talkie",
            .welcomeBody: "Tieni premuto il grande tasto TALK (o la barra spaziatrice) per parlare. Rilascia per ascoltare. Una voce alla volta, come una radio vera.",
            .networkTitle: "Niente internet. Niente account.",
            .networkBody: "Talky trova i dispositivi Talky (iPhone, Android, Mac) sulla tua rete Wi-Fi automaticamente. Concedi il microfono per trasmettere la voce.",
            .networkTip: "Tutti i dispositivi devono stare sulla stessa rete Wi-Fi. Non c'è niente da abbinare a mano: si parte tutti dal canale pubblico e ci si trova da soli.",
            .micGranted: "Microfono autorizzato",
            .liveTitle: "La radio vera, dal vivo",
            .liveBody: "Onde corte, CB 27 MHz e canali POC da ricevitori e server veri in tutto il mondo, con lo spettro e la cascata del ricevitore. Solo ascolto, 5 minuti gratis al giorno, senza limiti con Talky Pro.",
            .radioTitle: "343 stazioni radio dal mondo",
            .radioBody: "Passa al modulo Radio per stazioni verificate da oltre 50 Paesi, con preferiti, filtri e tasti multimediali.",
            .proNote: "Talky Pro e il Pacchetto Temi sono condivisi con l'app iOS: un solo acquisto sblocca iPhone, iPad e Mac.",
            .next: "Continua", .back: "Indietro", .start: "Inizia",
        ],
        "de": [
            .welcomeTitle: "Dein Mac ist jetzt ein Funkgerät",
            .welcomeBody: "Halte die große TALK-Taste (oder die Leertaste) gedrückt, um zu sprechen. Loslassen zum Zuhören. Eine Stimme nach der anderen, wie bei einem echten Funkgerät.",
            .networkTitle: "Kein Internet. Keine Konten.",
            .networkBody: "Talky findet Talky-Geräte (iPhone, Android, Mac) in deinem WLAN automatisch. Erlaube den Mikrofonzugriff, um deine Stimme zu übertragen.",
            .networkTip: "Alle Geräte müssen im selben WLAN sein. Es gibt nichts zu koppeln: Alle starten auf dem öffentlichen Kanal und finden sich von selbst.",
            .micGranted: "Mikrofon autorisiert",
            .liveTitle: "Echter Funk, live",
            .liveBody: "Kurzwelle, CB 27 MHz und POC-Kanäle von echten Empfängern und Servern auf der ganzen Welt, mit Spektrum und Wasserfall des Empfängers. Nur Empfang, 5 Gratisminuten am Tag, ohne Limit mit Talky Pro.",
            .radioTitle: "343 Radiosender aus aller Welt",
            .radioBody: "Wechsle zum Radio-Modul: verifizierte Sender aus über 50 Ländern, mit Favoriten, Filtern und Medientasten.",
            .proNote: "Talky Pro und das Themes-Paket werden mit der iOS-App geteilt: Ein Kauf schaltet iPhone, iPad und Mac frei.",
            .next: "Weiter", .back: "Zurück", .start: "Los geht's",
        ],
        "es": [
            .welcomeTitle: "Tu Mac ahora es un walkie-talkie",
            .welcomeBody: "Mantén pulsada la gran tecla TALK (o la barra espaciadora) para hablar. Suelta para escuchar. Una voz a la vez, como una radio de verdad.",
            .networkTitle: "Sin internet. Sin cuentas.",
            .networkBody: "Talky encuentra automáticamente los dispositivos Talky (iPhone, Android, Mac) en tu red Wi-Fi. Concede acceso al micrófono para transmitir tu voz.",
            .networkTip: "Todos los dispositivos deben estar en la misma red Wi-Fi. No hay nada que emparejar: todos empiezan en el canal público y se encuentran solos.",
            .micGranted: "Micrófono autorizado",
            .liveTitle: "Radio real, en directo",
            .liveBody: "Onda corta, CB 27 MHz y canales POC de receptores y servidores reales de todo el mundo, con el espectro y la cascada del receptor. Solo escucha, 5 minutos gratis al día, sin límites con Talky Pro.",
            .radioTitle: "343 emisoras de radio del mundo",
            .radioBody: "Cambia al módulo Radio: emisoras verificadas de más de 50 países, con favoritos, filtros y teclas multimedia.",
            .proNote: "Talky Pro y el Pack de Temas se comparten con la app de iOS: una sola compra desbloquea iPhone, iPad y Mac.",
            .next: "Continuar", .back: "Atrás", .start: "Empezar",
        ],
        "fr": [
            .welcomeTitle: "Votre Mac est maintenant un talkie-walkie",
            .welcomeBody: "Maintenez la grande touche TALK (ou la barre d'espace) pour parler. Relâchez pour écouter. Une voix à la fois, comme une vraie radio.",
            .networkTitle: "Pas d'internet. Pas de compte.",
            .networkBody: "Talky trouve automatiquement les appareils Talky (iPhone, Android, Mac) sur votre réseau Wi-Fi. Autorisez le micro pour transmettre votre voix.",
            .networkTip: "Tous les appareils doivent être sur le même réseau Wi-Fi. Rien à appairer : tout le monde démarre sur le canal public et se trouve tout seul.",
            .micGranted: "Micro autorisé",
            .liveTitle: "La vraie radio, en direct",
            .liveBody: "Ondes courtes, CB 27 MHz et canaux POC depuis de vrais récepteurs et serveurs du monde entier, avec le spectre et la cascade du récepteur. Écoute seule, 5 minutes gratuites par jour, sans limite avec Talky Pro.",
            .radioTitle: "343 stations de radio du monde",
            .radioBody: "Passez au module Radio : stations vérifiées de plus de 50 pays, avec favoris, filtres et touches multimédia.",
            .proNote: "Talky Pro et le Pack de thèmes sont partagés avec l'app iOS : un seul achat débloque iPhone, iPad et Mac.",
            .next: "Continuer", .back: "Retour", .start: "Commencer",
        ],
        "ja": [
            .welcomeTitle: "Macがトランシーバーに",
            .welcomeBody: "大きなTALKキー、またはスペースキーを押し続けて話します。離すと受信。本物の無線機のように、一度に一人ずつ。",
            .networkTitle: "インターネット不要。アカウント不要。",
            .networkBody: "TalkyはWi-Fiネットワーク上のTalkyデバイス(iPhone、Android、Mac)を自動で見つけます。声を送信するにはマイクを許可してください。",
            .networkTip: "すべての端末を同じWi-Fiネットワークに接続してください。手動でペアリングするものはありません。全員が公開チャンネルから始まり、自動で見つかります。",
            .micGranted: "マイク許可済み",
            .liveTitle: "本物の無線をライブで",
            .liveBody: "世界中の本物の受信機とサーバーから短波、CB 27 MHz、POCチャンネルを受信。受信機のスペクトラムとウォーターフォールも表示します。受信のみ、1日5分無料、Talky Proなら無制限。",
            .radioTitle: "世界343のラジオ局",
            .radioBody: "ラジオモジュールに切り替えると、50か国以上の検証済みステーションをお気に入り・フィルタ・メディアキーで楽しめます。",
            .proNote: "Talky ProとテーマパックはiOSアプリと共通。1回の購入でiPhone・iPad・Macすべてで使えます。",
            .next: "続ける", .back: "戻る", .start: "開始",
        ],
        "ko": [
            .welcomeTitle: "Mac이 워키토키가 됩니다",
            .welcomeBody: "큰 TALK 버튼이나 스페이스바를 누른 채 말하세요. 놓으면 수신합니다. 진짜 무전기처럼 한 번에 한 명씩.",
            .networkTitle: "인터넷 불필요. 계정 불필요.",
            .networkBody: "Talky는 Wi-Fi 네트워크의 Talky 기기(iPhone, Android, Mac)를 자동으로 찾습니다. 음성을 전송하려면 마이크를 허용하세요.",
            .networkTip: "모든 기기가 같은 Wi-Fi 네트워크에 있어야 합니다. 따로 페어링할 것은 없습니다. 모두 공개 채널에서 시작해 알아서 서로를 찾습니다.",
            .micGranted: "마이크 허용됨",
            .liveTitle: "진짜 무선, 실시간으로",
            .liveBody: "전 세계 실제 수신기와 서버에서 단파, CB 27 MHz, POC 채널을 수신하고 수신기의 스펙트럼과 워터폴을 보여 줍니다. 청취 전용, 하루 5분 무료, Talky Pro로 무제한.",
            .radioTitle: "세계 343개 라디오 방송국",
            .radioBody: "라디오 모듈로 전환하면 50개국 이상의 검증된 방송국을 즐겨찾기, 필터, 미디어 키와 함께 들을 수 있습니다.",
            .proNote: "Talky Pro와 테마 팩은 iOS 앱과 공유됩니다. 한 번 구매로 iPhone, iPad, Mac 모두 잠금 해제.",
            .next: "계속", .back: "뒤로", .start: "시작",
        ],
        "pt": [
            .welcomeTitle: "Seu Mac agora é um walkie-talkie",
            .welcomeBody: "Segure a grande tecla TALK (ou a barra de espaço) para falar. Solte para ouvir. Uma voz por vez, como um rádio de verdade.",
            .networkTitle: "Sem internet. Sem contas.",
            .networkBody: "O Talky encontra automaticamente os dispositivos Talky (iPhone, Android, Mac) na sua rede Wi-Fi. Conceda o microfone para transmitir sua voz.",
            .networkTip: "Todos os aparelhos precisam estar na mesma rede Wi-Fi. Não há nada para parear: todo mundo começa no canal público e se encontra sozinho.",
            .micGranted: "Microfone autorizado",
            .liveTitle: "Rádio de verdade, ao vivo",
            .liveBody: "Ondas curtas, PX 27 MHz e canais POC de receptores e servidores reais do mundo todo, com o espectro e a cascata do receptor. Só escuta, 5 minutos grátis por dia, sem limites com o Talky Pro.",
            .radioTitle: "343 estações de rádio do mundo",
            .radioBody: "Mude para o módulo Rádio: estações verificadas de mais de 50 países, com favoritos, filtros e teclas de mídia.",
            .proNote: "O Talky Pro e o Pacote de Temas são compartilhados com o app iOS: uma compra desbloqueia iPhone, iPad e Mac.",
            .next: "Continuar", .back: "Voltar", .start: "Começar",
        ],
        "th": [
            .welcomeTitle: "Mac ของคุณคือวิทยุสื่อสารแล้ว",
            .welcomeBody: "กดปุ่ม TALK ขนาดใหญ่ (หรือแป้น Space) ค้างไว้เพื่อพูด ปล่อยเพื่อฟัง ทีละเสียงเหมือนวิทยุจริง",
            .networkTitle: "ไม่ต้องใช้อินเทอร์เน็ต ไม่ต้องมีบัญชี",
            .networkBody: "Talky ค้นหาอุปกรณ์ Talky (iPhone, Android, Mac) บนเครือข่าย Wi-Fi โดยอัตโนมัติ อนุญาตไมโครโฟนเพื่อส่งเสียงของคุณ",
            .networkTip: "อุปกรณ์ทุกเครื่องต้องอยู่บนเครือข่าย Wi-Fi เดียวกัน ไม่มีอะไรต้องจับคู่ ทุกคนเริ่มที่ช่องสาธารณะและหากันเจอเอง",
            .micGranted: "อนุญาตไมโครโฟนแล้ว",
            .liveTitle: "วิทยุจริง แบบสด",
            .liveBody: "คลื่นสั้น CB 27 MHz และช่อง POC จากเครื่องรับและเซิร์ฟเวอร์จริงทั่วโลก พร้อมสเปกตรัมและวอเตอร์ฟอลของเครื่องรับ ฟังอย่างเดียว ฟรีวันละ 5 นาที ไม่จำกัดกับ Talky Pro",
            .radioTitle: "วิทยุ 343 สถานีทั่วโลก",
            .radioBody: "สลับไปที่โมดูลวิทยุ: สถานีที่ตรวจสอบแล้วจากกว่า 50 ประเทศ พร้อมรายการโปรด ตัวกรอง และปุ่มมีเดีย",
            .proNote: "Talky Pro และแพ็กธีมใช้ร่วมกับแอป iOS: ซื้อครั้งเดียวปลดล็อกทั้ง iPhone, iPad และ Mac",
            .next: "ต่อไป", .back: "ย้อนกลับ", .start: "เริ่ม",
        ],
        "tr": [
            .welcomeTitle: "Mac'iniz artık bir telsiz",
            .welcomeBody: "Konuşmak için büyük TALK tuşunu (veya boşluk tuşunu) basılı tutun. Dinlemek için bırakın. Gerçek bir telsiz gibi, aynı anda tek ses.",
            .networkTitle: "İnternet yok. Hesap yok.",
            .networkBody: "Talky, Wi-Fi ağınızdaki Talky cihazlarını (iPhone, Android, Mac) otomatik bulur. Sesinizi iletmek için mikrofona izin verin.",
            .networkTip: "Tüm cihazlar aynı Wi-Fi ağında olmalı. Eşleştirilecek bir şey yok: herkes ortak kanaldan başlar ve birbirini kendiliğinden bulur.",
            .micGranted: "Mikrofon izni verildi",
            .liveTitle: "Gerçek radyo, canlı",
            .liveBody: "Dünyanın dört bir yanındaki gerçek alıcı ve sunuculardan kısa dalga, CB 27 MHz ve POC kanalları, alıcının spektrumu ve şelalesiyle. Yalnızca dinleme, günde 5 dakika ücretsiz, Talky Pro ile sınırsız.",
            .radioTitle: "Dünyadan 343 radyo istasyonu",
            .radioBody: "Radyo modülüne geçin: 50'den fazla ülkeden doğrulanmış istasyonlar, favoriler, filtreler ve medya tuşlarıyla.",
            .proNote: "Talky Pro ve Tema Paketi iOS uygulamasıyla ortaktır: tek satın alma iPhone, iPad ve Mac'i açar.",
            .next: "Devam", .back: "Geri", .start: "Başla",
        ],
        "vi": [
            .welcomeTitle: "Mac của bạn giờ là bộ đàm",
            .welcomeBody: "Giữ phím TALK lớn (hoặc phím Space) để nói. Thả ra để nghe. Mỗi lần một giọng nói, như bộ đàm thật.",
            .networkTitle: "Không cần internet. Không cần tài khoản.",
            .networkBody: "Talky tự động tìm các thiết bị Talky (iPhone, Android, Mac) trên mạng Wi-Fi của bạn. Cho phép micrô để truyền giọng nói.",
            .networkTip: "Tất cả thiết bị phải ở cùng một mạng Wi-Fi. Không có gì phải ghép nối: mọi người đều bắt đầu ở kênh công khai và tự tìm thấy nhau.",
            .micGranted: "Đã cho phép micrô",
            .liveTitle: "Radio thật, trực tiếp",
            .liveBody: "Sóng ngắn, CB 27 MHz và các kênh POC từ máy thu và máy chủ thật trên khắp thế giới, kèm phổ và thác nước của máy thu. Chỉ nghe, 5 phút miễn phí mỗi ngày, không giới hạn với Talky Pro.",
            .radioTitle: "343 đài radio khắp thế giới",
            .radioBody: "Chuyển sang mô-đun Radio: các đài đã xác minh từ hơn 50 quốc gia, với yêu thích, bộ lọc và phím media.",
            .proNote: "Talky Pro và Gói chủ đề dùng chung với ứng dụng iOS: mua một lần, mở khóa iPhone, iPad và Mac.",
            .next: "Tiếp tục", .back: "Quay lại", .start: "Bắt đầu",
        ],
        "ms": [
            .welcomeTitle: "Mac anda kini walkie-talkie",
            .welcomeBody: "Tahan kekunci TALK besar (atau bar Space) untuk bercakap. Lepaskan untuk mendengar. Satu suara pada satu masa, seperti radio sebenar.",
            .networkTitle: "Tiada internet. Tiada akaun.",
            .networkBody: "Talky mencari peranti Talky (iPhone, Android, Mac) pada rangkaian Wi-Fi anda secara automatik. Benarkan mikrofon untuk menghantar suara anda.",
            .networkTip: "Semua peranti mesti berada pada rangkaian Wi-Fi yang sama. Tiada apa-apa untuk digandingkan: semua bermula pada saluran awam dan menemui satu sama lain sendiri.",
            .micGranted: "Mikrofon dibenarkan",
            .liveTitle: "Radio sebenar, secara langsung",
            .liveBody: "Gelombang pendek, CB 27 MHz dan saluran POC daripada penerima dan pelayan sebenar di seluruh dunia, dengan spektrum dan air terjun penerima. Dengar sahaja, 5 minit percuma sehari, tanpa had dengan Talky Pro.",
            .radioTitle: "343 stesen radio dunia",
            .radioBody: "Tukar ke modul Radio: stesen yang disahkan dari lebih 50 negara, dengan kegemaran, penapis dan kekunci media.",
            .proNote: "Talky Pro dan Pek Tema dikongsi dengan apl iOS: satu pembelian membuka iPhone, iPad dan Mac.",
            .next: "Teruskan", .back: "Kembali", .start: "Mula",
        ],
        "zh-Hans": [
            .welcomeTitle: "你的 Mac 现在是一台对讲机",
            .welcomeBody: "按住大大的 TALK 键（或空格键）即可说话。松开即收听。一次一个声音,就像真正的对讲机。",
            .networkTitle: "无需互联网。无需账号。",
            .networkBody: "Talky 会自动发现 Wi-Fi 网络中的 Talky 设备(iPhone、Android、Mac)。授权麦克风即可传输语音。",
            .networkTip: "所有设备必须连到同一个 Wi-Fi 网络。没有什么需要手动配对：大家都从公开频道开始，会自己找到彼此。",
            .micGranted: "麦克风已授权",
            .liveTitle: "真正的电台，实时收听",
            .liveBody: "来自世界各地真实接收机和服务器的短波、CB 27 MHz 和 POC 频道，并显示接收机的频谱和瀑布图。仅收听，每天免费 5 分钟，Talky Pro 无限制。",
            .radioTitle: "343 个全球电台",
            .radioBody: "切换到电台模块:来自 50 多个国家的经过验证的电台,支持收藏、筛选和媒体键。",
            .proNote: "Talky Pro 和主题包与 iOS 应用通用:一次购买,解锁 iPhone、iPad 和 Mac。",
            .next: "继续", .back: "返回", .start: "开始",
        ],
        "zh-Hant": [
            .welcomeTitle: "你的 Mac 現在是一台對講機",
            .welcomeBody: "按住大大的 TALK 鍵（或空白鍵）即可說話。放開即收聽。一次一個聲音,就像真正的對講機。",
            .networkTitle: "無需網際網路。無需帳號。",
            .networkBody: "Talky 會自動發現 Wi-Fi 網路中的 Talky 裝置(iPhone、Android、Mac)。授權麥克風即可傳送語音。",
            .networkTip: "所有裝置必須連到同一個 Wi-Fi 網路。沒有什麼需要手動配對：大家都從公開頻道開始，會自己找到彼此。",
            .micGranted: "麥克風已授權",
            .liveTitle: "真正的電台，即時收聽",
            .liveBody: "來自世界各地真實接收機和伺服器的短波、CB 27 MHz 和 POC 頻道，並顯示接收機的頻譜和瀑布圖。僅收聽，每天免費 5 分鐘，Talky Pro 無限制。",
            .radioTitle: "343 個全球電台",
            .radioBody: "切換到電台模組:來自 50 多個國家的已驗證電台,支援收藏、篩選與媒體鍵。",
            .proNote: "Talky Pro 與主題包與 iOS 應用程式通用:一次購買,解鎖 iPhone、iPad 與 Mac。",
            .next: "繼續", .back: "返回", .start: "開始",
        ],
    ]
}

// MARK: - View

struct OnboardingView: View {
    @EnvironmentObject private var engine: WalkieEngine
    @Environment(\.dismiss) private var dismiss

    var onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 26)

            // La sheet ha altezza fissa (430) e la pagina di rete ora porta anche
            // il promemoria sulla stessa Wi-Fi: in tedesco e thai quel blocco
            // cresce parecchio, quindi il contenuto scorre invece di essere
            // tagliato contro il bordo inferiore.
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch page {
                    case 0: pageView(icon: "mic.circle.fill",
                                     tint: Talky.signal,
                                     title: OBString.welcomeTitle.text,
                                     body: OBString.welcomeBody.text)
                    case 1: networkPage
                    case 2: pageView(icon: "dot.radiowaves.left.and.right",
                                     tint: Talky.amber,
                                     title: OBString.liveTitle.text,
                                     body: OBString.liveBody.text)
                    default: radioPage
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: .infinity)

            // Dots
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Talky.amber : Talky.dim.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, 18)

            // Controls
            //
            // Guideline 5.1.1(iv): dalla pagina che spiega il microfono si esce
            // **solo** passando per il prompt di sistema. Apple ha respinto la
            // 1.1.1 (77) perche' il bottone "Skip" permetteva di chiudere il
            // messaggio rinviando la richiesta: "the user should always proceed
            // to the permission request after the message". Skip e' quindi
            // sparito del tutto — la sheet ha gia' `.interactiveDismissDisabled()`,
            // quindi ora l'unico modo di finire l'onboarding e' attraversare
            // `micPage`, e li' il prompt parte sempre.
            HStack {
                Spacer()

                if page > 0 {
                    Button(OBString.back.text) {
                        withAnimation(.easeOut(duration: 0.18)) { page -= 1 }
                    }
                    .buttonStyle(ChipButtonStyle(accent: Talky.dim))
                }

                Button(page == pageCount - 1 ? OBString.start.text : OBString.next.text) {
                    advance()
                }
                .buttonStyle(ChipButtonStyle(filled: true))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
        }
        .frame(width: 480, height: 430)
        .background(Talky.coal)
    }

    private func finish() {
        onFinish()
        dismiss()
    }

    /// Indice della pagina che spiega a cosa serve il microfono.
    private var micPage: Int { 1 }

    /// Avanza di una pagina. Uscendo da `micPage` con il permesso ancora da
    /// decidere si presenta prima il prompt di sistema e si aspetta la risposta,
    /// cosi' la richiesta arriva mentre il messaggio che la spiega e' ancora a
    /// schermo. Se l'utente aveva gia' negato, `requestAccess` ritorna subito e
    /// non lo si blocca: la sua decisione resta quella.
    private func advance() {
        guard page == micPage, !engine.hasMicPermission, !engine.micPermissionDenied else {
            step()
            return
        }
        engine.requestMicPermission { step() }
    }

    private func step() {
        if page == pageCount - 1 {
            finish()
        } else {
            withAnimation(.easeOut(duration: 0.18)) { page += 1 }
        }
    }

    // MARK: - Pages

    private func pageView(icon: String, tint: Color, title: String, body: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.6), radius: 14)
            Text(title)
                .font(.talkyTitle(21))
                .foregroundStyle(Talky.text)
                .multilineTextAlignment(.center)
            Text(body)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Talky.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
    }

    private var networkPage: some View {
        VStack(spacing: 16) {
            pageView(icon: "wifi.circle.fill",
                     tint: Talky.teal,
                     title: OBString.networkTitle.text,
                     body: OBString.networkBody.text)
            // Nessun bottone dedicato al microfono: la richiesta parte dal
            // "Continue" in fondo alla sheet (vedi `advance()`). Prima ce n'era
            // uno etichettato "Enable microphone", respinto dalla 5.1.1(iv)
            // perche' spingeva verso il "si'"; sostituirlo con un secondo
            // "Continue" avrebbe messo due bottoni identici nella stessa
            // schermata, quindi la pagina ora si limita a spiegare.
            // Il Mac parla solo TALKY1 su Bonjour/TCP: senza la stessa rete Wi-Fi
            // non vede nessuno, ed e' la causa piu' probabile di un "non si
            // connette". Detto qui, dove l'utente sta gia' guardando la rete.
            Label(OBString.networkTip.text, systemImage: "wifi")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Talky.dim.opacity(0.8))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 46)
                .fixedSize(horizontal: false, vertical: true)

            if engine.hasMicPermission {
                Label(OBString.micGranted.text, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Talky.signal)
            }
        }
    }

    private var radioPage: some View {
        VStack(spacing: 16) {
            pageView(icon: "antenna.radiowaves.left.and.right.circle.fill",
                     tint: Talky.amber,
                     title: OBString.radioTitle.text,
                     body: OBString.radioBody.text)
            Text(OBString.proNote.text)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Talky.dim.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 46)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
