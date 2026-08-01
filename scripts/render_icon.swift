#!/usr/bin/env swift
//
// Genera el icono de la app: un rótulo luminoso desplazándose sobre un
// degradado nocturno. Se dibuja con CoreGraphics puro porque
// NSGraphicsContext no funciona de forma fiable fuera de una app de AppKit.
//
// Uso: swift scripts/render_icon.swift Banner/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()

// Sin canal alfa: App Store rechaza iconos de iOS con transparencia.
guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: side * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("No se pudo crear el contexto de dibujo")
}

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

// MARK: - Fondo

let background = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        color(0.09, 0.06, 0.24),
        color(0.24, 0.07, 0.35),
        color(0.05, 0.04, 0.12)
    ] as CFArray,
    locations: [0.0, 0.55, 1.0]
)!
context.drawLinearGradient(
    background,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: side, y: 0),
    options: []
)

// MARK: - Marco del rótulo

let panel = CGRect(x: 96, y: 300, width: side - 192, height: 424)
let panelPath = CGPath(roundedRect: panel, cornerWidth: 72, cornerHeight: 72, transform: nil)
context.addPath(panelPath)
context.setFillColor(color(0.02, 0.02, 0.05))
context.fillPath()

context.addPath(panelPath)
context.setStrokeColor(color(1, 1, 1, 0.16))
context.setLineWidth(8)
context.strokePath()

// MARK: - Puntos de led del rótulo

context.saveGState()
context.addPath(panelPath)
context.clip()

let dotSpacing = 34.0
let dotRadius = 5.0
context.setFillColor(color(1, 1, 1, 0.05))
for y in stride(from: panel.minY + 24, to: panel.maxY, by: dotSpacing) {
    for x in stride(from: panel.minX + 24, to: panel.maxX, by: dotSpacing) {
        context.fillEllipse(in: CGRect(
            x: x - dotRadius, y: y - dotRadius,
            width: dotRadius * 2, height: dotRadius * 2
        ))
    }
}

// MARK: - Texto del rótulo

let fontSize = 300.0
let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
    ?? CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
let glyphColor = color(1.0, 0.78, 0.16)

// Se usan las claves de CoreText (y no las de NSAttributedString) porque el
// script se ejecuta sin AppKit ni UIKit.
let attributes = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: glyphColor,
    kCTKernAttributeName: 6.0 as CFNumber
] as CFDictionary
let attributedText = CFAttributedStringCreate(nil, "AB!" as CFString, attributes)!
let line = CTLineCreateWithAttributedString(attributedText)
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

// Halo del texto para dar sensación de rótulo encendido.
context.setShadow(
    offset: .zero,
    blur: 48,
    color: color(1.0, 0.72, 0.10, 0.9)
)
context.textPosition = CGPoint(
    x: panel.midX - bounds.width / 2 - bounds.minX,
    y: panel.midY - bounds.height / 2 - bounds.minY
)
CTLineDraw(line, context)
context.setShadow(offset: .zero, blur: 0, color: nil)

// Flecha de desplazamiento a la izquierda del texto.
context.setFillColor(color(1, 1, 1, 0.35))
let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: panel.minX + 52, y: panel.midY))
arrow.addLine(to: CGPoint(x: panel.minX + 116, y: panel.midY + 52))
arrow.addLine(to: CGPoint(x: panel.minX + 116, y: panel.midY - 52))
arrow.closeSubpath()
context.addPath(arrow)
context.fillPath()

context.restoreGState()

// MARK: - Destellos decorativos

for (cx, cy, r, alpha) in [
    (170.0, 880.0, 70.0, 0.16),
    (870.0, 170.0, 96.0, 0.12),
    (830.0, 860.0, 46.0, 0.10)
] {
    context.setFillColor(color(1, 1, 1, alpha))
    context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}

// MARK: - Escritura del PNG

guard let image = context.makeImage() else {
    fatalError("No se pudo generar la imagen")
}
let url = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
) else {
    fatalError("No se pudo crear el destino \(outputPath)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("No se pudo escribir \(outputPath)")
}
print("Icono generado en \(outputPath)")
