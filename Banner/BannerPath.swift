import CoreGraphics
import Foundation

/// Trayectoria vertical que siguen las letras mientras recorren la pantalla.
///
/// Se guarda normalizada —`x` e `y` en 0...1— para que el mismo trazo valga en
/// cualquier pantalla: la `x` recorre el ancho y la `y` va de arriba (0) abajo
/// (1). Fuera del intervalo el dibujo se repite, de modo que un diente de
/// sierra encadena sin saltos.
struct BannerPath: Codable, Hashable, Sendable {

    /// Puntos del trazo, ordenados por `x`.
    private(set) var points: [CGPoint]

    /// Trayectoria plana: el texto no sube ni baja.
    static let straight = BannerPath(points: [])

    /// Indica que no hay trazo y el recorrido es horizontal.
    var isStraight: Bool { points.count < 2 }

    /// Crea la trayectoria ordenando y limpiando los puntos recibidos.
    /// - Parameter points: Puntos normalizados, en cualquier orden.
    init(points: [CGPoint]) {
        // Se ordena por `x` y se descartan los puntos demasiado juntos: al
        // dibujar con el dedo llegan cientos y basta con el perfil.
        let sorted = points
            .map { CGPoint(x: min(max($0.x, 0), 1), y: min(max($0.y, 0), 1)) }
            .sorted { $0.x < $1.x }

        var cleaned: [CGPoint] = []
        for point in sorted where cleaned.last.map({ point.x - $0.x > 0.004 }) ?? true {
            cleaned.append(point)
        }
        self.points = cleaned.count >= 2 ? cleaned : []
    }

    /// Altura normalizada de la trayectoria en una posición horizontal.
    ///
    /// - Parameter x: Posición normalizada; puede salirse de 0...1, en cuyo caso
    ///   el trazo se repite.
    /// - Returns: Altura entre 0 (arriba) y 1 (abajo); 0,5 si no hay trazo.
    func normalizedY(at x: Double) -> Double {
        guard !isStraight else { return 0.5 }

        // Repetición periódica del trazo a lo largo del recorrido.
        let wrapped = x - floor(x)

        guard let first = points.first, let last = points.last else { return 0.5 }
        if wrapped <= first.x { return Double(first.y) }
        if wrapped >= last.x { return Double(last.y) }

        // Búsqueda del tramo que contiene la posición e interpolación lineal.
        var lower = points[0]
        for point in points.dropFirst() {
            if point.x >= wrapped {
                let span = Double(point.x - lower.x)
                guard span > 0 else { return Double(point.y) }
                let ratio = (wrapped - Double(lower.x)) / span
                return Double(lower.y) + ratio * Double(point.y - lower.y)
            }
            lower = point
        }
        return Double(last.y)
    }

    // MARK: - Trazos predefinidos

    /// Onda suave de dos ciclos.
    static var wave: BannerPath {
        BannerPath(points: (0...48).map { step in
            let x = Double(step) / 48
            return CGPoint(x: x, y: 0.5 - 0.42 * sin(x * 4 * .pi))
        })
    }

    /// Diente de sierra de tres dientes.
    static var sawtooth: BannerPath {
        BannerPath(points: (0...48).map { step in
            let x = Double(step) / 48
            let phase = (x * 3).truncatingRemainder(dividingBy: 1)
            return CGPoint(x: x, y: 0.92 - 0.84 * phase)
        })
    }
}
