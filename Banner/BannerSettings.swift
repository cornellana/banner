import SwiftUI

/// Ajustes del rótulo: texto, color, velocidad, tamaño y destellos.
///
/// Los valores se conservan entre ejecuciones en `UserDefaults`; se guardan en
/// cada cambio porque son pocos y muy ligeros.
@Observable
final class BannerSettings {

    /// Texto que recorre la pantalla. Admite emoticonos.
    var text: String { didSet { save(text, for: .text) } }

    /// Tipografía con la que se dibuja el texto.
    var typeface: BannerTypeface { didSet { save(typeface.rawValue, for: .typeface) } }

    /// Tono del color en el espacio HSB, en el rango 0...1.
    var hue: Double { didSet { save(hue, for: .hue) } }

    /// Saturación del color en el rango 0...1.
    var saturation: Double { didSet { save(saturation, for: .saturation) } }

    /// Luminosidad del color en el rango 0...1.
    var brightness: Double { didSet { save(brightness, for: .brightness) } }

    /// Velocidad de desplazamiento en puntos por segundo.
    var speed: Double { didSet { save(speed, for: .speed) } }

    /// Fracción de la altura de la pantalla que ocupa el texto, en el rango 0...1.
    var heightFraction: Double { didSet { save(heightFraction, for: .heightFraction) } }

    /// Indica si el fondo debe destellar en el color elegido para llamar la atención.
    ///
    /// Se activa y desactiva con los botones de volumen mientras el rótulo está
    /// en pantalla; no se conserva entre ejecuciones para que la app arranque
    /// siempre en modo tranquilo.
    var flashesEnabled: Bool = false

    /// Destellos por segundo cuando ``flashesEnabled`` está activo.
    var flashRate: Double { didSet { save(flashRate, for: .flashRate) } }

    /// Color resultante de los tres deslizadores HSB.
    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    // MARK: - Límites de los deslizadores

    /// Velocidad mínima y máxima en puntos por segundo.
    static let speedRange: ClosedRange<Double> = 40...1600

    /// Proporción mínima y máxima de la altura de pantalla ocupada por el texto.
    static let heightRange: ClosedRange<Double> = 0.25...1.0

    /// Frecuencia mínima y máxima de destello en hercios.
    static let flashRateRange: ClosedRange<Double> = 0.5...8

    // MARK: - Ciclo de vida

    init() {
        let defaults = UserDefaults.standard
        text = defaults.string(forKey: Key.text.rawValue)
            ?? String(localized: "banner.defaultText", comment: "Texto de ejemplo que aparece la primera vez")
        typeface = defaults.string(forKey: Key.typeface.rawValue)
            .flatMap(BannerTypeface.init(rawValue:)) ?? .rounded
        hue = defaults.value(forKey: Key.hue.rawValue) as? Double ?? 0.12
        saturation = defaults.value(forKey: Key.saturation.rawValue) as? Double ?? 1.0
        brightness = defaults.value(forKey: Key.brightness.rawValue) as? Double ?? 1.0
        speed = defaults.value(forKey: Key.speed.rawValue) as? Double ?? 350
        heightFraction = defaults.value(forKey: Key.heightFraction.rawValue) as? Double ?? 0.8
        flashRate = defaults.value(forKey: Key.flashRate.rawValue) as? Double ?? 2
    }

    // MARK: - Persistencia

    private enum Key: String {
        case text, typeface, hue, saturation, brightness, speed, heightFraction, flashRate
    }

    private func save(_ value: Any, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
