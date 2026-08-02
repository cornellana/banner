import SwiftUI
import UIKit

/// Muestra el rótulo en una pantalla externa: televisor por AirPlay, monitor
/// conectado por cable o un iPad usado como pantalla.
///
/// El sistema crea una escena aparte con el rol de pantalla externa —el mismo
/// mecanismo que usan las apps de vídeo para no limitarse a duplicar la
/// pantalla— y esta clase la puebla con el rótulo a pantalla completa. El
/// dispositivo queda libre para seguir editando el mensaje: los cambios se ven
/// al instante en la pantalla externa porque ambas escenas comparten los mismos
/// ajustes a través de ``AppEnvironment``.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let environment = AppEnvironment.shared
        let projection = ProjectionScreen(settings: environment.settings)
            .environment(\.locale, environment.settings.language.locale)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: projection)
        window.isHidden = false
        self.window = window

        environment.projection.isProjecting = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        AppEnvironment.shared.projection.isProjecting = false
    }
}

// MARK: - Contenido proyectado

/// El rótulo tal cual, sin controles: la pantalla externa no recibe toques.
private struct ProjectionScreen: View {
    let settings: BannerSettings

    var body: some View {
        MarqueeBanner(settings: settings, speed: settings.speed)
            .background(settings.backgroundColor)
            .ignoresSafeArea()
            .statusBarHidden()
    }
}
