//
//  CaretTextField.swift
//  bank-management
//
//  Created by KOCHI HASHIMOTO on 2025/10/29.
//

// CaretTextField.swift 置き換え版
import SwiftUI

#if os(macOS)
import AppKit

/// 単行の NSTextField ラッパー（キャレット色・システム適応文字色）
struct MacCaretTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var caretColor: NSColor = .controlAccentColor

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CaretAwareTextField {
        let tf = CaretAwareTextField()
        tf.caretColor = caretColor

        // ここがポイント: システム適応色（ライト=黒、ダーク=白）
        tf.textColor = .labelColor
        tf.backgroundColor = .clear

        // プレースホルダーもシステム適応色
        tf.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.placeholderTextColor]
        )

        tf.isBezeled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.usesSingleLineMode = true
        tf.lineBreakMode = .byClipping
        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.didEndEditing)
        return tf
    }

    func updateNSView(_ nsView: CaretAwareTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
        // 外観変更時にも追従させる
        nsView.textColor = .labelColor
        nsView.caretColor = caretColor
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: MacCaretTextField
        init(_ parent: MacCaretTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            if parent.text != tf.stringValue { parent.text = tf.stringValue }
        }

        @objc func didEndEditing() { /* no-op (キーボードのReturn対策用) */ }
    }
}

/// キャレット色だけをカスタマイズする NSTextField
final class CaretAwareTextField: NSTextField {
    var caretColor: NSColor = .controlAccentColor
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            editor.insertionPointColor = caretColor
        }
        return ok
    }
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let editor = currentEditor() as? NSTextView {
            editor.insertionPointColor = caretColor
        }
    }
}

#else
// iOS などでは普通の TextField を組合せて使う想定のためダミーを用意（使わないがビルドは通る）
struct MacCaretTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var caretColor: UIColor = .tintColor
    var body: some View {
        TextField(placeholder, text: $text)
            .foregroundStyle(.primary)
    }
}
#endif
