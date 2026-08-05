import UIKit

/// Utilidades del texto con atributos del rótulo.
///
/// El mensaje se guarda como `NSAttributedString` para poder llevar negrita,
/// cursiva, subrayado y colores por tramos. Lo que se conserva de cada tramo es
/// la *intención* —los rasgos y, si lo hay, un color propio—, no el tipo ni el
/// cuerpo concretos: esos se resuelven al dibujar, porque dependen de la
/// tipografía elegida y de la altura de la pantalla.
enum BannerText {

    /// Marca los tramos cuyo color eligió el usuario.
    ///
    /// Sin esta marca no se podría distinguir el color explícito del que UIKit
    /// pone por defecto en el editor, y todo el texto quedaría fijado a ese
    /// color en vez de seguir al color base del rótulo.
    static let customColorKey = NSAttributedString.Key("com.cornellana.banner.customColor")

    /// Cuerpo con el que se edita el mensaje en la pantalla de ajustes.
    static let editingFontSize: CGFloat = 20

    // MARK: - Construcción

    /// Crea un mensaje sin atributos a partir de texto plano.
    /// - Parameter string: Texto de partida.
    static func plain(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: UIFont.systemFont(ofSize: editingFontSize),
                .foregroundColor: UIColor.label
            ]
        )
    }

    /// Aplica al mensaje la tipografía, el cuerpo y el color base del rótulo.
    ///
    /// - Parameters:
    ///   - source: Mensaje tal y como lo editó el usuario.
    ///   - typeface: Tipografía elegida para el rótulo.
    ///   - fontSize: Cuerpo en puntos, derivado de la altura de la pantalla.
    ///   - baseColor: Color de los tramos a los que el usuario no dio uno propio.
    /// - Returns: El mensaje listo para dibujar.
    static func styled(
        _ source: NSAttributedString,
        typeface: BannerTypeface,
        fontSize: CGFloat,
        baseColor: UIColor,
        lightweight: Bool = false
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        guard whole.length > 0 else { return result }

        // Se recorre el original y se escribe en la copia: al añadir atributos
        // cambian los tramos, y enumerar el mismo texto que se está
        // modificando descuadra el recorrido y pisa los tramos siguientes.
        source.enumerateAttributes(in: whole, options: []) { attributes, range, _ in
            let editedFont = attributes[.font] as? UIFont
            let traits = editedFont?.fontDescriptor.symbolicTraits ?? []
            result.addAttribute(
                .font,
                value: font(for: typeface, size: fontSize, traits: traits, lightweight: lightweight),
                range: range
            )

            // El color se respeta si lo puso el usuario, ya sea con el selector
            // propio —que deja la marca— o desde el panel *Más…* del menú de
            // iOS, que no la deja y solo se distingue por no ser el color con
            // el que escribe el editor.
            let chosenColor = attributes[.foregroundColor] as? UIColor
            let keepsColor = attributes[customColorKey] != nil || !isEditorColor(chosenColor)
            if !keepsColor {
                result.addAttribute(.foregroundColor, value: baseColor, range: range)
            }
        }
        return result
    }

    /// Indica si el color es el que usa el editor por omisión.
    ///
    /// El editor escribe en `label`, que se resuelve en negro o en blanco según
    /// la apariencia del sistema. Un tramo con ese color es un tramo al que el
    /// usuario no le dio color propio, y por tanto sigue al color base del
    /// rótulo. La contrapartida es que un negro o un blanco elegidos desde el
    /// panel del sistema no se distinguen del valor por omisión; con el
    /// selector propio de la app sí, porque deja marca.
    private static func isEditorColor(_ color: UIColor?) -> Bool {
        guard let color else { return true }
        if color.isEqual(UIColor.label) { return true }

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let isBlack = red < 0.02 && green < 0.02 && blue < 0.02
        let isWhite = red > 0.98 && green > 0.98 && blue > 0.98
        return isBlack || isWhite
    }

    /// Fuente del rótulo con los rasgos del tramo (negrita y cursiva) aplicados.
    private static func font(
        for typeface: BannerTypeface,
        size: CGFloat,
        traits: UIFontDescriptor.SymbolicTraits,
        lightweight: Bool = false
    ) -> UIFont {
        let base = typeface.uiFont(size: size,
                                   bold: traits.contains(.traitBold),
                                   lightweight: lightweight)
        guard traits.contains(.traitItalic) else { return base }

        if let descriptor = base.fontDescriptor.withSymbolicTraits(
            base.fontDescriptor.symbolicTraits.union(.traitItalic)
        ) {
            let italic = UIFont(descriptor: descriptor, size: size)
            // Si la familia no tiene corte cursivo, el sistema devuelve el
            // mismo tipo sin avisar; se detecta comparando el nombre.
            if italic.fontName != base.fontName { return italic }
        }

        // Inclinación sintética para las familias sin cursiva propia, como
        // San Francisco Rounded, que es la tipografía por omisión del rótulo.
        let slant = CGAffineTransform(a: 1, b: 0, c: obliqueSlant, d: 1, tx: 0, ty: 0)
        return UIFont(descriptor: base.fontDescriptor.withMatrix(slant), size: size)
    }

    /// Inclinación de la cursiva sintética: 12°, la pendiente habitual de las
    /// cursivas de palo seco.
    private static let obliqueSlant = CGFloat(tan(12 * Double.pi / 180))

    // MARK: - Persistencia

    /// Convierte el mensaje en datos para guardarlo.
    ///
    /// Se archiva en lugar de exportarlo a RTF porque el archivado conserva los
    /// atributos propios de la app, y RTF no.
    /// - Parameter text: Mensaje a guardar.
    static func archive(_ text: NSAttributedString) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: text, requiringSecureCoding: false)
    }

    /// Recupera un mensaje archivado.
    /// - Parameter data: Datos devueltos por ``archive(_:)``.
    static func unarchive(_ data: Data) -> NSAttributedString? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data)
    }
}
