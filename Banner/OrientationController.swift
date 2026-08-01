import SwiftUI

/// Controla la orientación admitida por la escena activa.
///
/// La pantalla de ajustes se muestra en vertical y el rótulo en apaisado. Como
/// SwiftUI no ofrece un modificador para esto, se combina el valor consultado
/// por el delegado de aplicación con `requestGeometryUpdate(_:)` para forzar la
/// rotación inmediata sin esperar a que el usuario gire el dispositivo.
enum OrientationController {

    /// Orientaciones que el delegado de aplicación declara como admitidas.
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    /// Fija la orientación de la escena y solicita la rotación al sistema.
    /// - Parameter orientations: Máscara de orientaciones permitidas a partir de ahora.
    @MainActor
    static func lock(to orientations: UIInterfaceOrientationMask) {
        supportedOrientations = orientations

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        // El error se ignora deliberadamente: en iPad con multitarea el sistema
        // puede rechazar la petición, y en ese caso basta con que la vista se
        // adapte al tamaño disponible.
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
