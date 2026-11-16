// Draws the Groovey app icon and writes AppIcon.appiconset.
// Usage: swift scripts/make-icon.swift Groovey/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <AppIcon.appiconset>\n".utf8))
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: size / 1024, y: size / 1024)

    // macOS icon grid: an 824pt rounded square centred on a 1024pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    context.addPath(tilePath)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let background = CGGradient(colorsSpace: space, colors: [
        NSColor(red: 1.00, green: 0.72, blue: 0.38, alpha: 1).cgColor,
        NSColor(red: 0.86, green: 0.36, blue: 0.16, alpha: 1).cgColor,
        NSColor(red: 0.42, green: 0.14, blue: 0.08, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 0.55, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Record.
    let center = CGPoint(x: 512, y: 500)
    func circle(_ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    context.setFillColor(NSColor(white: 0.06, alpha: 1).cgColor)
    context.fillEllipse(in: circle(318))
    context.restoreGState()

    var radius: CGFloat = 132
    var index = 0
    while radius < 310 {
        let gap = index % 9 == 8
        context.setStrokeColor(NSColor(white: gap ? 0 : 1, alpha: gap ? 0.7 : 0.07).cgColor)
        context.setLineWidth(gap ? 4 : 1.6)
        context.strokeEllipse(in: circle(radius))
        radius += 7
        index += 1
    }

    // Two soft highlights across the grooves.
    context.saveGState()
    context.addEllipse(in: circle(318))
    context.addEllipse(in: circle(126))
    context.clip(using: .evenOdd)
    for angle in [CGFloat.pi * 0.28, CGFloat.pi * 1.28] {
        let wedge = CGMutablePath()
        wedge.move(to: center)
        wedge.addArc(center: center, radius: 330, startAngle: angle - 0.2, endAngle: angle + 0.2, clockwise: false)
        wedge.closeSubpath()
        context.addPath(wedge)
        context.setFillColor(NSColor.white.withAlphaComponent(0.13).cgColor)
        context.fillPath()
    }
    context.restoreGState()

    // Label.
    let label = CGGradient(colorsSpace: space, colors: [
        NSColor(red: 1.0, green: 0.92, blue: 0.74, alpha: 1).cgColor,
        NSColor(red: 0.98, green: 0.74, blue: 0.42, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    context.saveGState()
    context.addEllipse(in: circle(120))
    context.clip()
    context.drawLinearGradient(label, start: CGPoint(x: 512, y: 620), end: CGPoint(x: 512, y: 380), options: [])
    context.restoreGState()
    context.setStrokeColor(NSColor(red: 0.42, green: 0.14, blue: 0.08, alpha: 0.5).cgColor)
    context.setLineWidth(5)
    context.strokeEllipse(in: circle(84))
    context.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor)
    context.fillEllipse(in: circle(17))

    // Tonearm.
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 14, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    let pivot = CGPoint(x: 790, y: 790)
    let stylus = CGPoint(x: 640, y: 470)
    context.setStrokeColor(NSColor(white: 0.93, alpha: 1).cgColor)
    context.setLineWidth(24)
    context.setLineCap(.round)
    context.move(to: pivot)
    context.addLine(to: stylus)
    context.strokePath()
    context.setFillColor(NSColor(white: 0.96, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: pivot.x - 48, y: pivot.y - 48, width: 96, height: 96))
    context.setFillColor(NSColor(white: 0.16, alpha: 1).cgColor)
    context.saveGState()
    context.translateBy(x: stylus.x, y: stylus.y)
    context.rotate(by: atan2(stylus.y - pivot.y, stylus.x - pivot.x))
    context.addPath(CGPath(roundedRect: CGRect(x: -24, y: -30, width: 84, height: 60), cornerWidth: 12, cornerHeight: 12, transform: nil))
    context.fillPath()
    context.restoreGState()

    context.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

struct Slot { let points: Int; let scale: Int }
let slots = [16, 32, 128, 256, 512].flatMap { [Slot(points: $0, scale: 1), Slot(points: $0, scale: 2)] }
var images: [[String: String]] = []
for slot in slots {
    let name = "icon_\(slot.points)x\(slot.points)\(slot.scale == 2 ? "@2x" : "").png"
    try drawIcon(pixels: slot.points * slot.scale).write(to: output.appendingPathComponent(name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(slot.scale)x", "size": "\(slot.points)x\(slot.points)"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(slots.count) icons to \(output.path)")
