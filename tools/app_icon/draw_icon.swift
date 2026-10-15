// Draws the Framix app icon (REL-024): two overlapping rounded frames, a photo frame and a
// film frame with sprocket holes, whose shared edges form a bold white "F".
// Usage: tools/app_icon/generate.sh (writes every iOS and Android icon file).
// Geometry is in Android's 108-unit adaptive icon space; content stays inside the 66-unit
// safe zone (21...87). Colors are design-system tokens (docs/design-system.md).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let accentFill = CGColor(srgbRed: 0x6E / 255, green: 0x4C / 255, blue: 0xF5 / 255, alpha: 1)
let onAccent = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
/// Opacity of the back parts of both frames (onAccent over accentFill).
let faintAlpha: CGFloat = 0.4

/// full: opaque iOS square; foreground: Android adaptive foreground (also its themed
/// monochrome layer); legacy: pre-adaptive Android icon with its own rounded square.
enum Layer { case full, foreground, legacy }

/// Draws one layer into `ctx`, whose user space is the 108-unit icon space (y down).
func draw(_ layer: Layer, in ctx: CGContext) {
    switch layer {
    case .full:
        ctx.setFillColor(accentFill)
        ctx.fill(CGRect(x: 0, y: 0, width: 108, height: 108))
    case .legacy:
        ctx.setFillColor(accentFill)
        ctx.addPath(CGPath(roundedRect: CGRect(x: 14, y: 14, width: 80, height: 80),
                           cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.fillPath()
    case .foreground:
        break
    }
    // Photo frame (top) and film frame (below, wider) overlap by one bold edge. The F is
    // their shared left edge (stem), the photo top (top bar) and the overlap (middle bar),
    // drawn bold in onAccent; the rest of both frames is thin and faint.
    let radius: CGFloat = 10
    let bold: CGFloat = 10
    let thin: CGFloat = 5
    let film = CGRect(x: 30, y: 46, width: 50, height: 38)
    let photo = CGRect(x: 30, y: 24, width: film.width - radius, height: film.minY + bold - 24)

    // Faint layer: drawn opaque, then composited once, so overlaps do not get brighter.
    ctx.setAlpha(faintAlpha)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setStrokeColor(onAccent)
    ctx.setFillColor(onAccent)
    ctx.setLineWidth(thin)
    for frame in [photo, film] {
        ctx.saveGState()
        if frame == photo {
            // The photo frame's bottom edge sits behind the film frame's top edge.
            ctx.clip(to: CGRect(x: 0, y: 0, width: 108, height: film.minY + thin))
        }
        ctx.addPath(CGPath(roundedRect: frame.insetBy(dx: thin / 2, dy: thin / 2),
                           cornerWidth: radius - thin / 2, cornerHeight: radius - thin / 2,
                           transform: nil))
        ctx.strokePath()
        ctx.restoreGState()
    }
    // Film strip: a bold bottom edge with sprocket holes cut out.
    let strip = CGRect(x: film.minX, y: film.maxY - bold, width: film.width, height: bold)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: film, cornerWidth: radius, cornerHeight: radius,
                       transform: nil))
    ctx.clip()
    ctx.fill(strip)
    ctx.restoreGState()
    ctx.setBlendMode(.clear)
    for i in 0..<4 {
        let hole = CGRect(x: film.minX + bold + 5 + CGFloat(i) * 8.5, y: strip.midY - 2,
                          width: 4.5, height: 4)
        ctx.addPath(CGPath(roundedRect: hole, cornerWidth: 1.2, cornerHeight: 1.2,
                           transform: nil))
    }
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    ctx.endTransparencyLayer()
    ctx.setAlpha(1)

    let f = CGMutablePath()
    f.move(to: CGPoint(x: photo.minX, y: film.maxY))
    f.addLine(to: CGPoint(x: photo.minX, y: photo.minY + radius))
    f.addArc(tangent1End: CGPoint(x: photo.minX, y: photo.minY),
             tangent2End: CGPoint(x: photo.minX + radius, y: photo.minY), radius: radius)
    f.addLine(to: CGPoint(x: photo.maxX - radius, y: photo.minY))
    f.addLine(to: CGPoint(x: photo.maxX - radius, y: photo.minY + bold))
    f.addLine(to: CGPoint(x: photo.minX + bold, y: photo.minY + bold))
    f.addLine(to: CGPoint(x: photo.minX + bold, y: film.minY))
    f.addLine(to: CGPoint(x: photo.maxX - radius - 6, y: film.minY))
    f.addLine(to: CGPoint(x: photo.maxX - radius - 6, y: film.minY + bold))
    f.addLine(to: CGPoint(x: photo.minX + bold, y: film.minY + bold))
    f.addLine(to: CGPoint(x: photo.minX + bold, y: film.maxY))
    f.closeSubpath()
    ctx.setFillColor(onAccent)
    ctx.addPath(f)
    ctx.fillPath()
}

/// Renders `layer` at `px` pixels square, mapping the icon-space `viewport` onto the canvas.
func render(_ layer: Layer, px: Int, viewport: CGRect, to url: URL) {
    let opaque = layer == .full
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                              bytesPerRow: 0, space: space,
                              bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast
                                                  : .premultipliedLast).rawValue) else {
        fatalError("cannot create a \(px)px context")
    }
    let scale = CGFloat(px) / viewport.width
    ctx.translateBy(x: 0, y: CGFloat(px))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.translateBy(x: -viewport.minX, y: -viewport.minY)
    draw(layer, in: ctx)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil)
    else { fatalError("cannot write \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("cannot finalize \(url.path)") }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let whole = CGRect(x: 0, y: 0, width: 108, height: 108)
// iOS masks the full square with no safe-zone margin, so it shows a tighter crop.
render(.full, px: 1024, viewport: whole.insetBy(dx: 12, dy: 12),
       to: out.appendingPathComponent("ios_1024.png"))
render(.foreground, px: 432, viewport: whole, to: out.appendingPathComponent("foreground.png"))
render(.legacy, px: 192, viewport: whole.insetBy(dx: 12, dy: 12),
       to: out.appendingPathComponent("legacy.png"))
