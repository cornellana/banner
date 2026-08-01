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

    /// Etiqueta mostrada en el selector.
    ///
    /// Se devuelve como `Text` para que las cuatro primeras se traduzcan con el
    /// idioma activo en el entorno; los nombres de familia son marcas y no se
    /// traducen.
    var label: Text {
        switch self {
        case .rounded: Text("typeface.rounded")
        case .standard: Text("typeface.standard")
        case .serif: Text("typeface.serif")
        case .monospaced: Text("typeface.monospaced")
        case .avenirNext: Text(verbatim: "Avenir Next")
        case .futura: Text(verbatim: "Futura")
        case .georgia: Text(verbatim: "Georgia")
        case .helvetica: Text(verbatim: "Helvetica Neue")
        case .americanTypewriter: Text(verbatim: "American Typewriter")
        case .copperplate: Text(verbatim: "Copperplate")
        case .chalkboard: Text(verbatim: "Chalkboard")
        case .markerFelt: Text(verbatim: "Marker Felt")
        case .snellRoundhand: Text(verbatim: "Snell Roundhand")
        case .partyLET: Text(verbatim: "Party")
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
