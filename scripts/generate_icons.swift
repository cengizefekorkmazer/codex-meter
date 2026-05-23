#!/usr/bin/env swift

//
// generate_icons.swift
//
// Generates the AppIcon set at all macOS-required sizes from a single
// in-memory design. Run from the repo root:
//
//   swift scripts/generate_icons.swift
//
// Output goes to CodexMeter/Assets.xcassets/AppIcon.appiconset/
//

import AppKit
import CoreGraphics

let sizes: [(label: String, dim: Int)] = [
    ("16x16",       16),
    ("16x16@2x",    32),
    ("32x32",       32),
    ("32x32@2x",    64),
    ("128x128",    128),
    ("128x128@2x", 256),
    ("256x256",    256),
    ("256x256@2x", 512),
    ("512x512",    512),
    ("512x512@2x", 1024),
]

func renderIconPNG(size: Int) -> Data {
    let dim = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(x: 0, y: 0, width: dim, height: dim)

    // Rounded square background (macOS Big Sur+ icon shape).
    let cornerRadius = dim * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()

    // Vertical gradient.
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.10, green: 0.13, blue: 0.22, alpha: 1.0),
        NSColor(srgbRed: 0.18, green: 0.10, blue: 0.28, alpha: 1.0),
    ])!
    gradient.draw(in: rect, angle: 90)

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = dim * 0.30
    let lineWidth = dim * 0.085

    // Background ring (white, low opacity).
    let bgRing = NSBezierPath()
    bgRing.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    bgRing.lineWidth = lineWidth
    bgRing.stroke()

    // Progress arc — 65% filled, green-cyan, rounded caps.
    let progress: CGFloat = 0.65
    let progressArc = NSBezierPath()
    progressArc.appendArc(
        withCenter: center,
        radius: radius,
        startAngle: 90,
        endAngle: 90 - 360 * progress,
        clockwise: true
    )
    NSColor(srgbRed: 0.22, green: 0.87, blue: 0.62, alpha: 1.0).setStroke()
    progressArc.lineWidth = lineWidth
    progressArc.lineCapStyle = .round
    progressArc.stroke()

    // Center letter "C".
    let fontSize = dim * 0.36
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
    ]
    let text = "C" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textRect = NSRect(
        x: center.x - textSize.width / 2,
        y: center.y - textSize.height / 2,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let outDir = URL(fileURLWithPath: "CodexMeter/Assets.xcassets/AppIcon.appiconset")
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

for (label, dim) in sizes {
    let data = renderIconPNG(size: dim)
    let url = outDir.appendingPathComponent("icon_\(label).png")
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(dim)x\(dim))")
}
