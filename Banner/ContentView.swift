import SwiftUI

/// Pantalla de configuración: texto, color, velocidad, tamaño y destellos.
struct ContentView: View {
    @Bindable var settings: BannerSettings

    @State private var isShowingBanner = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                textSection
                typefaceSection
                colorSection
                speedSection
                sizeSection
                flashSection
                showSection
            }
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { isTextFieldFocused = false }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fullScreenCover(isPresented: $isShowingBanner) {
            BannerScreen(settings: settings)
        }
    }

    // MARK: - Secciones

    private var textSection: some View {
        Section {
            TextField("settings.text.placeholder", text: $settings.text, axis: .vertical)
                .lineLimit(1...3)
                .focused($isTextFieldFocused)
                .font(.title3)
        } header: {
            Text("settings.text.header")
        } footer: {
            Text("settings.text.footer")
        }
    }

    private var typefaceSection: some View {
        Section {
            Picker(selection: $settings.typeface) {
                ForEach(BannerTypeface.allCases) { typeface in
                    Text(typeface.displayName)
                        .font(typeface.font(size: 20))
                        .tag(typeface)
                }
            } label: {
                Text("settings.typeface.header")
            }
            .pickerStyle(.navigationLink)

            // Muestra el aspecto real del rótulo con el tipo y el color elegidos.
            Text(settings.text.isEmpty ? " " : settings.text)
                .font(settings.typeface.font(size: 34))
                .foregroundStyle(settings.color)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .listRowBackground(Color.black)
        } header: {
            Text("settings.typeface.header")
        }
    }

    private var colorSection: some View {
        Section("settings.color.header") {
            LabeledSlider(
                title: "settings.color.hue",
                value: $settings.hue,
                range: 0...1,
                track: LinearGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
                        Color(hue: $0, saturation: settings.saturation, brightness: settings.brightness)
                    },
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            LabeledSlider(
                title: "settings.color.saturation",
                value: $settings.saturation,
                range: 0...1,
                track: LinearGradient(
                    colors: [
                        Color(hue: settings.hue, saturation: 0, brightness: settings.brightness),
                        Color(hue: settings.hue, saturation: 1, brightness: settings.brightness)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            LabeledSlider(
                title: "settings.color.brightness",
                value: $settings.brightness,
                range: 0...1,
                track: LinearGradient(
                    colors: [
                        Color(hue: settings.hue, saturation: settings.saturation, brightness: 0),
                        Color(hue: settings.hue, saturation: settings.saturation, brightness: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var speedSection: some View {
        Section {
            Slider(
                value: $settings.speed,
                in: BannerSettings.speedRange
            ) {
                Text("settings.speed.header")
            } minimumValueLabel: {
                Image(systemName: "tortoise.fill")
            } maximumValueLabel: {
                Image(systemName: "hare.fill")
            }
            .tint(settings.color)
        } header: {
            Text("settings.speed.header")
        }
    }

    private var sizeSection: some View {
        Section {
            Slider(
                value: $settings.heightFraction,
                in: BannerSettings.heightRange
            ) {
                Text("settings.size.header")
            } minimumValueLabel: {
                Image(systemName: "textformat.size.smaller")
            } maximumValueLabel: {
                Image(systemName: "textformat.size.larger")
            }
            .tint(settings.color)
        } header: {
            Text("settings.size.header")
        } footer: {
            Text("settings.size.footer")
        }
    }

    private var flashSection: some View {
        Section {
            Slider(
                value: $settings.flashRate,
                in: BannerSettings.flashRateRange
            ) {
                Text("settings.flash.rate")
            } minimumValueLabel: {
                Image(systemName: "light.min")
            } maximumValueLabel: {
                Image(systemName: "light.max")
            }
            .tint(settings.color)
        } header: {
            Text("settings.flash.header")
        } footer: {
            Text("settings.flash.footer")
        }
    }

    private var showSection: some View {
        Section {
            Button {
                isTextFieldFocused = false
                isShowingBanner = true
            } label: {
                Label("settings.show", systemImage: "play.rectangle.fill")
                    // Sin esto el símbolo se dibuja en multicolor y el triángulo
                    // sale azul sobre el fondo del botón.
                    .symbolRenderingMode(.monochrome)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.color)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

// MARK: - Deslizador con muestra de color

/// Deslizador acompañado de una barra que previsualiza el rango de valores.
private struct LabeledSlider<Track: ShapeStyle>: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Capsule()
                .fill(track)
                .frame(height: 10)
                .overlay(Capsule().strokeBorder(.quaternary))

            Slider(value: $value, in: range)
                .tint(.primary.opacity(0.6))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView(settings: BannerSettings())
}
