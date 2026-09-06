// GPUMonitor AppIcon 生成器（Apple 风格矢量图标）
// 运行：swift scripts/generate_icon.swift

import AppKit
import CoreGraphics

let size = CGSize(width: 1024, height: 1024)
let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "assets"

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// 连续圆角“squircle”路径（类 Apple 图标外框）
func squirclePath(in rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let minX = rect.minX, maxX = rect.maxX
    let minY = rect.minY, maxY = rect.maxY
    let r = min(radius, rect.width / 2)
    path.move(to: CGPoint(x: minX + r, y: minY))
    path.addLine(to: CGPoint(x: maxX - r, y: minY))
    path.addQuadCurve(to: CGPoint(x: maxX, y: minY + r),
                      control: CGPoint(x: maxX - r * 0.2, y: minY))
    path.addLine(to: CGPoint(x: maxX, y: maxY - r))
    path.addQuadCurve(to: CGPoint(x: maxX - r, y: maxY),
                      control: CGPoint(x: maxX, y: maxY - r * 0.2))
    path.addLine(to: CGPoint(x: minX + r, y: maxY))
    path.addQuadCurve(to: CGPoint(x: minX, y: maxY - r),
                      control: CGPoint(x: minX + r * 0.2, y: maxY))
    path.addLine(to: CGPoint(x: minX, y: minY + r))
    path.addQuadCurve(to: CGPoint(x: minX + r, y: minY),
                      control: CGPoint(x: minX, y: minY + r * 0.2))
    path.closeSubpath()
    return path
}

func drawIcon() -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let bounds = CGRect(origin: .zero, size: size)
    let iconRect = bounds.insetBy(dx: 0, dy: 0)

    // 1. 背景：深色石墨渐变（Apple “monochrome” 风格）
    let bgPath = squirclePath(in: iconRect, radius: 228)
    context.addPath(bgPath)
    context.clip()

    let colors = [
        color(0x4a4a52).cgColor,
        color(0x26262b).cgColor,
        color(0x101012).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors,
                              locations: [0, 0.52, 1])!
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: bounds.midX, y: bounds.maxY),
                               end: CGPoint(x: bounds.midX, y: bounds.minY),
                               options: [])

    // 2. 顶部柔和高光
    let highlight = NSColor(white: 1, alpha: 0.08)
    highlight.setFill()
    context.fillEllipse(in: CGRect(x: -120, y: 620, width: 1264, height: 700))

    // 3. 外圈细描边
    context.setStrokeColor(NSColor(white: 1, alpha: 0.16).cgColor)
    context.setLineWidth(5)
    context.addPath(squirclePath(in: iconRect.insetBy(dx: 2.5, dy: 2.5), radius: 226))
    context.strokePath()

    // 4. 芯片轮廓
    let chip = CGRect(x: 260, y: 250, width: 504, height: 504)
    let chipPath = CGPath(roundedRect: chip, cornerWidth: 74, cornerHeight: 74, transform: nil)
    context.addPath(chipPath)
    context.setFillColor(NSColor(white: 1, alpha: 0.06).cgColor)
    context.fillPath()
    context.addPath(chipPath)
    context.setStrokeColor(NSColor(white: 1, alpha: 0.92).cgColor)
    context.setLineWidth(30)
    context.strokePath()

    // 5. 四周引脚（上/下/左/右）
    let pinLength: CGFloat = 56
    let pinWidth: CGFloat = 40
    let gap: CGFloat = 42
    let pinColor = NSColor(white: 1, alpha: 0.95)
    pinColor.setFill()

    func pins(at side: CGRect, horizontal: Bool) {
        var step = 0
        var x: CGFloat = side.minX
        while x < side.maxX {
            if step % 2 == 0 {
                let rect = horizontal
                    ? CGRect(x: x, y: side.minY, width: pinWidth, height: pinLength)
                    : CGRect(x: side.minY, y: x, width: pinLength, height: pinWidth)
                context.fill(rect)
            }
            x += pinWidth + gap
            step += 1
        }
    }

    let topRect = CGRect(x: chip.minX + 44, y: chip.minY - pinLength - 2, width: chip.width - 88, height: pinLength)
    let bottomRect = CGRect(x: chip.minX + 44, y: chip.maxY + 2, width: chip.width - 88, height: pinLength)
    let leftRect = CGRect(x: chip.minX - pinLength - 2, y: chip.minY + 44, width: pinLength, height: chip.height - 88)
    let rightRect = CGRect(x: chip.maxX + 2, y: chip.minY + 44, width: pinLength, height: chip.height - 88)

    pins(at: topRect, horizontal: true)
    pins(at: bottomRect, horizontal: true)
    pins(at: leftRect, horizontal: false)
    pins(at: rightRect, horizontal: false)

    // 6. 芯片内部：GPU 核心网格与蓝色发光点
    let inner = chip.insetBy(dx: 62, dy: 62)
    let gridPath = CGMutablePath()
    let cols = 3, rows = 3
    let cellW = inner.width / CGFloat(cols)
    let cellH = inner.height / CGFloat(rows)
    for row in 0..<rows {
        for col in 0..<cols {
            let cell = CGRect(x: inner.minX + CGFloat(col) * cellW + 10,
                              y: inner.minY + CGFloat(row) * cellH + 10,
                              width: cellW - 20,
                              height: cellH - 20)
            gridPath.addRoundedRect(in: cell, cornerWidth: 16, cornerHeight: 16)
        }
    }
    context.addPath(gridPath)
    context.setFillColor(NSColor(white: 1, alpha: 0.14).cgColor)
    context.fillPath()

    // 中心强调色：柔和的苹果蓝渐变圆点
    let glowColors = [
        NSColor(srgbRed: 0.35, green: 0.72, blue: 1, alpha: 0.95).cgColor,
        NSColor(srgbRed: 0.10, green: 0.46, blue: 0.98, alpha: 0.95).cgColor
    ] as CFArray
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: glowColors,
                          locations: [0, 1])!
    let dotRect = CGRect(x: inner.midX - 58, y: inner.midY - 58, width: 116, height: 116)
    context.addPath(CGPath(ellipseIn: dotRect, transform: nil))
    context.clip()
    context.drawLinearGradient(glow,
                               start: CGPoint(x: dotRect.minX, y: dotRect.maxY),
                               end: CGPoint(x: dotRect.maxX, y: dotRect.minY),
                               options: [])

    context.resetClip()
    context.setStrokeColor(NSColor(white: 1, alpha: 0.95).cgColor)
    context.setLineWidth(6)
    context.addPath(CGPath(ellipseIn: dotRect, transform: nil))
    context.strokePath()

    image.unlockFocus()
    return image
}

// 导出多种尺寸
let fileManager = FileManager.default
try? fileManager.createDirectory(atPath: outDir, withIntermediateDirectories: true)
try? fileManager.createDirectory(atPath: "\(outDir)/AppIcon.iconset", withIntermediateDirectories: true)

let image = drawIcon()
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

for spec in sizes {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let cg = rep.cgImage else { continue }

    let pixelSize = spec.pixels
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    guard let out = ctx.makeImage() else { continue }
    let rep2 = NSBitmapImageRep(cgImage: out)
    guard let png = rep2.representation(using: .png, properties: [:]) else { continue }
    let url = URL(fileURLWithPath: "\(outDir)/AppIcon.iconset/\(spec.name).png")
    try? png.write(to: url)
}

print("icon pngs written to \(outDir)/AppIcon.iconset")
