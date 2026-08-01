import SwiftUI

/// Tipografías disponibles para el rótulo.
///
/// Los cuatro primeros casos son los diseños del tipo de sistema (San Francisco
/// y New York), que se adaptan automáticamente a cualquier idioma. El resto son
/// familias incluidas en iOS, identificadas por su nombre PostScript; si alguna
/// no estuviera disponible en el dispositivo se recurre al tipo de sistema.
enum BannerTypeface: String, CaseIterable, Identifiable, Sendable {
    case rounded
    case standard
    case serif
    case monospaced
    case avenirNext = "AvenirNext-Heavy"
    case futura = "Futura-Bold"
    case georgia = "Georgia-Bold"
    case helvetica = "HelveticaNeue-Bold"
    case americanTypewriter = "AmericanTypewriter-Bold"
    case copperplate = "Copperplate-Bold"
    case chalkboard = "ChalkboardSE-Bold"
    case markerFelt = "MarkerFelt-Wide"
    case snellRoundhand = "SnellRoundhand-Black"
    case partyLET = "PartyLetPlain"

    var id: String { rawValue }

    /// Nombre mostrado en el selector. Los nombres de familia son marcas y no se traducen.
    var displayName: String {
        switch self {
        case .rounded: String(localized: "typeface.rounded", comment: "Nombre del tipo San Francisco Rounded")
        case .standard: String(localized: "typeface.standard", comment: "Nombre del tipo del sistema")
        case .serif: String(localized: "typeface.serif", comment: "Nombre del tipo con remates (New York)")
        case .monospaced: String(localized: "typeface.monospaced", comment: "Nombre del tipo monoespaciado")
        case .avenirNext: "Avenir Next"
        case .futura: "Futura"
        case .georgia: "Georgia"
        case .helvetica: "Helvetica Neue"
        case .americanTypewriter: "American Typewriter"
        case .copperplate: "Copperplate"
        case .chalkboard: "Chalkboard"
        case .markerFelt: "Marker Felt"
        case .snellRoundhand: "Snell Roundhand"
        case .partyLET: "Party"
        }
    }

    /// Diseño del tipo de sistema correspondiente, o `nil` si es una familia con nombre.
    private var systemDesign: Font.Design? {
        switch self {
        case .rounded: .rounded
        case .standard: .default
        case .serif: .serif
        case .monospaced: .monospaced
        default: nil
        }
    }

    /// Fuente de SwiftUI con el cuerpo indicado.
    /// - Parameter size: Cuerpo en puntos.
    func font(size: CGFloat) -> Font {
        if let systemDesign {
            .system(size: size, weight: .heavy, design: systemDesign)
        } else {
            .custom(rawValue, fixedSize: size)
        }
    }

    /// Equivalente en UIKit, usado para medir la anchura del texto.
    /// - Parameter size: Cuerpo en puntos.
    func uiFont(size: CGFloat) -> UIFont {
        let system = UIFont.systemFont(ofSize: size, weight: .heavy)
        guard let systemDesign else {
            return UIFont(name: rawValue, size: size) ?? system
        }
        let design: UIFontDescriptor.SystemDesign = switch systemDesign {
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        default: .default
        }
        guard let descriptor = system.fontDescriptor.withDesign(design) else { return system }
        return UIFont(descriptor: descriptor, size: size)
    }
}
