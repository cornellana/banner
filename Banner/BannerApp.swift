import SwiftUI

/// Punto de entrada de la aplicación.
///
/// Se usa un `UIApplicationDelegateAdaptor` únicamente para poder responder a
/// `supportedInterfaceOrientationsFor:` — SwiftUI no expone todavía ninguna API
/// declarativa para restringir la orientación de una escena.
@main
struct BannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Estado compartido con la escena de la pantalla externa.
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ContentView(
                settings: environment.settings,
                store: environment.store,
                projection: environment.projection
            )
            // El idioma elegido en la propia app se aplica inyectando su
            // configuración regional: los textos se resuelven contra ella.
            .environment(\.locale, environment.settings.language.locale)
        }
    }
}

// MARK: - Delegado de aplicación

/// Delegado mínimo cuyo único cometido es delegar la orientación permitida en
/// ``OrientationController``.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationController.supportedOrientations
    }
}
