import SwiftUI
import UIKit

/// Dibuja un texto con atributos en una sola línea.
///
/// Se usa `UILabel` en vez de `Text` porque el mensaje lleva tipo, rasgos y
/// color distintos por tramos, y con `NSAttributedString` se dibuja y se mide
/// exactamente igual que se calculó.
struct AttributedLabel: UIViewRepresentable {
    let attributedText: NSAttributedString

    /// Reduce el cuerpo hasta que el texto quepa en el ancho disponible.
    ///
    /// Es lo que quieren las vistas previas; el rótulo en marcha, en cambio,
    /// necesita el tamaño completo porque su gracia es no caber y desfilar.
    var scalesToFit = false

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        // El rótulo se recorta por los lados a propósito: el texto es más ancho
        // que la pantalla y va entrando por la derecha.
        label.lineBreakMode = .byClipping
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = attributedText
        uiView.adjustsFontSizeToFitWidth = scalesToFit
        uiView.minimumScaleFactor = scalesToFit ? 0.3 : 0
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let intrinsic = uiView.intrinsicContentSize
        // Sin acotar a lo propuesto, un mensaje largo impondría su anchura
        // natural al layout y desbordaría la pantalla de ajustes entera.
        guard let width = proposal.width, width.isFinite else { return intrinsic }
        return CGSize(width: min(intrinsic.width, width), height: intrinsic.height)
    }
}
