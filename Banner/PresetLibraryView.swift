import SwiftUI

/// Biblioteca de mensajes guardados: una cuadrícula de vistas previas donde
/// cada una reproduce el aspecto real del rótulo. Al tocar una, sus ajustes
/// pasan a ser los vigentes.
struct PresetLibraryView: View {
    let store: PresetStore

    /// Acción que aplica el mensaje elegido y cierra la biblioteca.
    let onSelect: (BannerPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Cuadrícula adaptable: una columna en iPhone vertical, varias en iPad.
    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if store.presets.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("presets.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Contenido

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.presets) { preset in
                    Button {
                        onSelect(preset)
                        dismiss()
                    } label: {
                        PresetCard(preset: preset)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.delete(preset)
                        } label: {
                            Label("presets.delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("presets.empty.title", systemImage: "rectangle.stack")
        } description: {
            Text("presets.empty.description")
        }
    }
}

// MARK: - Tarjeta de vista previa

/// Reproduce en pequeño el aspecto del rótulo guardado.
private struct PresetCard: View {
    let preset: BannerPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AttributedLabel(
                attributedText: BannerText.styled(
                    preset.attributedText,
                    typeface: preset.typeface,
                    fontSize: 28,
                    baseColor: UIColor(preset.color)
                ),
                scalesToFit: true
            )
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Proporción apaisada, como la pantalla donde se verá.
            .frame(height: 96)
            .background(preset.backgroundColor, in: RoundedRectangle(cornerRadius: 14))
            .clipped()

            HStack(spacing: 6) {
                preset.typeface.label
                Text(verbatim: "·")
                Text(preset.savedAt, format: .dateTime.day().month().hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    PresetLibraryView(store: PresetStore()) { _ in }
}
