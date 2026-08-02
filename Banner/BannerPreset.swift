import SwiftUI

/// Mensaje guardado con todas sus características.
///
/// Es una instantánea de los ajustes en el momento de guardar: recuperarlo
/// restituye texto, tipografía, colores, velocidad, tamaño y frecuencia de
/// destello tal y como estaban.
struct BannerPreset: Identifiable, Codable, Hashable {
    let id: UUID
    let savedAt: Date

    var text: String
    var typeface: BannerTypeface
    var hue: Double
    var saturation: Double
    var brightness: Double
    var backgroundHue: Double
    var backgroundSaturation: Double
    var backgroundBrightness: Double
    var speed: Double
    var heightFraction: Double
    var flashRate: Double

    /// Color del texto guardado.
    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Color de fondo guardado.
    var backgroundColor: Color {
        Color(hue: backgroundHue, saturation: backgroundSaturation, brightness: backgroundBrightness)
    }

    /// Crea el mensaje a partir de los ajustes vigentes.
    /// - Parameters:
    ///   - settings: Ajustes de los que se toma la instantánea.
    ///   - date: Momento en que se guarda; se inyecta para poder probarlo.
    init(settings: BannerSettings, date: Date = .now) {
        id = UUID()
        savedAt = date
        text = settings.text
        typeface = settings.typeface
        hue = settings.hue
        saturation = settings.saturation
        brightness = settings.brightness
        backgroundHue = settings.backgroundHue
        backgroundSaturation = settings.backgroundSaturation
        backgroundBrightness = settings.backgroundBrightness
        speed = settings.speed
        heightFraction = settings.heightFraction
        flashRate = settings.flashRate
    }
}
