import SwiftUI
import UIKit

/// Campo de edición del mensaje con atributos.
///
/// Envuelve un `UITextView` con `allowsEditingTextAttributes`, que es lo que
/// añade *Formato* (negrita, cursiva, subrayado…) al menú que aparece al
/// seleccionar texto. SwiftUI no ofrece edición con atributos en iOS 17, así
/// que aquí sí está justificado bajar a UIKit.
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString

    /// Mando a distancia del editor para la barra sobre el teclado.
    let controller: RichTextController

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, controller: controller)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        // El almacén avisa también de los cambios que solo tocan atributos —los
        // que hace el menú *Formato*—, que no llegan por `textViewDidChange`.
        view.textStorage.delegate = context.coordinator
        view.allowsEditingTextAttributes = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.font = .systemFont(ofSize: BannerText.editingFontSize)
        view.attributedText = text
        view.typingAttributes = [
            .font: UIFont.systemFont(ofSize: BannerText.editingFontSize),
            .foregroundColor: UIColor.label
        ]
        // La barra va sobre el teclado y no debajo del campo: el menú de
        // selección de iOS aparece junto al texto y taparía cualquier control
        // que estuviera ahí.
        view.inputAccessoryView = context.coordinator.makeToolbar()
        controller.textView = view
        return view
    }

    /// Ajusta el editor al ancho disponible y crece solo en alto.
    ///
    /// Sin esto, un `UITextView` sin desplazamiento reclama como anchura la de
    /// todo el texto en una línea y desborda la pantalla de ajustes entera.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        controller.textView = uiView
        // Solo se reescribe cuando el cambio viene de fuera (cargar un mensaje
        // guardado); si no, se perdería la posición del cursor al teclear.
        if !uiView.attributedText.isEqual(to: text) {
            let selection = uiView.selectedRange
            uiView.attributedText = text
            uiView.selectedRange = NSRange(
                location: min(selection.location, text.length),
                length: 0
            )
        }
    }

    // MARK: - Coordinador

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, NSTextStorageDelegate {
        private let text: Binding<NSAttributedString>
        private let controller: RichTextController

        init(text: Binding<NSAttributedString>, controller: RichTextController) {
            self.text = text
            self.controller = controller
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.attributedText
        }

        nonisolated func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorage.EditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            let updated = NSAttributedString(attributedString: textStorage)
            // Se difiere: aquí se está en plena pasada de layout del editor y
            // cambiar el estado de SwiftUI en ese momento provoca avisos.
            Task { @MainActor [weak self] in
                self?.text.wrappedValue = updated
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            controller.hasSelection = textView.selectedRange.length > 0
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            controller.isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            controller.isEditing = false
            controller.hasSelection = false
        }

        // MARK: - Barra sobre el teclado

        /// Crea la barra de formato que acompaña al teclado.
        func makeToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            toolbar.items = [
                item(systemName: "bold", action: #selector(toggleBold), label: "settings.text.bold"),
                item(systemName: "italic", action: #selector(toggleItalic), label: "settings.text.italic"),
                item(systemName: "underline", action: #selector(toggleUnderline), label: "settings.text.underline"),
                item(systemName: "paintpalette", action: #selector(chooseColor), label: "settings.text.color"),
                item(systemName: "paintbrush", action: #selector(clearColor), label: "settings.text.clearColor"),
                UIBarButtonItem(systemItem: .flexibleSpace),
                UIBarButtonItem(
                    title: String(localized: "common.done"),
                    style: .done,
                    target: self,
                    action: #selector(finishEditing)
                )
            ]
            return toolbar
        }

        private func item(systemName: String, action: Selector, label: LocalizedStringResource) -> UIBarButtonItem {
            let item = UIBarButtonItem(
                image: UIImage(systemName: systemName),
                style: .plain,
                target: self,
                action: action
            )
            item.accessibilityLabel = String(localized: label)
            return item
        }

        @objc private func toggleBold() { controller.toggle(.traitBold) }
        @objc private func toggleItalic() { controller.toggle(.traitItalic) }
        @objc private func toggleUnderline() { controller.toggleUnderline() }
        @objc private func clearColor() { controller.clearColor() }
        @objc private func finishEditing() { controller.endEditing() }

        @objc private func chooseColor() {
            controller.presentColorPicker()
        }
    }
}

// MARK: - Mando del editor

/// Aplica formato al texto seleccionado desde fuera del editor.
///
/// La barra sobre el teclado y el editor viven en ramas distintas de la vista,
/// así que se comunican a través de este objeto en lugar de por enlaces.
@Observable
@MainActor
final class RichTextController: NSObject, UIColorPickerViewControllerDelegate {

    /// Editor activo; lo registra la propia vista al crearse.
    @ObservationIgnored weak var textView: UITextView?

    /// Tramo sobre el que se aplicará el color elegido.
    ///
    /// Se recuerda porque el selector de color se presenta como hoja y el
    /// editor pierde el foco —y con él la selección visible— mientras está
    /// abierto.
    @ObservationIgnored private var pendingRange: NSRange?

    /// Indica si hay texto seleccionado, para habilitar los botones de formato.
    var hasSelection = false

    /// Indica si el editor tiene el foco.
    var isEditing = false

    /// Cierra el teclado.
    func endEditing() {
        textView?.resignFirstResponder()
    }

    /// Acción con la que se notifica al modelo el texto ya modificado.
    @ObservationIgnored var onChange: ((NSAttributedString) -> Void)?

    /// Alterna negrita o cursiva en la selección.
    /// - Parameter trait: Rasgo a alternar.
    func toggle(_ trait: UIFontDescriptor.SymbolicTraits) {
        edit { text, range in
            text.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let font = value as? UIFont ?? .systemFont(ofSize: BannerText.editingFontSize)
                var traits = font.fontDescriptor.symbolicTraits
                if traits.contains(trait) {
                    traits.remove(trait)
                } else {
                    traits.insert(trait)
                }
                guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return }
                text.addAttribute(
                    .font,
                    value: UIFont(descriptor: descriptor, size: font.pointSize),
                    range: subrange
                )
            }
        }
    }

    /// Alterna el subrayado en la selección.
    func toggleUnderline() {
        edit { text, range in
            let isUnderlined = text.attribute(.underlineStyle, at: range.location, effectiveRange: nil) != nil
            if isUnderlined {
                text.removeAttribute(.underlineStyle, range: range)
            } else {
                text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
    }

    /// Abre el selector de color del sistema para el tramo seleccionado.
    func presentColorPicker() {
        guard let textView, textView.selectedRange.length > 0 else { return }
        pendingRange = textView.selectedRange

        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = false
        if let current = textView.attributedText.attribute(
            .foregroundColor,
            at: textView.selectedRange.location,
            effectiveRange: nil
        ) as? UIColor {
            picker.selectedColor = current
        }
        topViewController()?.present(picker, animated: true)
    }

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        applyColor(viewController.selectedColor)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        pendingRange = nil
    }

    /// Controlador visible más arriba, desde el que presentar el selector.
    private func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: {
                $0.session.role == .windowApplication && $0.activationState == .foregroundActive
            })?
            .keyWindow?
            .rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Pinta la selección con el color indicado.
    /// - Parameter color: Color elegido por el usuario.
    func applyColor(_ color: UIColor) {
        edit { text, range in
            text.addAttribute(.foregroundColor, value: color, range: range)
            // La marca distingue este color del que UIKit pone por defecto.
            text.addAttribute(BannerText.customColorKey, value: true, range: range)
        }
    }

    /// Devuelve la selección al color base del rótulo.
    func clearColor() {
        edit { text, range in
            text.removeAttribute(BannerText.customColorKey, range: range)
            text.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        }
    }

    /// Aplica un cambio a la selección conservando cursor y foco.
    ///
    /// Si el editor perdió el foco al abrir el selector de color, se usa el
    /// tramo que se guardó antes de presentarlo.
    private func edit(_ change: (NSMutableAttributedString, NSRange) -> Void) {
        guard let textView else { return }
        let range = textView.selectedRange.length > 0 ? textView.selectedRange : (pendingRange ?? NSRange())
        guard range.length > 0, NSMaxRange(range) <= textView.attributedText.length else { return }
        let updated = NSMutableAttributedString(attributedString: textView.attributedText)
        change(updated, range)
        textView.attributedText = updated
        textView.selectedRange = range
        onChange?(updated)
    }
}
