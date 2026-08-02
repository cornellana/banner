import SwiftUI

/// Lienzo donde se dibuja con el dedo la trayectoria del rótulo, al estilo del
/// recuadro de las firmas.
struct PathEditorView: View {

    /// Trayectoria de partida; al aceptar se devuelve la que quede dibujada.
    let initialPath: BannerPath
    let onSave: (BannerPath) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Trazo en curso, ya en coordenadas normalizadas.
    ///
    /// Se normaliza en el propio gesto, con el tamaño que da el `GeometryReader`
    /// en ese momento, en vez de guardarlo aparte: el tamaño no está disponible
    /// hasta la primera disposición y hacerlo así evita depender de cuándo llega.
    @State private var drawnPoints: [CGPoint] = []

    /// Trayectoria mostrada: la dibujada o, mientras no se toque, la de partida.
    @State private var path: BannerPath

    init(initialPath: BannerPath, onSave: @escaping (BannerPath) -> Void) {
        self.initialPath = initialPath
        self.onSave = onSave
        _path = State(initialValue: initialPath)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("path.instructions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                canvas

                HStack(spacing: 12) {
                    Button("path.preset.wave") { use(.wave) }
                    Button("path.preset.sawtooth") { use(.sawtooth) }
                    Button("path.preset.straight") { use(.straight) }
                }
                .buttonStyle(.bordered)
                .font(.subheadline)

                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("path.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("path.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("path.use") {
                        onSave(path)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Lienzo

    private var canvas: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))

                // Línea de referencia del centro de la pantalla.
                Path { line in
                    line.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    line.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                stroke(in: proxy.size)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard proxy.size.width > 0, proxy.size.height > 0 else { return }
                        drawnPoints.append(
                            CGPoint(
                                x: value.location.x / proxy.size.width,
                                y: value.location.y / proxy.size.height
                            )
                        )
                        path = BannerPath(points: drawnPoints)
                    }
            )
        }
        .frame(height: 240)
    }

    /// Dibujo de la trayectoria a escala del lienzo.
    private func stroke(in size: CGSize) -> Path {
        guard !path.isStraight else { return Path() }
        return Path { shape in
            let steps = 120
            for step in 0...steps {
                let x = Double(step) / Double(steps)
                let point = CGPoint(x: x * size.width, y: path.normalizedY(at: x) * size.height)
                if step == 0 {
                    shape.move(to: point)
                } else {
                    shape.addLine(to: point)
                }
            }
        }
    }

    /// Sustituye el trazo por uno predefinido.
    private func use(_ preset: BannerPath) {
        drawnPoints = preset.points
        path = preset
    }
}

#Preview {
    PathEditorView(initialPath: .sawtooth) { _ in }
}
