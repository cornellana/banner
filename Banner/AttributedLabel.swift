import SwiftUI
import UIKit

/// Dibuja un texto con atributos en una sola línea.
///
/// Se usa `UILabel` en vez de `Text` porque el mensaje lleva tipo, rasgos y
/// color distintos por tramos, y con `NSAttributedString` se dibuja y se mide
/// exactamente igual que se calculó.
struct AttributedLabel: UIViewRepresentable {
    let attributedText: NSAttributedString

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        // El rótulo se recorta por los lados a propósito: el texto es más ancho
        // que la pantalla y va entrando por la derecha.
        label.lineBreakMode = .byClipping
        label.attributedText = attributedText
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = attributedText
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        uiView.intrinsicContentSize
    }
}
