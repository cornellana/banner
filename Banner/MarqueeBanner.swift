import SwiftUI

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
            let textWidth = Self.width(of: displayText, typeface: settings.typeface, fontSize: fontSize)
            // Recorrido completo: entra por la derecha y sale del todo por la
            // izquierda antes de volver a empezar.
            let duration = Double(textWidth + size.width) / max(speed, 1)

            ZStack {
                (isLit ? settings.color : settings.backgroundColor)

                MarqueeText(
                    text: displayText,
                    font: settings.typeface.font(size: fontSize),
                    // En el destello se intercambian los dos colores, para que
                    // el texto siga legible cuando el fondo se enciende.
                    color: isLit ? settings.backgroundColor : settings.color,
                    textWidth: textWidth,
                    canvas: size,
                    duration: duration
                )
                // Recrear la vista es la forma de reiniciar el recorrido cuando
                // cambia el texto, la tipografía, el tamaño o la velocidad.
                .id("\(displayText)|\(settings.typeface.rawValue)|\(fontSize)|\(speed)|\(size.width)")
                .clipped()
            }
        }
        .task { await flashLoop() }
    }

    /// Texto mostrado: los saltos de línea se sustituyen por espacios porque el
    /// rótulo es siempre de una sola línea.
    private var displayText: String {
        let cleaned = settings.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? " " : cleaned + "   "
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

    /// Anchura que ocupará el texto con la fuente indicada.
    ///
    /// Se mide con UIKit en lugar de con una `PreferenceKey` para no encadenar
    /// una nueva pasada de layout con cada cambio. La fuente de UIKit es la misma
    /// que usa `Text`, y el sistema aplica el mismo repertorio de fuentes de
    /// reserva para los emoticonos.
    private static func width(of text: String, typeface: BannerTypeface, fontSize: CGFloat) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: typeface.uiFont(size: fontSize)]).width
    }
}

// MARK: - Texto animado

/// Texto que recorre el ancho del rótulo con una animación cíclica.
///
/// La animación se declara con `.animation(_:value:)` y `repeatForever`, de modo
/// que la ejecuta el servidor de render y el hilo principal no interviene en
/// cada fotograma. El estado propio de la vista permite reiniciar el recorrido
/// recreándola con `.id(_:)`.
private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let textWidth: CGFloat
    let canvas: CGSize
    let duration: Double

    @State private var hasScrolled = false

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .offset(x: hasScrolled ? -textWidth : canvas.width)
            .frame(width: canvas.width, height: canvas.height, alignment: .leading)
            .animation(
                .linear(duration: duration).repeatForever(autoreverses: false),
                value: hasScrolled
            )
            .onAppear { hasScrolled = true }
    }
}
