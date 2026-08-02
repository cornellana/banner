import CoreText
import SwiftUI
import UIKit

/// Dibuja el mensaje letra a letra y las hace recorrer la pantalla siguiendo
/// una trayectoria.
///
/// Cada letra es una capa con su propia animación de fotogramas clave sobre el
/// mismo trazado; lo único que cambia entre ellas es el desfase temporal, que
/// es justo su posición dentro del mensaje. Así las letras van en fila y suben
/// y bajan al pasar por cada tramo del dibujo, y toda la animación la ejecuta
/// el servidor de render sin intervención del hilo principal.
struct MarqueeGlyphView: UIViewRepresentable {
    let text: NSAttributedString
    let path: BannerPath
    let speed: Double

    func makeUIView(context: Context) -> MarqueeContentView {
        let view = MarqueeContentView()
        view.configure(text: text, path: path, speed: speed)
        return view
    }

    func updateUIView(_ uiView: MarqueeContentView, context: Context) {
        uiView.configure(text: text, path: path, speed: speed)
    }
}

// MARK: - Vista de contenido

/// Vista que mantiene una capa por letra y sus animaciones.
final class MarqueeContentView: UIView {

    private var text = NSAttributedString()
    private var path = BannerPath.straight
    private var speed: Double = 300

    /// Identifica la disposición actual: mientras no cambie, un cambio de
    /// color solo repinta las capas en vez de rehacer la animación.
    private var layoutKey = ""

    private var glyphLayers: [(layer: CATextLayer, range: NSRange)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        // Al volver del segundo plano el sistema retira las animaciones.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildAfterForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    /// Actualiza el contenido y rehace la animación si hace falta.
    /// - Parameters:
    ///   - text: Mensaje con sus atributos ya resueltos.
    ///   - path: Trayectoria vertical.
    ///   - speed: Velocidad en puntos por segundo.
    func configure(text: NSAttributedString, path: BannerPath, speed: Double) {
        self.text = text
        self.path = path
        self.speed = speed
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildIfNeeded()
    }

    @objc private func rebuildAfterForeground() {
        layoutKey = ""
        setNeedsLayout()
    }

    // MARK: - Construcción

    private func rebuildIfNeeded() {
        let size = bounds.size
        guard size.width > 0, size.height > 0, text.length > 0 else { return }

        let key = "\(text.string)|\(Int(text.size().width))|\(Int(size.width))x\(Int(size.height))|\(speed)|\(path.points.count)|\(path.points.first?.y ?? 0)"
        guard key != layoutKey else {
            // Misma disposición: basta con repintar por si cambió el color.
            refreshColors()
            return
        }
        layoutKey = key
        rebuild(in: size)
    }

    /// Repinta las capas conservando la animación en curso.
    private func refreshColors() {
        for entry in glyphLayers {
            entry.layer.string = text.attributedSubstring(from: entry.range)
        }
    }

    private func rebuild(in size: CGSize) {
        glyphLayers.forEach { $0.layer.removeFromSuperlayer() }
        glyphLayers.removeAll()

        let line = CTLineCreateWithAttributedString(text)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        let lineHeight = ascent + descent
        guard textWidth > 0 else { return }

        let travel = textWidth + size.width
        let duration = Double(travel) / max(speed, 1)
        let trackPath = makeTrackPath(in: size, travel: travel, lineHeight: lineHeight)

        let string = text.string as NSString
        var index = 0
        while index < string.length {
            let range = string.rangeOfComposedCharacterSequence(at: index)
            index = NSMaxRange(range)

            let piece = text.attributedSubstring(from: range)
            // Los espacios no necesitan capa: solo separan.
            guard !piece.string.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let offset = CGFloat(CTLineGetOffsetForStringIndex(line, range.location, nil))
            let layer = makeLayer(for: piece, width: piece.size().width, height: lineHeight)
            layer.position = CGPoint(x: size.width + offset, y: size.height / 2)
            self.layer.addSublayer(layer)
            glyphLayers.append((layer, range))

            // Cada letra recorre el mismo trazado, retrasada justo lo que
            // tarda el rótulo en avanzar hasta su posición en el mensaje.
            let lag = Double(offset) / max(speed, 1)
            let animation = CAKeyframeAnimation(keyPath: "position")
            animation.path = trackPath
            animation.duration = duration
            animation.calculationMode = .linear
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            animation.timeOffset = duration - lag.truncatingRemainder(dividingBy: duration)
            layer.add(animation, forKey: "marquee")
        }
    }

    private func makeLayer(for piece: NSAttributedString, width: CGFloat, height: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = piece
        layer.isWrapped = false
        layer.alignmentMode = .left
        layer.contentsScale = traitCollection.displayScale
        // El anclaje a la izquierda y al medio hace que `position` sea el punto
        // por el que la letra va montada sobre la trayectoria.
        layer.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer.bounds = CGRect(x: 0, y: 0, width: ceil(width) + 2, height: ceil(height))
        return layer
    }

    /// Trazado que recorre el origen del mensaje, de derecha a izquierda.
    ///
    /// La altura sale del dibujo del usuario, acotada para que el texto no se
    /// salga por arriba ni por abajo.
    private func makeTrackPath(in size: CGSize, travel: CGFloat, lineHeight: CGFloat) -> CGPath {
        let margin = min(lineHeight / 2, size.height / 2)
        let top = margin
        let bottom = size.height - margin

        let trackPath = CGMutablePath()
        let samples = max(80, Int(travel / 6))
        for step in 0...samples {
            let progress = CGFloat(step) / CGFloat(samples)
            let x = size.width - progress * travel
            let y: CGFloat
            if path.isStraight || bottom <= top {
                y = size.height / 2
            } else {
                let normalized = path.normalizedY(at: Double(x / size.width))
                y = top + CGFloat(normalized) * (bottom - top)
            }
            let point = CGPoint(x: x, y: y)
            if step == 0 {
                trackPath.move(to: point)
            } else {
                trackPath.addLine(to: point)
            }
        }
        return trackPath
    }
}
