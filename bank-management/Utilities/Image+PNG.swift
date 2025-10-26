//
//  Image+PNG.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import Foundation

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

public extension PlatformImage {
    /// Cross-platform PNG data
    /// - iOS: UIImage.pngData()
    /// - macOS: TIFF→PNG。TIFFが無い場合は CGImage を生成してから PNG 化
    var pngDataCompat: Data? {
#if os(macOS)
        // 1) 通常経路: TIFF → PNG
        if let tiff = self.tiffRepresentation,
           let rep  = NSBitmapImageRep(data: tiff),
           let png  = rep.representation(using: .png, properties: [:]) {
            return png
        }
        // 2) フォールバック: CGImage を作ってから PNG
        guard let cg = self._cgImageFallback() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        return rep.representation(using: .png, properties: [:])
#else
        return self.pngData()
#endif
    }
    
    /// 画像を PNG で保存（成功/失敗を Bool で返す）
    @discardableResult
    func writePNG(to url: URL, options: Data.WritingOptions = [.atomic]) -> Bool {
        guard let data = pngDataCompat else { return false }
        do {
            try data.write(to: url, options: options)
            return true
        } catch {
#if DEBUG
            print("❌ PNG書き込み失敗: \(error.localizedDescription)")
#endif
            return false
        }
    }
}

#if os(macOS)
private extension NSImage {
    /// NSImage が TIFF を持たない（PDF 由来など）場合のフォールバックで CGImage を作る
    func _cgImageFallback() -> CGImage? {
        // 1) 既存の CGImage を取れるならそれを使う
        var rect = CGRect(origin: .zero, size: size)
        if let cg = self.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cg
        }
        
        // 2) 描画して CGImage を作る（解像度: 1.0, 背景透明）
        let scale: CGFloat = 1.0
        let width  = Int(size.width  * scale)
        let height = Int(size.height * scale)
        guard width > 0, height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.interpolationQuality = .high
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: scale, y: -scale)
        
        // NSImage を CoreGraphics に描画
        let dstRect = CGRect(origin: .zero, size: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        self.draw(in: dstRect, from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        
        return ctx.makeImage()
    }
}
#endif
