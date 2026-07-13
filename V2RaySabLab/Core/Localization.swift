import Foundation
import Combine

/// Supported UI languages.
/// Add a new case here AND a column in `L10n.dict` to extend.
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, ru, uz

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .uz: return "O‘zbek"
        }
    }

    /// Unicode regional-indicator flag emoji.
    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .ru: return "🇷🇺"
        case .uz: return "🇺🇿"
        }
    }

    /// Best-effort match to the device's preferred language at first launch.
    static var systemDefault: AppLanguage {
        let pref = Locale.preferredLanguages.first ?? "en"
        let base = pref.split(separator: "-").first.map(String.init) ?? "en"
        return AppLanguage(rawValue: base) ?? .en
    }
}

/// Holds the active UI language. UI views observe this and re-render when it
/// changes. Persists across launches via UserDefaults.
@MainActor
final class LanguageStore: ObservableObject {

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
        }
    }

    private static let defaultsKey = "v2raysablab.language"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let lang = AppLanguage(rawValue: saved) {
            self.language = lang
        } else {
            // Default to Russian for new installs (project requirement).
            // User can override via the language switcher; their choice is then persisted.
            self.language = .ru
        }
    }
}

/// Tiny translation helper. Pragmatic choice over .xcstrings for runtime
/// language switching: with `Text(LocalizedStringKey)` SwiftUI uses the
/// bundle's localization, which doesn't react to in-app language changes
/// without bundle-swizzling. A dict lookup keyed by AppLanguage is dumb,
/// explicit, and trivial to extend.
enum L10n {
    /// Translate a key. Falls back to English, then to the raw key.
    static func t(_ key: Key, _ lang: AppLanguage) -> String {
        let row = dict[key] ?? [:]
        return row[lang] ?? row[.en] ?? key.rawValue
    }

    enum Key: String {
        case connectionTime
        case statusDisconnected
        case statusConnecting
        case statusConnected
        case statusDisconnecting
        case statusInstallProfile
        case statusErrorPrefix
        case configurations
        case emptyConfigs
        case scanQR
        case enterLink
        case importClipboard
        case cancel
        case add
        case tryAgain
        case delete
        case vlessURL
        case clipboardEmpty
        case cameraDenied
        case language
        case privacyTitle
        case privacyNoLogging
        case privacyLocalConfigs
        case privacyRoutingOnly
        case privacyNoThirdParty
        case privacyAgreeContinue
        case dataPrivacy
        case done
    }

