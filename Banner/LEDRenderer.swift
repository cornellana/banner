import CoreText
import UIKit

/// Convierte texto en una matriz de puntos, al modo de los paneles de LEDs.
///
/// La letra se dibuja primero en un mapa de bits y después se muestrea en una
/// rejilla: cada celda que tenga tinta se convierte en un punto del color que
/// hubiera ahí. Tomar el color del píxel —en vez de recibirlo como parámetro—
/// conserva el formato por tramos: un mensaje con varios colores sigue teniendo
/// varios colores al pasar a puntos.
///
/// No se dibujan los puntos apagados. Un panel real los tiene, pero aquí cada
/// letra es una capa independiente y una rejilla de fondo dejaría ver el
/// rectángulo de cada una.
enum LEDRenderer {

    /// Separación entre centros de puntos, deducida del cuerpo de la letra.
    ///
    /// Alrededor de dieciséis puntos de altura por letra. Con doce —la
    /// proporción de un panel de tráfico— las minúsculas de una tipografía
    /// gruesa se funden y «Hello» se lee «HB||P|»: aquellos paneles usan tipos
    /// dibujados para la rejilla, y aquí la rejilla se aplica sobre cualquier
    /// tipografía, así que hace falta más resolución.
    /// - Parameter fontSize: Cuerpo en puntos.
    /// - Returns: Paso de la rejilla en puntos.
    static func pitch(forFontSize fontSize: CGFloat) -> CGFloat {
        max(2, (fontSize / 22).rounded())
    }

    /// Dibuja un trozo de texto como matriz de puntos.
    ///
    /// - Parameters:
    ///   - piece: Texto con sus atributos ya resueltos (tipo, cuerpo y color).
    ///   - pitch: Separación entre centros de puntos, en puntos.
    ///   - scale: Escala de pantalla, para que los puntos salgan nítidos.
    /// - Returns: Imagen con la letra en puntos, o `nil` si no se pudo dibujar.
    static func image(for piece: NSAttributedString,
                      pitch: CGFloat,
                      scale: CGFloat) -> UIImage? {

        let medida = piece.size()
        let ancho = ceil(medida.width) + 2
        let alto = ceil(medida.height) + 2
        guard ancho > 1, alto > 1 else { return nil }

        // 1 — La letra, tal cual, en un mapa de bits que luego se lee píxel a píxel.
        let px = Int(ancho * scale), py = Int(alto * scale)
        guard let origen = CGContext(
            data: nil, width: px, height: py,
            bitsPerComponent: 8, bytesPerRow: px * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        origen.scaleBy(x: scale, y: scale)
        UIGraphicsPushContext(origen)
        piece.draw(at: .zero)
        UIGraphicsPopContext()

        guard let datos = origen.data else { return nil }
        let pixeles = datos.bindMemory(to: UInt8.self, capacity: px * py * 4)

        /// Color de una celda de la rejilla, o `nil` si no tiene tinta suficiente.
        ///
        /// Se promedia la opacidad de toda la celda en vez de mirar solo su
        /// centro: un trazo fino que no pasara justo por el centro desaparecía,
        /// y las letras se rompían. El color se toma del píxel más opaco, que es
        /// el que representa el trazo y no su borde difuminado.
        func tinta(enCelda cx: CGFloat, _ cy: CGFloat, lado: CGFloat) -> UIColor? {
            let x0 = max(0, Int((cx - lado / 2) * scale))
            let x1 = min(px - 1, Int((cx + lado / 2) * scale))
            let y0 = max(0, Int((cy - lado / 2) * scale))
            let y1 = min(py - 1, Int((cy + lado / 2) * scale))
            guard x0 <= x1, y0 <= y1 else { return nil }

            var suma = 0, muestras = 0, mejorAlfa: UInt8 = 0, mejorOrigen = -1
            for y in y0...y1 {
                for x in x0...x1 {
                    let o = (y * px + x) * 4
                    let a = pixeles[o + 3]
                    suma += Int(a); muestras += 1
                    if a > mejorAlfa { mejorAlfa = a; mejorOrigen = o }
                }
            }
            // Más de media celda cubierta. Con un umbral bajo se encienden las
            // celdas del contrapunzón de la «e» o la «o», que solo tienen el
            // borde difuminado del trazo, y la letra se cierra.
            guard muestras > 0, suma / muestras > 140, mejorOrigen >= 0 else { return nil }

            let f = CGFloat(mejorAlfa) / 255
            guard f > 0 else { return nil }
            return UIColor(red: CGFloat(pixeles[mejorOrigen]) / 255 / f,
                           green: CGFloat(pixeles[mejorOrigen + 1]) / 255 / f,
                           blue: CGFloat(pixeles[mejorOrigen + 2]) / 255 / f,
                           alpha: 1)
        }

        // 2 — La rejilla de puntos.
        let formato = UIGraphicsImageRendererFormat.preferred()
        formato.scale = scale
        formato.opaque = false
        let render = UIGraphicsImageRenderer(size: CGSize(width: ancho, height: alto),
                                             format: formato)

        let diametro = pitch * 0.82   // Deja aire entre puntos; pegados no parecen LEDs.
        return render.image { contexto in
            let ctx = contexto.cgContext
            var y = pitch / 2
            while y < alto {
                var x = pitch / 2
                while x < ancho {
                    if let color = tinta(enCelda: x, y, lado: pitch) {
                        ctx.setFillColor(color.cgColor)
                        ctx.fillEllipse(in: CGRect(x: x - diametro / 2,
                                                   y: y - diametro / 2,
                                                   width: diametro,
                                                   height: diametro))
                    }
                    x += pitch
                }
                y += pitch
            }
        }
    }
}
