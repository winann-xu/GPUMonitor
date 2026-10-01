// MARK: - MenuBarView
// 菜单栏主视图 — 常驻在右上角状态栏

import SwiftUI
import AppKit

@MainActor
class MenuBarController: ObservableObject {
    static let shared = MenuBarController()

    /// 菜单栏要画的「格子」；每个格子尺寸固定，数值画在格子内部
    @Published var chips: [MenuBarChip] = []
    /// 是否在格子里显示数值（对应设置里的「显示文本摘要」）
    @Published var showValues: Bool = true
    /// 鼠标悬停提示（完整文字版）
    @Published var tooltip: String = "GPU Monitor"
    @Published var isWarning: Bool = false
    @Published var isCritical: Bool = false
}

struct MenuBarView: View {
    @EnvironmentObject var menuBarCtrl: MenuBarController
    @Environment(\.colorScheme) private var colorScheme

    /// 格子视觉风格（改这一处即可换样式）
    static let chipStyle: MenuBarChipStyle = .labeled

    var body: some View {
        // 为什么不用 Text：label 交给状态栏后字体会被系统菜单栏字体接管，
        // 字符串宽度必然随数值抖动（实测同一格式 199→239pt，抖动 40pt）。
        // 这里整条自绘成固定尺寸图像 —— 宽度只由格子数决定，与数值无关。
        Image(nsImage: MenuBarLabelImage.make(menuBarCtrl.chips,
                                              showValues: menuBarCtrl.showValues,
                                              dark: colorScheme == .dark,
                                              style: Self.chipStyle))
            .help(menuBarCtrl.tooltip)
    }
}

// MARK: - 菜单栏格子模型
/// 每个指标用图形标识（替代原来的 M / G / ↓ 等字母），数值单独显示
enum MenuBarIconKind {
    case memory      // 内存条
    case download    // 下载箭头 + 托盘
    case gpu         // 芯片（四边引脚 + 内核）
    case tokens      // 闪电（生成速度）
    case temperature // 温度计
}

struct MenuBarChip {
    /// 格子里只显示数值，如 "37"、"0.0"、"1"
    var text: String
    /// 比例填充 0…1（电池式液位）
    var fraction: Double
    var color: NSColor
    var icon: MenuBarIconKind
}

// MARK: - 图标
// 优先用 SF Symbols（苹果矢量图标，漂亮、形象、深浅色通吃）；
// 万一系统里缺某个符号，回退到下面的自绘矢量图形，保证不会空白。
enum MenuBarIcon {
    static func symbolName(_ kind: MenuBarIconKind) -> String {
        switch kind {
        case .memory:      return "memorychip"          // 内存条
        case .download:    return "arrow.down.to.line"  // 下载：下箭头 + 底线
        case .gpu:         return "display"             // 显示器（图形 / GPU）
        case .tokens:      return "bolt.fill"           // 闪电（生成速度）
        case .temperature: return "thermometer.medium"  // 温度计
        }
    }

    static func draw(_ kind: MenuBarIconKind, in box: NSRect, color: NSColor,
                     lineWidth: CGFloat = 1.0, pointSize: CGFloat = 10.5) {
        if let image = symbolImage(symbolName(kind), pointSize: pointSize, color: color) {
            drawFitted(image, in: box)
            return
        }
        drawVector(kind, in: box, color: color, lineWidth: lineWidth)
    }

