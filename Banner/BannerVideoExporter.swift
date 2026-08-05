import AVFoundation
import CoreText
import SwiftUI
import UIKit

/// Exporta el rótulo a un vídeo MP4 listo para compartir.
///
/// No graba la pantalla: **redibuja** cada fotograma. La posición de una letra
/// en el instante `t` es una función pura —`x = ancho + desfase − velocidad·t`,
/// y la altura sale del trazo del usuario—, así que el vídeo se puede calcular
/// entero sin que la app esté en pantalla.
///
/// Esto tiene tres ventajas sobre grabar con ReplayKit: no pide permiso, no
/// aparecen la barra de estado ni los dedos, y el resultado va a fotogramas
/// constantes aunque el dispositivo esté ocupado.
///
/// Los destellos no se incluyen a propósito: un fondo parpadeando a varios
/// hercios se comprime fatal y en un vídeo corto resulta molesto.
enum BannerVideoExporter {

    /// Errores que pueden impedir la exportación.
    enum Failure: LocalizedError {
        case emptyMessage
        case writerFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyMessage:            String(localized: "The message is empty.")
            case .writerFailed(let razon): razon
            }
        }
    }

    /// Una letra con su desfase dentro del mensaje, ya medida.
    private struct Glyph {
        let line: CTLine
        /// Desplazamiento horizontal de la letra dentro del mensaje, en puntos.
        let offset: CGFloat
        /// Anchura tipográfica, para descartarla cuando sale de pantalla.
        let width: CGFloat
        /// Dibujo en matriz de puntos, cuando el rótulo va en modo LED.
        let dots: CGImage?
        /// Altura del dibujo en puntos, necesaria para colocarlo.
        let dotsHeight: CGFloat
    }

    /// Genera el vídeo y devuelve la URL del archivo temporal.
    ///
    /// - Parameters:
    ///   - settings: Ajustes vigentes; de aquí salen texto, tipografía, colores,
    ///     trayectoria, velocidad y proporción de altura.
    ///   - size: Tamaño del lienzo en puntos. Debe ser apaisado.
    ///   - fps: Fotogramas por segundo del vídeo resultante.
    ///   - progress: Se invoca en el hilo principal con el avance de 0 a 1.
    /// - Returns: URL de un MP4 en el directorio temporal.
    /// - Throws: ``Failure`` si el mensaje está vacío o el escritor falla.
    static func export(settings: BannerSettings,
                       size: CGSize = CGSize(width: 1920, height: 1080),
                       fps: Int32 = 30,
                       progress: @MainActor @escaping (Double) -> Void = { _ in }) async throws -> URL {

        let fontSize = max(12, size.height * settings.heightFraction)
        let texto = BannerText.styled(displayText(from: settings),
                                      typeface: settings.typeface,
                                      fontSize: fontSize,
                                      baseColor: UIColor(settings.color),
                                      lightweight: settings.ledEnabled)

        let linea = CTLineCreateWithAttributedString(texto)
        var ascent: CGFloat = 0, descent: CGFloat = 0
        let anchoTexto = CGFloat(CTLineGetTypographicBounds(linea, &ascent, &descent, nil))
        let altoLinea = ascent + descent
        guard anchoTexto > 0 else { throw Failure.emptyMessage }

        let glyphs = trocear(texto, linea: linea,
                             led: settings.ledEnabled,
                             pitch: LEDRenderer.pitch(forFontSize: fontSize),
                             altoLinea: altoLinea)
        let recorrido = anchoTexto + size.width
        let velocidad = max(settings.speed, 1)
        // Una pasada completa, más lo que tarda la última letra en salir.
        let segundos = (recorrido + anchoTexto) / velocidad
        let total = Int(ceil(segundos * Double(fps)))

        let margen = min(altoLinea / 2, size.height / 2)
        let arriba = margen
        let abajo = size.height - margen

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("neonda-\(UUID().uuidString.prefix(8)).mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fondo = UIColor(settings.backgroundColor).cgColor
        let espacio = CGColorSpaceCreateDeviceRGB()

        for frame in 0..<total {
            let t = Double(frame) / Double(fps)

            // Se espera a que el escritor tenga hueco en vez de encolar sin
            // control: con vídeos largos, encolar de golpe dispara la memoria.
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }

            guard let pool = adaptor.pixelBufferPool else {
                throw Failure.writerFailed(writer.error?.localizedDescription
                                           ?? String(localized: "Could not prepare the video."))
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let pixels = buffer else { continue }

            CVPixelBufferLockBaseAddress(pixels, [])
            if let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(pixels),
                width: Int(size.width), height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
                space: espacio,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {

                ctx.setFillColor(fondo)
                ctx.fill(CGRect(origin: .zero, size: size))

                for g in glyphs {
                    let x = size.width + g.offset - CGFloat(velocidad * t)
                    guard x + g.width > 0, x < size.width else { continue }

                    let normalizada = settings.path.isStraight || abajo <= arriba
                        ? 0.5
                        : settings.path.normalizedY(at: Double(x / size.width))
                    let centro = arriba + CGFloat(normalizada) * (abajo - arriba)

                    // La capa se ancla a la izquierda y al medio, con la altura
                    // de línea completa: la base del texto queda a `ascent` del
                    // borde superior. Aquí se replica, invirtiendo la Y porque
                    // Core Graphics tiene el origen abajo.
                    if let puntos = g.dots {
                        // La imagen se ancla igual que la capa: a la izquierda y
                        // centrada en vertical sobre la trayectoria.
                        // La imagen mide ya la altura de línea, igual que la
                        // capa en pantalla: se dibuja a tamaño natural.
                        let alto = altoLinea
                        let ancho = CGFloat(puntos.width) / CGFloat(puntos.height) * alto
                        ctx.draw(puntos, in: CGRect(x: x,
                                                    y: size.height - centro - alto / 2,
                                                    width: ancho,
                                                    height: alto))
                    } else {
                        let baseArriba = centro - altoLinea / 2 + ascent
                        ctx.textPosition = CGPoint(x: x, y: size.height - baseArriba)
                        CTLineDraw(g.line, ctx)
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])

            adaptor.append(pixels, withPresentationTime:
                CMTime(value: CMTimeValue(frame), timescale: fps))

            if frame % 15 == 0 {
                let avance = Double(frame) / Double(total)
                await MainActor.run { progress(avance) }
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        await MainActor.run { progress(1) }

        guard writer.status == .completed else {
            throw Failure.writerFailed(writer.error?.localizedDescription
                                       ?? String(localized: "The video could not be written."))
        }
        return url
    }

    // MARK: - Auxiliares

    /// Parte el mensaje en letras, midiendo el desfase de cada una.
    ///
    /// Se recorre por secuencias de caracteres compuestas para no partir
    /// emoticonos ni acentos combinantes. Los espacios se descartan: no se
    /// dibujan, solo separan.
    private static func trocear(_ texto: NSAttributedString, linea: CTLine,
                                led: Bool, pitch: CGFloat, altoLinea: CGFloat) -> [Glyph] {
        var glyphs: [Glyph] = []
        let cadena = texto.string as NSString
        var indice = 0
        while indice < cadena.length {
            let rango = cadena.rangeOfComposedCharacterSequence(at: indice)
            indice = NSMaxRange(rango)

            let trozo = texto.attributedSubstring(from: rango)
            guard !trozo.string.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            // Los puntos se dibujan a escala 2: el vídeo sale a 1920 de ancho
            // y con escala 1 los bordes de cada punto quedan dentados.
            let puntos = led ? LEDRenderer.image(for: trozo, pitch: pitch, scale: 2,
                                                boxHeight: altoLinea) : nil
            glyphs.append(Glyph(
                line: CTLineCreateWithAttributedString(trozo),
                offset: CGFloat(CTLineGetOffsetForStringIndex(linea, rango.location, nil)),
                width: trozo.size().width,
                dots: puntos?.cgImage,
                dotsHeight: puntos?.size.height ?? 0))
        }
        return glyphs
    }

    /// Mensaje de una sola línea, igual que el que muestra ``MarqueeBanner``.
    private static func displayText(from settings: BannerSettings) -> NSAttributedString {
        let fuente = settings.attributedText
        guard fuente.length > 0 else { return BannerText.plain(" ") }

        let limpio = NSMutableAttributedString(attributedString: fuente)
        while let rango = limpio.string.range(of: "\n") {
            limpio.replaceCharacters(in: NSRange(rango, in: limpio.string), with: " ")
        }
        return limpio
    }
}
