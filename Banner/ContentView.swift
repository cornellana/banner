import SwiftUI

/// Pantalla de configuración: texto, tipografía, color, velocidad, tamaño y
/// destellos.
///
/// El contenido se compone con un `ScrollView` y tarjetas propias en lugar de un
/// `Form`: la lista del sistema duplica en iOS 26 la fila recortada por el borde
/// inferior sobre el título de la barra de navegación.
struct ContentView: View {
    @Bindable var settings: BannerSettings

    /// Mensajes guardados por el usuario.
    let store: PresetStore

    /// Estado de la proyección en una pantalla externa.
    let projection: ProjectionState

    @State private var isShowingBanner = false
    @State private var isShowingLibrary = false
    @State private var isShowingPathEditor = false

    /// Contador que dispara la respuesta háptica al guardar.
    @State private var saveCount = 0

    // MARK: Exportación a vídeo
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedVideo: ExportedVideo?
    @State private var exportError: String?

    /// Mando del editor de texto con atributos.
    @State private var richText = RichTextController()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    projectionBanner
                    textSection
                    typefaceSection
                    colorSection
                    backgroundSection
                    pathSection
                    speedSection
                    sizeSection
                    flashSection
                    languageSection
                    showButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                // Ancho máximo y centrado. A pantalla completa en un iPad de 13"
                // los deslizadores medirían casi mil puntos: con un recorrido así
                // un centímetro de dedo se salta medio arcoíris y ajustar un color
                // se vuelve imposible. En iPhone el límite no llega a aplicarse.
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        richText.endEditing()
                        store.save(from: settings)
                        saveCount += 1
                    } label: {
                        Label("presets.save", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        richText.endEditing()
                        isShowingLibrary = true
                    } label: {
                        Label("presets.title", systemImage: "rectangle.stack")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        richText.endEditing()
                        exportVideo()
                    } label: {
                        Label("export.video", systemImage: "film")
                    }
                    .disabled(isExporting)
                }
            }
            .overlay {
                if isExporting {
                    ZStack {
                        Color.black.opacity(0.55).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView(value: exportProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 220)
                            Text("export.progress")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .sheet(item: $exportedVideo) { video in
                ShareSheet(items: [video.url])
            }
            .alert("export.failed", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .sensoryFeedback(.success, trigger: saveCount)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // El editor vive en UIKit: los cambios de formato vuelven al
                // modelo por esta vía, no por el enlace del texto.
                richText.onChange = { settings.attributedText = $0 }
            }
        }
        .fullScreenCover(isPresented: $isShowingBanner) {
            BannerScreen(settings: settings)
                // El rótulo se presenta en su propia escena: el idioma elegido
                // se le inyecta de nuevo para no depender de la herencia.
                .environment(\.locale, settings.language.locale)
        }
        .sheet(isPresented: $isShowingPathEditor) {
            PathEditorView(initialPath: settings.path) { drawn in
                settings.path = drawn
            }
            .environment(\.locale, settings.language.locale)
        }
        .sheet(isPresented: $isShowingLibrary) {
            PresetLibraryView(store: store) { preset in
                settings.apply(preset)
            }
            .environment(\.locale, settings.language.locale)
        }
    }

    // MARK: - Secciones

    /// Aviso de que el rótulo se está viendo en una pantalla externa; los
    /// cambios que se hagan aquí se reflejan allí al momento.
    @ViewBuilder
    private var projectionBanner: some View {
        if projection.isProjecting {
            Label("projection.active", systemImage: "tv.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(settings.color.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var textSection: some View {
        SettingsCard(title: "settings.text.header", footer: "settings.text.footer") {
            RichTextEditor(text: $settings.attributedText, controller: richText)
                .frame(minHeight: 30)
        }
    }

    private var typefaceSection: some View {
        SettingsCard(title: "settings.typeface.header") {
            VStack(spacing: 16) {
                Picker(selection: $settings.typeface) {
                    ForEach(BannerTypeface.allCases) { typeface in
                        typeface.label
                            .font(typeface.font(size: 20))
                            .tag(typeface)
                    }
                } label: {
                    Text("settings.typeface.header")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                // Muestra el aspecto real del rótulo: tipografía, colores y los
                // atributos que lleve cada tramo del mensaje. Con los LEDs
                // encendidos se dibuja igual que el rótulo, en puntos: si no,
                // el interruptor no tendría efecto visible hasta lanzarlo.
                previewLabel
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(settings.backgroundColor, in: RoundedRectangle(cornerRadius: 12))
                .clipped()

                Toggle(isOn: $settings.ledEnabled) {
                    Label("settings.led", systemImage: "circle.grid.3x3.fill")
                }
                .tint(settings.color)
            }
        }
    }

    private var colorSection: some View {
        SettingsCard(title: "settings.color.header") {
            VStack(spacing: 18) {
                GradientSlider(
                    title: "settings.color.hue",
                    value: $settings.hue,
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
                        Color(hue: $0, saturation: settings.saturation, brightness: settings.brightness)
                    }
                )
                GradientSlider(
                    title: "settings.color.saturation",
                    value: $settings.saturation,
                    colors: [
                        Color(hue: settings.hue, saturation: 0, brightness: settings.brightness),
                        Color(hue: settings.hue, saturation: 1, brightness: settings.brightness)
                    ]
                )
                GradientSlider(
                    title: "settings.color.brightness",
                    value: $settings.brightness,
                    colors: [
                        Color(hue: settings.hue, saturation: settings.saturation, brightness: 0),
                        Color(hue: settings.hue, saturation: settings.saturation, brightness: 1)
                    ]
                )
            }
        }
    }

    /// Brillo con el que se dibujan las barras de tono y saturación del fondo.
    ///
    /// Se mantiene un mínimo visible aunque el fondo elegido sea negro: si no,
    /// las barras serían dos rectángulos oscuros sin información de color.
    private var previewBrightness: Double {
        max(settings.backgroundBrightness, 0.55)
    }

    private var backgroundSection: some View {
        SettingsCard(title: "settings.background.header", footer: "settings.background.footer") {
            VStack(spacing: 18) {
                GradientSlider(
                    title: "settings.color.brightness",
                    value: $settings.backgroundBrightness,
                    colors: [
                        Color(hue: settings.backgroundHue, saturation: settings.backgroundSaturation, brightness: 0),
                        Color(hue: settings.backgroundHue, saturation: settings.backgroundSaturation, brightness: 1)
                    ]
                )
                GradientSlider(
                    title: "settings.color.hue",
                    value: $settings.backgroundHue,
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
                        Color(
                            hue: $0,
                            saturation: settings.backgroundSaturation,
                            brightness: previewBrightness
                        )
                    }
                )
                GradientSlider(
                    title: "settings.color.saturation",
                    value: $settings.backgroundSaturation,
                    colors: [
                        Color(hue: settings.backgroundHue, saturation: 0, brightness: previewBrightness),
                        Color(hue: settings.backgroundHue, saturation: 1, brightness: previewBrightness)
                    ]
                )
            }
        }
    }

    private var pathSection: some View {
        SettingsCard(title: "path.title", footer: "path.footer") {
            VStack(spacing: 12) {
                PathPreview(path: settings.path, tint: settings.color)
                    .frame(height: 72)
                    .frame(maxWidth: .infinity)
                    .background(settings.backgroundColor, in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    Button {
                        richText.endEditing()
                        isShowingPathEditor = true
                    } label: {
                        Label("path.draw", systemImage: "scribble.variable")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if !settings.path.isStraight {
                        Button("path.preset.straight") { settings.path = .straight }
                            .buttonStyle(.bordered)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var speedSection: some View {
        SettingsCard(title: "settings.speed.header", footer: "settings.speed.video.footer") {
            VStack(spacing: 18) {
                IconSlider(
                    value: $settings.speed,
                    range: BannerSettings.speedRange,
                    minimumIcon: "tortoise.fill",
                    maximumIcon: "hare.fill",
                    accessibilityLabel: "settings.speed.header",
                    tint: settings.color
                )

                // El vídeo se comparte y el rótulo se contempla: con la misma
                // velocidad, un mensaje corto daba vídeos de casi un minuto.
                Picker(selection: $settings.videoSpeedFactor) {
                    ForEach(BannerSettings.videoSpeedFactors, id: \.self) { factor in
                        Text(verbatim: "×\(Int(factor))").tag(factor)
                    }
                } label: {
                    Label("settings.speed.video", systemImage: "film")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var sizeSection: some View {
        SettingsCard(title: "settings.size.header", footer: "settings.size.footer") {
            IconSlider(
                value: $settings.heightFraction,
                range: BannerSettings.heightRange,
                minimumIcon: "textformat.size.smaller",
                maximumIcon: "textformat.size.larger",
                accessibilityLabel: "settings.size.header",
                tint: settings.color
            )
        }
    }

    private var flashSection: some View {
        SettingsCard(title: "settings.flash.header", footer: "settings.flash.footer") {
            IconSlider(
                value: $settings.flashRate,
                range: BannerSettings.flashRateRange,
                minimumIcon: "light.min",
                maximumIcon: "light.max",
                accessibilityLabel: "settings.flash.rate",
                tint: settings.color
            )
        }
    }

    private var languageSection: some View {
        SettingsCard(title: "settings.language.header") {
            Picker(selection: $settings.language) {
                ForEach(AppLanguage.allCases) { language in
                    language.label.tag(language)
                }
            } label: {
                Text("settings.language.header")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var showButton: some View {
        Button {
            richText.endEditing()
            isShowingBanner = true
        } label: {
            Label("settings.show", systemImage: "play.rectangle.fill")
                // Sin esto el símbolo conserva su variante multicolor y el
                // triángulo sale azul sobre el fondo del botón.
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(settings.color)
    }

    /// Cuerpo usado en la vista previa de los ajustes.
    private static let previewFontSize: CGFloat = 34

    /// Mensaje con el aspecto que tendrá en el rótulo.
    private var previewText: NSAttributedString {
        BannerText.styled(
            settings.plainText.isEmpty ? BannerText.plain(" ") : settings.attributedText,
            typeface: settings.typeface,
            fontSize: Self.previewFontSize,
            baseColor: UIColor(settings.color),
            lightweight: settings.ledEnabled
        )
    }

    /// Vista previa del mensaje, en texto o en puntos de LED.
    @ViewBuilder
    private var previewLabel: some View {
        if settings.ledEnabled,
           let puntos = LEDRenderer.image(
               for: previewText,
               pitch: LEDRenderer.pitch(forFontSize: Self.previewFontSize),
               scale: 3) {
            Image(uiImage: puntos)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 44)
        } else {
            AttributedLabel(attributedText: previewText, scalesToFit: true)
        }
    }

    // MARK: - Exportación

    /// Lanza la exportación del rótulo a vídeo.
    ///
    /// El tamaño es 1920×1080 fijo: el rótulo es apaisado y esa resolución es la
    /// que mejor se comporta al compartirlo por mensajería o redes sociales.
    private func exportVideo() {
        isExporting = true
        exportProgress = 0
        Task {
            do {
                let url = try await BannerVideoExporter.export(settings: settings) { avance in
                    exportProgress = avance
                }
                isExporting = false
                exportedVideo = ExportedVideo(url: url)
            } catch {
                isExporting = false
                exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - Tarjeta de ajustes

/// Bloque con título, contenido sobre fondo agrupado y pie opcional.
private struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Vista previa de la trayectoria

/// Dibuja el trazo de la trayectoria a escala reducida.
private struct PathPreview: View {
    let path: BannerPath
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            Path { shape in
                let steps = 120
                for step in 0...steps {
                    let x = Double(step) / Double(steps)
                    let point = CGPoint(
                        x: x * proxy.size.width,
                        y: path.normalizedY(at: x) * proxy.size.height
                    )
                    if step == 0 {
                        shape.move(to: point)
                    } else {
                        shape.addLine(to: point)
                    }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Deslizadores

/// Deslizador flanqueado por dos símbolos que indican los extremos del rango.
private struct IconSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let minimumIcon: String
    let maximumIcon: String
    let accessibilityLabel: LocalizedStringKey
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: minimumIcon)
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range)
                .tint(tint)
                .accessibilityLabel(accessibilityLabel)
            Image(systemName: maximumIcon)
                .foregroundStyle(.secondary)
        }
    }
}

/// Deslizador con una barra de degradado que previsualiza el rango de colores.
private struct GradientSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Capsule()
                .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .frame(height: 10)
                .overlay(Capsule().strokeBorder(.quaternary))

            Slider(value: $value, in: 0...1)
                .tint(.primary.opacity(0.6))
                .accessibilityLabel(title)
        }
    }
}

#Preview {
    ContentView(settings: BannerSettings(), store: PresetStore(), projection: ProjectionState())

}

/// Vídeo listo para compartir. Envuelto en un tipo identificable porque
/// `sheet(item:)` lo exige y `URL` no lo es.
private struct ExportedVideo: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Hoja de compartir del sistema.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
