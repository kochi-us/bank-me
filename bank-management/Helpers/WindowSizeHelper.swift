//
//  WindowSizeHelper.swift
//  bank-management
//
//  Created by KOCHI HASHIMOTO on 2025/10/29.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// 初回起動時にウインドウの初期サイズを設定し、かつ最小サイズ（minSize）を固定する
struct InitialWindowSize: ViewModifier {
    var minWidth: CGFloat
    var minHeight: CGFloat
    var initialWidth: CGFloat
    var initialHeight: CGFloat

    @AppStorage("didSetInitialWindowSize") private var didSetInitial = false

    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor { window in
                    guard let window else { return }

                    // いつでも有効：最小サイズを固定
                    window.minSize = NSSize(width: minWidth, height: minHeight)

                    // 初回起動時のみ：初期サイズをセット
                    if !didSetInitial {
                        let frame = NSRect(
                            x: window.frame.origin.x,
                            y: window.frame.origin.y,
                            width: initialWidth,
                            height: initialHeight
                        )
                        window.setFrame(frame, display: true, animate: false)
                        didSetInitial = true
                    }
                }
            )
    }
}

private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    init(_ onResolve: @escaping (NSWindow?) -> Void) {
        self.onResolve = onResolve
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            onResolve(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            onResolve(nsView?.window)
        }
    }
}

extension View {
    /// 使いやすいショートカット
    func initialWindowSize(minWidth: CGFloat, minHeight: CGFloat,
                           initialWidth: CGFloat, initialHeight: CGFloat) -> some View {
        modifier(InitialWindowSize(minWidth: minWidth, minHeight: minHeight,
                                   initialWidth: initialWidth, initialHeight: initialHeight))
    }
}
