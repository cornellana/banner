import SwiftUI

/// Ajustes del rótulo: texto, color, velocidad, tamaño y destellos.
///
/// Los valores se conservan entre ejecuciones en `UserDefaults`; se guardan en
/// cada cambio porque son pocos y muy ligeros.
@Observable
final class BannerSettings {

    /// Mensaje que recorre la pantalla.
    ///
    /// Lleva atributos —negrita, cursiva, subrayado y colores por tramos—
    /// además de admitir emoticonos.
    var attributedText: NSAttributedString {
        didSet {
            guard let data = BannerText.archive(attributedText) else { return }
            save(data, for: .richText)
        }
    }

    /// El mensaje sin atributos, para comprobaciones y para mostrarlo en listas.
    var plainText: String { attributedText.string }

    /// Tipografía con la que se dibuja el texto.
    var typeface: BannerTypeface { didSet { save(typeface.rawValue, for: .typeface) } }

    /// Idioma de la interfaz, independiente del idioma del sistema.
    var language: AppLanguage { didSet { save(language.rawValue, for: .language) } }

    /// Tono del color en el espacio HSB, en el rango 0...1.
    var hue: Double { didSet { save(hue, for: .hue) } }

    /// Saturación del color en el rango 0...1.
    var saturation: Double { didSet { save(saturation, for: .saturation) } }

    /// Luminosidad del color en el rango 0...1.
    var brightness: Double { didSet { save(brightness, for: .brightness) } }

    /// Tono del fondo en el espacio HSB, en el rango 0...1.
    var backgroundHue: Double { didSet { save(backgroundHue, for: .backgroundHue) } }

    /// Saturación del fondo en el rango 0...1.
    var backgroundSaturation: Double { didSet { save(backgroundSaturation, for: .backgroundSaturation) } }

    /// Luminosidad del fondo en el rango 0...1; en 0 el fondo es negro.
    var backgroundBrightness: Double { didSet { save(backgroundBrightness, for: .backgroundBrightness) } }

    /// Trayectoria vertical que siguen las letras al desfilar.
    var path: BannerPath {
        didSet {
            guard let data = try? JSONEncoder().encode(path) else { return }
            save(data, for: .path)
        }
    }

    /// Dibuja el texto como una matriz de puntos, al modo de los paneles de LEDs.
    ///
    /// No cambia la tipografía: se sigue usando la elegida, y lo que se
    /// convierte en puntos es su dibujo. Así el formato por tramos y los
    /// emoticonos siguen funcionando igual.
    var ledEnabled: Bool { didSet { save(ledEnabled, for: .ledEnabled) } }

    /// Velocidad de desplazamiento en puntos por segundo.
    var speed: Double { didSet { save(speed, for: .speed) } }

    /// Cuántas veces más rápido va el vídeo exportado que el rótulo en pantalla.
    ///
    /// Son dos usos distintos: el cartel se lee en persona y conviene lento,
    /// mientras que el vídeo se comparte y un mensaje corto tardaba casi un
    /// minuto en cruzar. Por eso el valor por omisión es 2.
    var videoSpeedFactor: Double { didSet { save(videoSpeedFactor, for: .videoSpeedFactor) } }

    /// Multiplicadores ofrecidos para la velocidad del vídeo.
    static let videoSpeedFactors: [Double] = [1, 2, 3, 4]

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

    /// Color del texto, resultante de los tres deslizadores HSB.
    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Color del fondo del rótulo.
    var backgroundColor: Color {
        Color(hue: backgroundHue, saturation: backgroundSaturation, brightness: backgroundBrightness)
    }

    /// Restituye un mensaje guardado con todas sus características.
    /// - Parameter preset: Mensaje que se quiere volver a usar.
    func apply(_ preset: BannerPreset) {
        attributedText = preset.attributedText
        typeface = preset.typeface
        hue = preset.hue
        saturation = preset.saturation
        brightness = preset.brightness
        backgroundHue = preset.backgroundHue
        backgroundSaturation = preset.backgroundSaturation
        backgroundBrightness = preset.backgroundBrightness
        path = preset.path ?? .straight
        speed = preset.speed
        heightFraction = preset.heightFraction
        flashRate = preset.flashRate
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
        // Los mensajes guardados antes de admitir atributos se recuperan como
        // texto plano.
        if let data = defaults.data(forKey: Key.richText.rawValue),
           let restored = BannerText.unarchive(data) {
            attributedText = restored
        } else {
            let legacy = defaults.string(forKey: Key.text.rawValue)
                ?? String(localized: "banner.defaultText", comment: "Texto de ejemplo que aparece la primera vez")
            attributedText = BannerText.plain(legacy)
        }
        typeface = defaults.string(forKey: Key.typeface.rawValue)
            .flatMap(BannerTypeface.init(rawValue:)) ?? .rounded
        language = defaults.string(forKey: Key.language.rawValue)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        hue = defaults.value(forKey: Key.hue.rawValue) as? Double ?? 0.12
        saturation = defaults.value(forKey: Key.saturation.rawValue) as? Double ?? 1.0
        brightness = defaults.value(forKey: Key.brightness.rawValue) as? Double ?? 1.0
        ledEnabled = defaults.bool(forKey: Key.ledEnabled.rawValue)
        let factor = defaults.double(forKey: Key.videoSpeedFactor.rawValue)
        videoSpeedFactor = factor > 0 ? factor : 2
        path = defaults.data(forKey: Key.path.rawValue)
            .flatMap { try? JSONDecoder().decode(BannerPath.self, from: $0) } ?? .straight
        backgroundHue = defaults.value(forKey: Key.backgroundHue.rawValue) as? Double ?? 0
        backgroundSaturation = defaults.value(forKey: Key.backgroundSaturation.rawValue) as? Double ?? 0
        // Por defecto el fondo es negro, que es lo que más contrasta con el texto.
        backgroundBrightness = defaults.value(forKey: Key.backgroundBrightness.rawValue) as? Double ?? 0
        speed = defaults.value(forKey: Key.speed.rawValue) as? Double ?? 350
        heightFraction = defaults.value(forKey: Key.heightFraction.rawValue) as? Double ?? 0.8
        flashRate = defaults.value(forKey: Key.flashRate.rawValue) as? Double ?? 2
    }

    // MARK: - Persistencia

    private enum Key: String {
        case text, richText, typeface, language, hue, saturation, brightness
        case backgroundHue, backgroundSaturation, backgroundBrightness
        case speed, heightFraction, flashRate, path
        case ledEnabled, videoSpeedFactor
    }

    private func save(_ value: Any, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
