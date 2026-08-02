import Foundation

/// Colección de mensajes guardados, persistida en disco.
///
/// Se escribe un único JSON en el directorio de soporte de la app: son pocos
/// registros y muy pequeños, así que reescribir el archivo entero en cada
/// cambio resulta más simple que mantener una base de datos.
@Observable
final class PresetStore {

    /// Mensajes guardados, del más reciente al más antiguo.
    private(set) var presets: [BannerPreset] = []

    private let fileURL: URL

    /// Crea la colección y carga lo que hubiera guardado.
    /// - Parameter fileURL: Ubicación del archivo; por omisión, dentro del
    ///   directorio de soporte de la app.
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    // MARK: - Operaciones

    /// Guarda una instantánea de los ajustes actuales al principio de la lista.
    /// - Parameter settings: Ajustes que se quieren conservar.
    func save(from settings: BannerSettings) {
        presets.insert(BannerPreset(settings: settings), at: 0)
        persist()
    }

    /// Elimina el mensaje indicado.
    /// - Parameter preset: Mensaje a borrar.
    func delete(_ preset: BannerPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    // MARK: - Persistencia

    private static func defaultFileURL() -> URL {
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "presets.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        presets = (try? JSONDecoder().decode([BannerPreset].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
