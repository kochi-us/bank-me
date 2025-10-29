//
//  CaretTextField.swift
//  bank-management
//
//  Created by KOCHI HASHIMOTO on 2025/10/29.
//

import SwiftUI
#if os(macOS)
import AppKit

/// macOS 用の NSTextField を拡張して、キャレットの色や背景色をカスタマイズ
final class CaretTextField: NSTextField {
    var caretColor: NSColor? = nil

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        applyCaret()
        return ok
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
        DispatchQueue.main.async { [weak self] in self?.applyCaret() }
    }

    private func applyCaret() {
        guard let editor = window?.fieldEditor(true, for: self) as? NSTextView else { return }
        editor.insertionPointColor = .red
        let len = editor.string.utf16.count
        editor.setSelectedRange(NSRange(location: len, length: 0))
    }
}

/// SwiftUI から使うためのラッパー
struct MacCaretTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var caretColor: NSColor? = nil
    var showsBezel: Bool = true 
    init(text: Binding<String>, placeholder: String = "", caretColor: NSColor? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.caretColor = caretColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CaretTextField {
        let tf = CaretTextField(string: text)
        tf.isEditable = true
        tf.isBezeled = false
        tf.isBordered = false
        tf.bezelStyle = .roundedBezel
        tf.focusRingType = .none
        tf.placeholderString = placeholder
        tf.delegate = context.coordinator
        tf.caretColor = caretColor

        // 背景と文字色を明示的に設定（検索窓を白くする）
        tf.drawsBackground = true
        tf.backgroundColor = .white
        tf.textColor = .black

        // フォーカスを初期設定
        DispatchQueue.main.async {
            tf.window?.makeFirstResponder(tf)
        }
        return tf
    }

    func updateNSView(_ nsView: CaretTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.caretColor = caretColor ?? .red   // キャレットを赤で維持
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacCaretTextField
        init(_ parent: MacCaretTextField) { self.parent = parent }

        func controlTextDidChange(_ note: Notification) {
            if let tf = note.object as? NSTextField {
                parent.text = tf.stringValue
            }
        }

        func controlTextDidBeginEditing(_ note: Notification) {
            if let editor = (note.object as? NSTextField)?.currentEditor() as? NSTextView {
                editor.insertionPointColor = .red
            }
        }
    }
}
#endif