    /// 把 SF Symbol 渲染成指定颜色的位图（2x，Retina 不糊）
    private static func symbolImage(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil),
              let configured = base.withSymbolConfiguration(
                  NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)) else { return nil }
        let size = configured.size
        guard size.width >= 1, size.height >= 1 else { return nil }
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((size.width * scale).rounded()), pixelsHigh: Int((size.height * scale).rounded()),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.cgContext.scaleBy(x: scale, y: scale)
        ctx.imageInterpolation = .high
        configured.draw(in: NSRect(origin: .zero, size: size))
        color.setFill()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)   // 只给符号本身染色
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }

    /// 等比缩放居中（图标外观固定，与数值无关）
    private static func drawFitted(_ image: NSImage, in box: NSRect) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let fit = min(box.width / size.width, box.height / size.height)
        let w = size.width * fit, h = size.height * fit
        image.draw(in: NSRect(x: (box.midX - w / 2).rounded(), y: (box.midY - h / 2).rounded(),
                              width: w, height: h),
                   from: .zero, operation: .sourceOver, fraction: 1)
    }

    /// 回退用自绘矢量（12×12 设计稿，等宽线条）
    private static func drawVector(_ kind: MenuBarIconKind, in box: NSRect,
                                   color: NSColor, lineWidth: CGFloat) {
        let scale = box.width / 12.0
        guard scale > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: box.minX, yBy: box.minY)
        transform.scale(by: scale)
        transform.concat()
        color.setStroke()
        color.setFill()
        let lw = lineWidth / scale
        switch kind {
        case .memory:
            // 内存条：PCB 本体 + 底部金手指
            let body = NSBezierPath(roundedRect: NSRect(x: 0.6, y: 4.0, width: 10.8, height: 5.4),
                                    xRadius: 1.0, yRadius: 1.0)
            body.lineWidth = lw
            body.stroke()
            for cx in [1.9, 4.4, 6.9, 9.4] {
                NSRect(x: cx - 0.5, y: 1.7, width: 1.0, height: 2.4).fill()
            }
        case .download:
            // 下载：托盘 + 下箭头
            NSRect(x: 0.9, y: 0.8, width: 10.2, height: 1.3).fill()
            NSRect(x: 5.1, y: 6.5, width: 1.8, height: 4.8).fill()
            let head = NSBezierPath()
            head.move(to: NSPoint(x: 2.9, y: 7.1))
            head.line(to: NSPoint(x: 9.1, y: 7.1))
            head.line(to: NSPoint(x: 6.0, y: 2.9))
            head.close()
            head.fill()
        case .gpu:
            // 芯片：本体 + 四边引脚 + 内核
            let body = NSBezierPath(roundedRect: NSRect(x: 3.0, y: 3.0, width: 6.0, height: 6.0),
                                    xRadius: 1.3, yRadius: 1.3)
            body.lineWidth = lw
            body.stroke()
            for y in [4.6, 6.4] {
                NSRect(x: 0.9, y: y, width: 2.1, height: 1.0).fill()
                NSRect(x: 9.0, y: y, width: 2.1, height: 1.0).fill()
            }
            for x in [4.6, 6.4] {
                NSRect(x: x, y: 0.9, width: 1.0, height: 2.1).fill()
                NSRect(x: x, y: 9.0, width: 1.0, height: 2.1).fill()
            }
            NSBezierPath(roundedRect: NSRect(x: 4.8, y: 4.8, width: 2.4, height: 2.4),
                         xRadius: 0.5, yRadius: 0.5).fill()
        case .tokens:
            // 闪电：生成速度
            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: 7.4, y: 11.7))
            bolt.line(to: NSPoint(x: 2.7, y: 6.3))
            bolt.line(to: NSPoint(x: 5.6, y: 6.3))
            bolt.line(to: NSPoint(x: 4.5, y: 0.3))
            bolt.line(to: NSPoint(x: 9.3, y: 5.9))
            bolt.line(to: NSPoint(x: 6.3, y: 5.9))
            bolt.close()
            bolt.fill()
        case .temperature:
            // 温度计：外壳 + 球部 + 水银柱
            let stem = NSBezierPath(roundedRect: NSRect(x: 4.7, y: 3.6, width: 2.6, height: 8.0),
                                    xRadius: 1.3, yRadius: 1.3)
            stem.lineWidth = lw
            stem.stroke()
            NSBezierPath(ovalIn: NSRect(x: 3.4, y: 0.5, width: 5.2, height: 5.2)).fill()
            NSRect(x: 5.4, y: 3.6, width: 1.2, height: 4.8).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - 格子视觉风格
