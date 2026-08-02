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
            let textWidth = styled.size().width
            // Recorrido completo: entra por la derecha y sale del todo por la
            // izquierda antes de volver a empezar.
            let duration = Double(textWidth + size.width) / max(speed, 1)

            ZStack {
                (isLit ? settings.color : settings.backgroundColor)

                MarqueeText(
                    text: styled,
                    textWidth: textWidth,
                    canvas: size,
                    duration: duration
                )
                // Recrear la vista es la forma de reiniciar el recorrido cuando
                // cambia el mensaje, la tipografía, el tamaño o la velocidad.
                .id("\(styled.string)|\(Int(textWidth))|\(Int(fontSize))|\(speed)|\(size.width)")
                .clipped()
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

// MARK: - Texto animado

/// Texto que recorre el ancho del rótulo con una animación cíclica.
///
/// La animación se declara con `.animation(_:value:)` y `repeatForever`, de modo
/// que la ejecuta el servidor de render y el hilo principal no interviene en
/// cada fotograma. El estado propio de la vista permite reiniciar el recorrido
/// recreándola con `.id(_:)`.
private struct MarqueeText: View {
    let text: NSAttributedString
    let textWidth: CGFloat
    let canvas: CGSize
    let duration: Double

    @State private var hasScrolled = false

    var body: some View {
        AttributedLabel(attributedText: text)
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
