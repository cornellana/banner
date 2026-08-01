import SwiftUI

/// Rótulo a pantalla completa: el texto recorre la pantalla en apaisado, de
/// derecha a izquierda, ocupando toda la anchura y la altura configurada.
struct BannerScreen: View {
    @Bindable var settings: BannerSettings

    @Environment(\.dismiss) private var dismiss

    /// Acumulador de desplazamiento; conserva la posición al cambiar la velocidad.
    @State private var clock = ScrollClock()
    @State private var areControlsVisible = false
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var isHintVisible = true
    @State private var volumeButtons = VolumeButtonWatcher()

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fontSize = max(12, size.height * settings.heightFraction)
            let textWidth = Self.width(of: displayText, typeface: settings.typeface, fontSize: fontSize)

            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                // Ciclo completo: el texto entra por la derecha y sale del todo
                // por la izquierda antes de reaparecer.
                let cycle = textWidth + size.width
                let travelled = clock.advance(to: time, speed: settings.speed, cycle: cycle)
                let isLit = settings.flashesEnabled
                    && Self.isFlashLit(at: time, rate: settings.flashRate)

                ZStack {
                    (isLit ? settings.color : Color.black)
                        .ignoresSafeArea()

                    Text(displayText)
                        .font(settings.typeface.font(size: fontSize))
                        // Sobre el destello se invierte el texto para que siga
                        // legible cuando el fondo se enciende con su mismo color.
                        .foregroundStyle(isLit ? Color.black : settings.color)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: size.width - travelled)
                        .frame(width: size.width, height: size.height, alignment: .leading)
                        .clipped()
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .overlay(alignment: .top) { controls }
        .overlay(alignment: .bottom) { hint }
        .contentShape(Rectangle())
        // Dos toques o un deslizamiento hacia abajo vuelven a los ajustes de
        // inmediato; un solo toque muestra la barra, que también permite salir.
        .onTapGesture(count: 2) { dismiss() }
        .onTapGesture { toggleControls() }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if abs(value.translation.height) > 60 { dismiss() }
                }
        )
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            OrientationController.lock(to: .landscape)
            UIApplication.shared.isIdleTimerDisabled = true
            // Los botones de volumen encienden y apagan los destellos sin
            // tener que tocar la pantalla.
            volumeButtons.onPress = { toggleFlashes() }
            volumeButtons.start()
        }
        .onDisappear {
            OrientationController.lock(to: .portrait)
            UIApplication.shared.isIdleTimerDisabled = false
            volumeButtons.stop()
            controlsHideTask?.cancel()
        }
    }

    /// Texto mostrado: los saltos de línea se sustituyen por espacios porque el
    /// rótulo es siempre de una sola línea.
    private var displayText: String {
        let cleaned = settings.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? " " : cleaned + "   "
    }

    // MARK: - Controles superpuestos

    @ViewBuilder
    private var controls: some View {
        if areControlsVisible {
            HStack(spacing: 20) {
                Button {
                    dismiss()
                } label: {
                    Label("banner.settings", systemImage: "slider.horizontal.3")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))

                Slider(value: $settings.speed, in: BannerSettings.speedRange) {
                    Text("settings.speed.header")
                } minimumValueLabel: {
                    Image(systemName: "tortoise.fill")
                } maximumValueLabel: {
                    Image(systemName: "hare.fill")
                }
                .frame(maxWidth: 320)

                // Alternativa a los botones de volumen para iOS anteriores a 17.2.
                Button {
                    toggleFlashes()
                } label: {
                    Image(systemName: settings.flashesEnabled ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title2)
                }
                .accessibilityLabel("settings.flash.toggle")
            }
            .tint(.white)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Aviso inicial con las formas de volver a los ajustes; se desvanece solo.
    @ViewBuilder
    private var hint: some View {
        if isHintVisible {
            Text("banner.hint")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 16)
                .transition(.opacity)
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(.easeInOut(duration: 0.6)) { isHintVisible = false }
                }
        }
    }

    /// Enciende o apaga los destellos con una respuesta háptica de confirmación,
    /// porque se acciona a ciegas desde los botones laterales.
    private func toggleFlashes() {
        settings.flashesEnabled.toggle()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Muestra u oculta la barra de controles y programa su ocultación automática.
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            areControlsVisible.toggle()
        }
        controlsHideTask?.cancel()
        guard areControlsVisible else { return }
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { areControlsVisible = false }
        }
    }

    // MARK: - Cálculos auxiliares

    /// Anchura que ocupará el texto con la fuente indicada.
    ///
    /// Se mide con UIKit en lugar de con una `PreferenceKey` para evitar un ciclo
    /// de invalidación de layout dentro de la animación, que se reevalúa en cada
    /// fotograma. La fuente de UIKit es la misma que usa `Text`, y el sistema
    /// aplica el mismo repertorio de fuentes de reserva para los emoticonos.
    private static func width(of text: String, typeface: BannerTypeface, fontSize: CGFloat) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: typeface.uiFont(size: fontSize)]).width
    }

    /// Indica si el destello está encendido en el instante dado (ciclo simétrico).
    private static func isFlashLit(at time: TimeInterval, rate: Double) -> Bool {
        (time * rate).truncatingRemainder(dividingBy: 1) < 0.5
    }
}

// MARK: - Reloj de desplazamiento

/// Acumula la distancia recorrida por el texto a partir del tiempo transcurrido.
///
/// Integrar la velocidad fotograma a fotograma (en lugar de calcular
/// `tiempo × velocidad`) evita que el rótulo pegue un salto cuando el usuario
/// mueve el deslizador de velocidad mientras el texto está en pantalla.
@MainActor
final class ScrollClock {
    private var lastTime: TimeInterval?
    private var distance: Double = 0

    /// Avanza el desplazamiento hasta el instante indicado.
    /// - Parameters:
    ///   - time: Marca de tiempo del fotograma actual.
    ///   - speed: Velocidad en puntos por segundo.
    ///   - cycle: Longitud del ciclo completo en puntos.
    /// - Returns: Distancia recorrida dentro del ciclo actual.
    func advance(to time: TimeInterval, speed: Double, cycle: Double) -> Double {
        defer { lastTime = time }
        guard let lastTime else { return distance }

        // Se acota el delta para que volver de segundo plano no provoque un salto.
        let delta = min(max(time - lastTime, 0), 0.1)
        distance += delta * speed
        if cycle > 0 {
            distance = distance.truncatingRemainder(dividingBy: cycle)
        }
        return distance
    }
}
