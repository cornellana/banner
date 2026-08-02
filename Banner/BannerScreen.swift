import SwiftUI

/// Rótulo a pantalla completa en el propio dispositivo: el texto recorre la
/// pantalla en apaisado y una barra oculta permite salir o ajustar la velocidad.
struct BannerScreen: View {
    @Bindable var settings: BannerSettings

    @Environment(\.dismiss) private var dismiss

    /// Velocidad con la que está corriendo la animación en curso.
    ///
    /// Se separa de ``BannerSettings/speed`` para no relanzar el recorrido en
    /// cada valor intermedio mientras se arrastra el deslizador.
    @State private var appliedSpeed: Double?

    /// Indica que el usuario está arrastrando el deslizador de velocidad.
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
            MarqueeBanner(settings: settings, speed: appliedSpeed ?? settings.speed)
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
        .background(settings.backgroundColor)
        .overlay(alignment: .top) { controls }
        .overlay(alignment: .bottom) { hint }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            OrientationController.lock(to: .landscape)
            UIApplication.shared.isIdleTimerDisabled = true
            appliedSpeed = settings.speed
            // Los botones de volumen encienden y apagan los destellos sin
            // tener que tocar la pantalla.
            volumeButtons.onPress = { toggleFlashes() }
            volumeButtons.start()
        }
        .onChange(of: settings.speed) {
            guard !isAdjustingSpeed else { return }
            appliedSpeed = settings.speed
        }
        .onDisappear {
            OrientationController.lock(to: .portrait)
            UIApplication.shared.isIdleTimerDisabled = false
            volumeButtons.stop()
            controlsHideTask?.cancel()
        }
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

    // MARK: - Acciones

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
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { areControlsVisible = false }
        }
    }
}