    private static let dict: [Key: [AppLanguage: String]] = [
        .connectionTime: [
            .en: "Connection time",
            .ru: "Время соединения",
            .uz: "Ulanish vaqti",
        ],
        .statusDisconnected: [
            .en: "Disconnected",
            .ru: "Отключено",
            .uz: "Uzilgan",
        ],
        .statusConnecting: [
            .en: "Connecting…",
            .ru: "Подключение…",
            .uz: "Ulanmoqda…",
        ],
        .statusConnected: [
            .en: "Connected",
            .ru: "Подключено",
            .uz: "Ulangan",
        ],
        .statusDisconnecting: [
            .en: "Disconnecting…",
            .ru: "Отключение…",
            .uz: "Uzilmoqda…",
        ],
        .statusInstallProfile: [
            .en: "Install profile",
            .ru: "Установите профиль",
            .uz: "Profilni o‘rnating",
        ],
        .statusErrorPrefix: [
            .en: "Error",
            .ru: "Ошибка",
            .uz: "Xato",
        ],
        .configurations: [
            .en: "Configurations",
            .ru: "Конфигурации",
            .uz: "Konfiguratsiyalar",
        ],
        .emptyConfigs: [
            .en: "No configurations yet.\nTap + to add one.",
            .ru: "Нет конфигураций.\nНажмите + чтобы добавить.",
            .uz: "Hech qanday konfiguratsiya yo‘q.\nQo‘shish uchun + tugmasini bosing.",
        ],
        .scanQR: [
            .en: "Scan QR",
            .ru: "Сканировать QR",
            .uz: "QR skanerlash",
        ],
        .enterLink: [
            .en: "Enter link",
            .ru: "Ввести ссылку",
            .uz: "Havolani kiritish",
        ],
        .importClipboard: [
            .en: "Import from clipboard",
            .ru: "Импорт из буфера",
            .uz: "Buferdan import qilish",
        ],
        .cancel: [
            .en: "Cancel",
            .ru: "Отмена",
            .uz: "Bekor qilish",
        ],
        .add: [
            .en: "Add",
            .ru: "Добавить",
            .uz: "Qo‘shish",
        ],
        .tryAgain: [
            .en: "Try again",
            .ru: "Повторить",
            .uz: "Qayta urinish",
        ],
        .delete: [
            .en: "Delete",
            .ru: "Удалить",
            .uz: "O‘chirish",
        ],
        .vlessURL: [
            .en: "VLESS URL",
            .ru: "VLESS URL",
            .uz: "VLESS URL",
        ],
        .clipboardEmpty: [
            .en: "Clipboard is empty.",
            .ru: "Буфер обмена пуст.",
            .uz: "Bufer bo‘sh.",
        ],
        .cameraDenied: [
            .en: "Camera access denied.\nEnable it in Settings → V2RaySabLab → Camera.",
            .ru: "Доступ к камере запрещён.\nВключите в Настройках → V2RaySabLab → Камера.",
            .uz: "Kameraga ruxsat berilmagan.\nSozlamalar → V2RaySabLab → Kamera bo‘limidan yoqing.",
        ],
        .language: [
            .en: "Language",
            .ru: "Язык",
            .uz: "Til",
        ],
        .privacyTitle: [
            .en: "Your Privacy",
            .ru: "Ваша конфиденциальность",
            .uz: "Maxfiyligingiz",
        ],
        .privacyNoLogging: [
            .en: "This app does not collect, log, inspect, or transmit your browsing history, DNS queries, network traffic content, or IP address.",
            .ru: "Приложение не собирает, не записывает, не анализирует и не передаёт историю посещений, DNS-запросы, содержимое сетевого трафика или ваш IP-адрес.",
            .uz: "Ilova brauzer tarixingizni, DNS so‘rovlaringizni, tarmoq trafigi mazmunini yoki IP-manzilingizni yig‘maydi, yozib olmaydi, tekshirmaydi va uzatmaydi.",
        ],
        .privacyLocalConfigs: [
            .en: "VPN server configurations you add are stored only on this device and are never uploaded to our servers.",
            .ru: "Добавленные вами конфигурации VPN-серверов хранятся только на этом устройстве и никогда не загружаются на наши серверы.",
            .uz: "Siz qo‘shgan VPN-server konfiguratsiyalari faqat shu qurilmada saqlanadi va hech qachon serverlarimizga yuklanmaydi.",
        ],
        .privacyRoutingOnly: [
            .en: "We use the VPN connection solely to route your traffic to the server you configure.",
            .ru: "VPN-соединение используется исключительно для маршрутизации вашего трафика на выбранный вами сервер.",
            .uz: "VPN ulanishi faqat trafigingizni siz sozlagan serverga yo‘naltirish uchun ishlatiladi.",
        ],
        .privacyNoThirdParty: [
            .en: "The app contains no advertising, tracking, or analytics SDKs, and shares no data with third parties.",
            .ru: "В приложении нет рекламы, трекеров и аналитических SDK; данные не передаются третьим лицам.",
            .uz: "Ilovada reklama, kuzatuv yoki analitika SDK’lari yo‘q; ma’lumotlar uchinchi tomonlarga berilmaydi.",
        ],
        .privacyAgreeContinue: [
            .en: "I Agree and Continue",
            .ru: "Принимаю и продолжаю",
            .uz: "Roziman va davom etaman",
        ],
        .dataPrivacy: [
            .en: "Data & Privacy",
            .ru: "Данные и конфиденциальность",
            .uz: "Ma’lumotlar va maxfiylik",
        ],
        .done: [
            .en: "Done",
            .ru: "Готово",
            .uz: "Tayyor",
        ],
    ]
}