enum MenuBarChipStyle {
    /// 图标在左（状态色描边 + 液位填充），数值右对齐在右
    case labeled
    /// 图标放大成底图（半透明）衬在数值后面
    case watermark
    /// 状态色实底胶囊，白色图标 + 白色数值
    case badge
}

// MARK: - 配色
enum MenuBarPalette {
    static let okColor = NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1)
    static let warnColor = NSColor(srgbRed: 0.95, green: 0.50, blue: 0.13, alpha: 1)
    static let critColor = NSColor(srgbRed: 0.90, green: 0.22, blue: 0.21, alpha: 1)
    static let idleColor = NSColor(srgbRed: 0.55, green: 0.58, blue: 0.62, alpha: 1)

    /// 按阈值分级（高 = 红，中 = 橙，其余 = 绿）
    static func level(_ value: Double, warn: Double, crit: Double) -> NSColor {
        if value >= crit { return critColor }
        if value >= warn { return warnColor }
        return okColor
    }
}

// MARK: - 菜单栏定长图像
// 每个指标一个固定尺寸的「格子」（外框 + 比例填充 + 数值），
// 总宽 = 格子数 × chipWidth + 间隙，与数值大小完全无关。
// 取值参考 macOS 电池图标：外框恒定，只有内部液位和数字在变。
enum MenuBarLabelImage {
    static let chipWidth: CGFloat = 34
    static let chipGap: CGFloat = 5
    static let chipHeight: CGFloat = 15
    static let height: CGFloat = 18
    static let valueFontSize: CGFloat = 8.5
    private static let scale: CGFloat = 2

    /// 固定总宽（pt）—— 就是状态栏那一项的宽度
    static func width(chipCount: Int) -> CGFloat {
        guard chipCount > 0 else { return 0 }
        return CGFloat(chipCount) * chipWidth + CGFloat(chipCount - 1) * chipGap
    }

    static func make(_ chips: [MenuBarChip], showValues: Bool, dark: Bool,
                     style: MenuBarChipStyle = .labeled) -> NSImage {
        let total = width(chipCount: chips.count)
        let imageSize = NSSize(width: max(total, 1), height: height)
        let fallback = NSImage(size: imageSize)
        guard !chips.isEmpty else { return fallback }

        let pxW = Int((total * scale).rounded()), pxH = Int((height * scale).rounded())
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pxW, pixelsHigh: pxH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return fallback }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.cgContext.scaleBy(x: scale, y: scale)

