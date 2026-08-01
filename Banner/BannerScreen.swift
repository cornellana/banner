import SwiftUI

/// Rótulo a pantalla completa: el texto recorre la pantalla en apaisado, de
/// derecha a izquierda, ocupando toda la anchura y la altura configurada.
///
/// El desplazamiento se delega en una animación de Core Animation en lugar de
/// recalcular la posición en cada fotograma: así el hilo principal queda libre y
/// los controles superpuestos responden al primer toque.
struct BannerScreen: View {
    @Bindable var settings: BannerSettings

    @Environment(\.dismiss) private var dismiss

    /// Velocidad con la que está corriendo la animación en curso.
    ///
    /// Se separa de ``BannerSettings/speed`` para no relanzar el recorrido en
    /// cada valor intermedio mientras se arrastra el deslizador.
    @State private var appliedSpeed: Double?

    /// Fase encendida del destello, conmutada por ``flashLoop()``.
    @State private var isLit = false

    /// Indica que el usuario está arrastrando el deslizador de velocidad: hasta
    /// que lo suelte no se relanza la animación, para que el texto no vuelva al
    /// principio en cada valor intermedio.
    @State private var isAdjustingSpeed = false

    @State private var areControlsVisible = false
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var isHintVisible = true
    @State private var volumeButtons = VolumeButtonWatcher()

    var body: some View {
        ZStack {
            // Los gestos viven en el rótulo, no en la vista compuesta: si
            // envolvieran también a los controles, cada toque sobre ellos
            // tendría que esperar a que el gesto del fondo se descartara.
            marquee
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if abs(value.translation.height) > 60 { dismiss() }
                        }
                )
        }
        .ignoresSafeArea()
        .background(Color.black)
        .overlay(alignment: .top) { controls }
        .overlay(alignment: .bottom) { hint }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task { await flashLoop() }
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

    // MARK: - Rótulo

    /// Texto desplazándose de derecha a izquierda a pantalla completa.
    private var marquee: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fontSize = max(12, size.height * settings.heightFraction)
            let textWidth = Self.width(of: displayText, typeface: settings.typeface, fontSize: fontSize)
            let speed = appliedSpeed ?? settings.speed
            // Recorrido completo: entra por la derecha y sale del todo por la
            // izquierda antes de volver a empezar.
            let duration = Double(textWidth + size.width) / speed

            ZStack {
                (isLit ? settings.color : Color.black)

                MarqueeText(
                    text: displayText,
                    font: settings.typeface.font(size: fontSize),
                    // Sobre el destello se invierte el texto para que siga
                    // legible cuando el fondo se enciende con su color.
                    color: isLit ? .black : settings.color,
                    textWidth: textWidth,
                    canvas: size,
                    duration: duration
                )
                // Recrear la vista es la forma de reiniciar el recorrido cuando
                // cambia el texto, la tipografía, el tamaño o la velocidad.
                .id("\(displayText)|\(settings.typeface.rawValue)|\(fontSize)|\(speed)|\(size.width)")
                .clipped()
            }
            .onAppear { appliedSpeed = settings.speed }
            .onChange(of: settings.speed) {
                guard !isAdjustingSpeed else { return }
                appliedSpeed = settings.speed
            }
        }
    }

    /// Texto que recorre el ancho del rótulo con una animación cíclica.
    ///
    /// La animación se declara con `.animation(_:value:)` y `repeatForever`, de
    /// modo que la ejecuta el servidor de render y el hilo principal no
    /// interviene en cada fotograma. El estado propio de la vista permite
    /// reiniciar el recorrido recreándola con `.id(_:)`.
    private struct MarqueeText: View {
        let text: String
        let font: Font
        let color: Color
        let textWidth: CGFloat
        let canvas: CGSize
        let duration: Double

        @State private var hasScrolled = false

        var body: some View {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .offset(x: hasScrolled ? -textWidth : canvas.width)
                .frame(width: canvas.width, height: canvas.height, alignment: .leading)
                .animation(
                    .linear(duration: duration).repeatForever(autoreverses: false),
                    value: hasScrolled
                )
                .onAppear { hasScrolled = true }
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

                Slider(
                    value: $settings.speed,
                    in: BannerSettings.speedRange,
                    label: { Text("settings.speed.header") },
                    minimumValueLabel: { Image(systemName: "tortoise.fill") },
                    maximumValueLabel: { Image(systemName: "hare.fill") },
                    onEditingChanged: { isEditing in
                        isAdjustingSpeed = isEditing
                        // La nueva velocidad se aplica al soltar, para que el
                        // texto no vuelva al principio en cada valor intermedio.
                        if !isEditing { appliedSpeed = settings.speed }
                    }
                )
                .frame(maxWidth: 320)

                // Alternativa a los botones de volumen, a mano en la propia barra.
                Button {
                    toggleFlashes()
                } label: {
                    Image(systemName: settings.flashesEnabled ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("settings.flash.toggle")
            }
            .tint(.white)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            // Un fondo opaco en vez de material: el desenfoque tendría que
            // recalcularse cada vez que el texto pasa por detrás.
            .background(Color.black.opacity(0.65), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
            .padding(.top, 24)
            .transition(.opacity)
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
                .background(Color.black.opacity(0.65), in: Capsule())
                .padding(.bottom, 24)
                .transition(.opacity)
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(.easeInOut(duration: 0.6)) { isHintVisible = false }
                }
        }
    }

    // MARK: - Animación

    /// Alterna la fase del destello mientras la vista está en pantalla.
    ///
    /// Un bucle a la frecuencia elegida (como mucho unas pocas conmutaciones por
    /// segundo) evita tener que redibujar la vista en cada fotograma.
    private func flashLoop() async {
        while !Task.isCancelled {
            let halfPeriod = 0.5 / settings.flashRate
            try? await Task.sleep(for: .seconds(halfPeriod))
            guard settings.flashesEnabled else {
                if isLit { isLit = false }
                continue
            }
            isLit.toggle()
        }
    }

    // MARK: - Acciones

    /// Enciende o apaga los destellos con una respuesta háptica de confirmación,
    /// porque se acciona a ciegas desde los botones laterales.
    private func toggleFlashes() {
        settings.flashesEnabled.toggle()
        if !settings.flashesEnabled { isLit = false }
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
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { areControlsVisible = false }
        }
    }

    // MARK: - Cálculos auxiliares

    /// Anchura que ocupará el texto con la fuente indicada.
    ///
    /// Se mide con UIKit en lugar de con una `PreferenceKey` para no encadenar
    /// una nueva pasada de layout con cada cambio. La fuente de UIKit es la misma
    /// que usa `Text`, y el sistema aplica el mismo repertorio de fuentes de
    /// reserva para los emoticonos.
    private static func width(of text: String, typeface: BannerTypeface, fontSize: CGFloat) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: typeface.uiFont(size: fontSize)]).width
    }
}
