import AVFoundation
import MediaPlayer
import UIKit

/// Detecta las pulsaciones de los botones de volumen del dispositivo.
///
/// iOS no expone estos botones como eventos: la única vía disponible para una
/// app que no captura vídeo es observar el volumen de salida de la sesión de
/// audio y deducir que el usuario ha pulsado cuando cambia. Para que el gesto se
/// pueda repetir indefinidamente, el volumen se recentra cuando llega a los
/// extremos, y se mantiene en la jerarquía un `MPVolumeView` fuera de pantalla
/// que evita que aparezca el indicador de volumen del sistema sobre el rótulo.
@MainActor
final class VolumeButtonWatcher {

    /// Acción que se ejecuta en cada pulsación de subir o bajar volumen.
    var onPress: (() -> Void)?

    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private let volumeView = MPVolumeView(
        frame: CGRect(x: -3000, y: -3000, width: 1, height: 1)
    )

    /// Instante hasta el que se ignoran los cambios de volumen, para no contar
    /// como pulsación el recentrado que hace la propia clase.
    private var ignoreChangesUntil = Date.distantPast

    /// Empieza a vigilar los botones.
    func start() {
        installVolumeView()

        // `.ambient` se mezcla con lo que ya esté sonando: activar la sesión no
        // interrumpe la música del usuario.
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)

        recenterIfNeeded(session.outputVolume)

        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let volume = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.handleVolumeChange(volume)
            }
        }
    }

    /// Deja de vigilar y libera la sesión de audio.
    func stop() {
        observation = nil
        volumeView.removeFromSuperview()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Detalles

    private func handleVolumeChange(_ volume: Float) {
        guard Date() >= ignoreChangesUntil else { return }
        onPress?()
        recenterIfNeeded(volume)
    }

    /// Devuelve el volumen al centro si ha topado con un extremo; en el máximo o
    /// el mínimo el sistema ya no notifica más cambios y el botón dejaría de
    /// responder.
    private func recenterIfNeeded(_ volume: Float) {
        guard volume >= 0.95 || volume <= 0.05 else { return }
        ignoreChangesUntil = Date().addingTimeInterval(0.4)
        // El ajuste se aplica en el siguiente ciclo: MPVolumeView ignora los
        // cambios hechos mientras el sistema procesa la pulsación del botón, y
        // su deslizador interno tampoco existe hasta que la vista se dispone.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let slider = self?.volumeView.subviews
                .compactMap({ $0 as? UISlider }).first
            else { return }
            slider.value = 0.5
        }
    }

    /// Inserta el `MPVolumeView` fuera de la pantalla visible; debe estar en la
    /// jerarquía y ser visible para que el sistema oculte su propio indicador.
    private func installVolumeView() {
        guard volumeView.superview == nil else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        window?.addSubview(volumeView)
    }
}