        let textColor: NSColor = dark ? .white : .black
        var x: CGFloat = 0
        for chip in chips {
            draw(chip, at: x, showValue: showValues, textColor: textColor, dark: dark, style: style)
            x += chipWidth + chipGap
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: imageSize)
        image.addRepresentation(rep)
        image.isTemplate = false   // 彩色自绘：保留绿/橙/红分级，不走系统单色染色
        return image
    }

    private static func draw(_ chip: MenuBarChip, at x: CGFloat, showValue: Bool,
                             textColor: NSColor, dark: Bool, style: MenuBarChipStyle) {
        let frac = min(max(chip.fraction, 0), 1)
        let top = ((height - chipHeight) / 2).rounded()
        let outer = NSRect(x: x, y: top, width: chipWidth, height: chipHeight)
        let path = NSBezierPath(roundedRect: outer, xRadius: 3.5, yRadius: 3.5)

        switch style {
        case .labeled:
            // 底：状态色描边 + 电池式液位填充
            fillLevel(path: path, outer: outer, frac: frac, color: chip.color, dark: dark)
            chip.color.setStroke()
            path.lineWidth = 1
            path.stroke()
            // 左：图标（用主色，和数值同色 —— 若用状态色会和液位糊在一起）
            let iconBox = NSRect(x: outer.minX + 2.5, y: outer.midY - 6, width: 12, height: 12)
            MenuBarIcon.draw(chip.icon, in: iconBox, color: textColor, pointSize: 11.5)
            // 右：纯数值，右对齐（数值位数变化也不会改变总宽）
            guard showValue else { return }
            drawNumber(chip.text, slot: NSRect(x: outer.minX + 16, y: outer.minY,
                                               width: chipWidth - 19, height: chipHeight),
                       alignRight: true, color: textColor)
        case .watermark:
            fillLevel(path: path, outer: outer, frac: frac, color: chip.color, dark: dark)
            chip.color.setStroke()
            path.lineWidth = 1
            path.stroke()
            // 图标放大成半透明底纹
            let big = NSRect(x: outer.midX - 9, y: outer.midY - 9, width: 18, height: 18)
            MenuBarIcon.draw(chip.icon, in: big, color: textColor.withAlphaComponent(0.30),
                             lineWidth: 1.2, pointSize: 17)
            guard showValue else { return }
            drawNumber(chip.text, slot: outer, alignRight: false, color: textColor)
        case .badge:
            chip.color.withAlphaComponent(dark ? 0.88 : 0.95).setFill()
            path.fill()
            let iconBox = NSRect(x: outer.minX + 3, y: outer.midY - 5.5, width: 11, height: 11)
            MenuBarIcon.draw(chip.icon, in: iconBox, color: .white)
            guard showValue else { return }
            drawNumber(chip.text, slot: NSRect(x: outer.minX + 16, y: outer.minY,
                                               width: chipWidth - 19, height: chipHeight),
                       alignRight: true, color: .white)
        }
    }

    /// 电池式液位填充（只填在固定格子内部）
    private static func fillLevel(path: NSBezierPath, outer: NSRect, frac: Double,
                                  color: NSColor, dark: Bool) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        color.withAlphaComponent(dark ? 0.45 : 0.32).setFill()
        NSRect(x: outer.minX + 0.75, y: outer.minY + 0.75,
               width: max(0, (chipWidth - 1.5) * CGFloat(frac)), height: chipHeight - 1.5).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// 数值：过宽时自动缩字号，保证永远画在格子内部
    private static func drawNumber(_ text: String, slot: NSRect, alignRight: Bool, color: NSColor) {
        let maxWidth = slot.width
        var fontSize = valueFontSize
        var attributed = attributedText(text, size: fontSize, color: color)
        while attributed.size().width > maxWidth, fontSize > 5 {
            fontSize -= 0.5
            attributed = attributedText(text, size: fontSize, color: color)
        }
        let size = attributed.size()
        let drawX = alignRight ? slot.maxX - size.width : slot.midX - size.width / 2
        attributed.draw(at: NSPoint(x: drawX.rounded(), y: (slot.midY - size.height / 2).rounded()))
    }

    private static func attributedText(_ text: String, size: CGFloat, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold),
            .foregroundColor: color,
        ])
    }
}

// MARK: - 菜单栏文字摘要（仅用于鼠标悬停提示）
enum MenuBarText {
    static func summary(memoryPercent: Double,
                        downloadMBps: Double,
                        gpuLoad: Double,
                        tokenSpeed: Double,
                        gpuTemp: Double,
                        showTokenSpeed: Bool) -> String {
        var parts: [String] = []
        parts.append("内存 \(Int(memoryPercent.rounded()))%")
        parts.append("下载 \(String(format: "%.1f", downloadMBps)) MB/s")
        parts.append("GPU \(Int(gpuLoad.rounded()))%")
        if showTokenSpeed {
            parts.append(tokenSpeed > 0 ? String(format: "%.0f t/s", tokenSpeed) : "t/s 空闲")
        }
        parts.append(gpuTemp > 0 ? "温度 \(Int(gpuTemp.rounded()))°C" : "温度不可用")
        return parts.joined(separator: " · ")
    }
}
