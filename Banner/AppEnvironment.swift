import SwiftUI

/// Estado compartido por todas las escenas de la app.
///
/// La escena principal la crea SwiftUI y la de la pantalla externa la crea
/// UIKit a través de ``ExternalDisplaySceneDelegate``; ninguna puede pasarle
/// valores a la otra por inicializador, así que ambas leen de esta instancia
/// única. Es la excepción justificada a la inyección por inicializador.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    /// Ajustes del rótulo, compartidos entre el iPhone y la pantalla externa.
    let settings = BannerSettings()

    /// Mensajes guardados.
    let store = PresetStore()

    /// Estado de la proyección en una pantalla externa (televisor, monitor o
    /// duplicado por AirPlay).
    let projection = ProjectionState()

    private init() {}
}

/// Indica si hay una pantalla externa mostrando el rótulo.
@Observable
@MainActor
final class ProjectionState {
    /// `true` mientras una escena de pantalla externa esté conectada.
    var isProjecting = false
}
