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

    /// Contador que dispara la respuesta háptica al guardar.
    @State private var saveCount = 0

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    projectionBanner
                    textSection
                    typefaceSection
                    colorSection
                    backgroundSection
                    speedSection
                    sizeSection
                    flashSection
                    languageSection
                    showButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isTextFieldFocused = false
                        store.save(from: settings)
                        saveCount += 1
                    } label: {
                        Label("presets.save", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isTextFieldFocused = false
                        isShowingLibrary = true
                    } label: {
                        Label("presets.title", systemImage: "rectangle.stack")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { isTextFieldFocused = false }
                }
            }
            .sensoryFeedback(.success, trigger: saveCount)
            .scrollDismissesKeyboard(.interactively)
        }
        .fullScreenCover(isPresented: $isShowingBanner) {
            BannerScreen(settings: settings)
                // El rótulo se presenta en su propia escena: el idioma elegido
                // se le inyecta de nuevo para no depender de la herencia.
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
            TextField("settings.text.placeholder", text: $settings.text, axis: .vertical)
                .lineLimit(1...3)
                .focused($isTextFieldFocused)
                .font(.title3)
                .textFieldStyle(.plain)
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

                // Muestra el aspecto real del rótulo con el tipo y el color elegidos.
                Text(settings.text.isEmpty ? " " : settings.text)
                    .font(settings.typeface.font(size: 34))
                    .foregroundStyle(settings.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(settings.backgroundColor, in: RoundedRectangle(cornerRadius: 12))
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

    private var speedSection: some View {
        SettingsCard(title: "settings.speed.header") {
            IconSlider(
                value: $settings.speed,
                range: BannerSettings.speedRange,
                minimumIcon: "tortoise.fill",
                maximumIcon: "hare.fill",
                accessibilityLabel: "settings.speed.header",
                tint: settings.color
            )
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
            isTextFieldFocused = false
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
