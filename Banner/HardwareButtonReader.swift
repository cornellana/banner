import AVKit
import SwiftUI

/// Captura las pulsaciones de los botones físicos de captura del iPhone
/// (subir y bajar volumen y, en los modelos que lo tienen, el botón de cámara)
/// mientras el rótulo está en pantalla.
///
/// Se usa `AVCaptureEventInteraction`, la única API pública que entrega estos
/// eventos a la app: mientras está activa, los botones dejan de modificar el
/// volumen del sistema. Requiere iOS 17.2; en versiones anteriores la vista no
/// hace nada y el usuario dispone del control equivalente en la barra oculta
/// que aparece al tocar la pantalla.
struct HardwareButtonReader: UIViewRepresentable {

    /// Acción ejecutada al soltar cualquiera de los botones.
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear

        if #available(iOS 17.2, *) {
            let coordinator = context.coordinator
            let interaction = AVCaptureEventInteraction { event in
                // Solo interesa el final de la pulsación, para no conmutar dos
                // veces por cada toque (fases `began` y `ended`).
                guard event.phase == .ended else { return }
                coordinator.trigger()
            }
            interaction.isEnabled = true
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
    }

    /// Conserva la acción más reciente para que el manejador registrado en
    /// `makeUIView` no capture una versión obsoleta de la vista.
    @MainActor
    final class Coordinator {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        nonisolated func trigger() {
            Task { @MainActor in action() }
        }
    }
}
