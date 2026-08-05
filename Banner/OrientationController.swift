import SwiftUI

/// Controla la orientación admitida por la escena activa.
///
/// La pantalla de ajustes se muestra en vertical y el rótulo en apaisado. Como
/// SwiftUI no ofrece un modificador para esto, se combina el valor consultado
/// por el delegado de aplicación con `requestGeometryUpdate(_:)` para forzar la
/// rotación inmediata sin esperar a que el usuario gire el dispositivo.
enum OrientationController {

    /// Orientaciones que el delegado de aplicación declara como admitidas.
    ///
    /// En iPad arranca admitiéndolas todas. Si se declarase solo vertical —como
    /// en iPhone— y el usuario tuviera el iPad apaisado, el sistema resolvería el
    /// conflicto metiendo la app en una ventana vertical flotando sobre el
    /// escritorio, en vez de dejarla a pantalla completa.
    static var supportedOrientations: UIInterfaceOrientationMask =
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait

    /// Fija la orientación de la escena y solicita la rotación al sistema.
    /// - Parameter orientations: Máscara de orientaciones permitidas a partir de ahora.
    @MainActor
    static func lock(to orientations: UIInterfaceOrientationMask) {
        // En iPad no se fuerza nada. Pedir una orientación concreta a una escena
        // que admite varias ventanas —y esta las admite, porque las necesita para
        // la pantalla externa— no rota la pantalla: redimensiona la ventana y deja
        // el rótulo flotando sobre el escritorio, con el Dock a la vista. Para una
        // app que existe para verse de lejos, eso la inutiliza. Se deja que ocupe
        // la ventana entera y que sea el usuario quien gire el iPad.
        guard UIDevice.current.userInterfaceIdiom != .pad else {
            supportedOrientations = .all
            return
        }

        supportedOrientations = orientations

        // Se descartan las escenas de pantalla externa: la orientación solo
        // tiene sentido en la del dispositivo.
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: {
                $0.session.role == .windowApplication && $0.activationState == .foregroundActive
            })
        else { return }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
