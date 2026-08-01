import SwiftUI

/// Idioma con el que se muestra la interfaz.
///
/// La selección se aplica en caliente inyectando el `Locale` correspondiente en
/// el entorno de SwiftUI: los textos declarados con `LocalizedStringKey` se
/// resuelven en cada dibujado contra ese idioma, sin reiniciar la app.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Sigue el idioma configurado en el sistema.
    case system
    case english = "en"
    case spanish = "es"
    case catalan = "ca"

    var id: String { rawValue }

    /// Etiqueta del selector; cada idioma se escribe en sí mismo, y la opción
    /// automática se traduce (se resuelve con el idioma que esté activo).
    var label: Text {
        switch self {
        case .system: Text("settings.language.system")
        case .english: Text(verbatim: "English")
        case .spanish: Text(verbatim: "Español")
        case .catalan: Text(verbatim: "Català")
        }
    }

    /// Configuración regional que debe inyectarse en el entorno.
    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        default: Locale(identifier: rawValue)
        }
    }
}
