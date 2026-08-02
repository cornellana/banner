import SwiftUI
import UIKit

/// Rótulo desplazándose sobre su fondo, con los destellos aplicados.
///
/// Es el contenido visual puro, sin gestos ni controles: lo usan tanto la
/// pantalla del dispositivo como la proyección en una pantalla externa.
struct MarqueeBanner: View {
    let settings: BannerSettings

    /// Velocidad con la que se anima el recorrido, en puntos por segundo.
    ///
    /// Se recibe desde fuera porque la pantalla del dispositivo la congela
    /// mientras se arrastra el deslizador, para no reiniciar el recorrido en
    /// cada valor intermedio.
    let speed: Double

    /// Fase encendida del destello, conmutada por ``flashLoop()``.
    @State private var isLit = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fontSize = max(12, size.height * settings.heightFraction)
            // En el destello se intercambian los dos colores, para que el texto
            // siga legible cuando el fondo se enciende.
            let baseColor = UIColor(isLit ? settings.backgroundColor : settings.color)
            let styled = BannerText.styled(
                displayText,
                typeface: settings.typeface,
                fontSize: fontSize,
                baseColor: baseColor
            )

            ZStack {
                (isLit ? settings.color : settings.backgroundColor)

                MarqueeGlyphView(text: styled, path: settings.path, speed: speed)
            }
        }
        .task { await flashLoop() }
    }

    /// Mensaje listo para desplazarse: los saltos de línea se sustituyen por
    /// espacios porque el rótulo es siempre de una sola línea.
    private var displayText: NSAttributedString {
        let source = settings.attributedText
        guard source.length > 0 else { return BannerText.plain(" ") }

        let cleaned = NSMutableAttributedString(attributedString: source)
        while let range = cleaned.string.range(of: "\n") {
            cleaned.replaceCharacters(in: NSRange(range, in: cleaned.string), with: " ")
        }
        return cleaned
    }

    /// Alterna la fase del destello mientras la vista está en pantalla.
    ///
    /// Un bucle a la frecuencia elegida (como mucho unas pocas conmutaciones por
    /// segundo) evita tener que redibujar la vista en cada fotograma.
    private func flashLoop() async {
        while !Task.isCancelled {
            let halfPeriod = 0.5 / settings.flashRate
            try? await Task.sleep(for: .seconds(halfPeriod))
            guard settings.flashesEnabled else {
                if isLit { isLit = false }
                continue
            }
            isLit.toggle()
        }
    }
}
