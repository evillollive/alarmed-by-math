import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct GenerateAppIcons {
    struct Palette {
        let background: String
        let face: String
        let bells: String
    }

    static let standard = Palette(background: "102b24", face: "f7cf63", bells: "f5f0d9")
    static let dark = Palette(background: "071914", face: "f7cf63", bells: "f5f0d9")
    static let tinted = Palette(background: "000000", face: "ffffff", bells: "cccccc")

    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
        let icons = root.appendingPathComponent("AlarmedByMath/Assets.xcassets/AppIcon.appiconset")
        let docs = root.appendingPathComponent("docs/assets")
        guard FileManager.default.fileExists(atPath: icons.path) else {
            throw ExportError.invalidRoot
        }
        try exportPNG(to: icons.appendingPathComponent("AppIcon.png"), palette: standard)
        try exportPNG(to: icons.appendingPathComponent("AppIconDark.png"), palette: dark)
        try exportPNG(to: icons.appendingPathComponent("AppIconTinted.png"), palette: tinted)
        try markSVG().write(to: docs.appendingPathComponent("chalkboard-mark.svg"), atomically: true, encoding: .utf8)
        try logoSVG(darkPage: false).write(to: docs.appendingPathComponent("logo.svg"), atomically: true, encoding: .utf8)
        try logoSVG(darkPage: true).write(to: docs.appendingPathComponent("logo-dark.svg"), atomically: true, encoding: .utf8)
        let demoURL = docs.appendingPathComponent("demo-preview.svg")
        var demo = try String(contentsOf: demoURL, encoding: .utf8)
        guard let start = demo.range(of: "<!-- brand-mark:start -->"),
              let end = demo.range(of: "<!-- brand-mark:end -->"),
              start.upperBound <= end.lowerBound else { throw ExportError.missingBrandMarker }
        let demoMark = "\n    <g transform=\"translate(-2 -4) scale(.095)\">\n      \(svgShapes())\n    </g>\n    "
        demo.replaceSubrange(start.upperBound..<end.lowerBound, with: demoMark)
        try demo.write(to: demoURL, atomically: true, encoding: .utf8)
        print("Exported three opaque 1024px app icons and matching SVG artwork from shared B3 geometry.")
    }

    private static func color(_ hex: String) throws -> CGColor {
        guard let value = UInt32(hex, radix: 16),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let color = CGColor(colorSpace: space, components: [
                CGFloat((value >> 16) & 255) / 255,
                CGFloat((value >> 8) & 255) / 255,
                CGFloat(value & 255) / 255, 1
              ]) else { throw ExportError.invalidColor }
        return color
    }

    private static func exportPNG(to url: URL, palette: Palette) throws {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                bytesPerRow: 1024 * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { throw ExportError.renderFailed }
        context.translateBy(x: 0, y: 1024)
        context.scaleBy(x: 2, y: -2)
        context.setFillColor(try color(palette.background))
        context.fill(AlarmClockGeometry.canvas)
        context.setFillColor(try color(palette.bells))
        context.addPath(AlarmClockGeometry.bells)
        context.fillPath()
        context.setFillColor(try color(palette.face))
        context.addPath(AlarmClockGeometry.face)
        context.fillPath()
        context.setStrokeColor(try color(palette.background))
        context.setLineWidth(AlarmClockGeometry.triangleLineWidth)
        context.setLineJoin(.round)
        context.addPath(AlarmClockGeometry.triangle)
        context.strokePath()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw ExportError.renderFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.renderFailed }
    }

    private static func svgPath(_ path: CGPath) -> String {
        func point(_ point: CGPoint) -> String {
            String(format: "%.3f %.3f", locale: Locale(identifier: "en_US_POSIX"), Double(point.x), Double(point.y))
        }
        var parts: [String] = []
        path.applyWithBlock { element in
            let value = element.pointee
            switch value.type {
            case .moveToPoint: parts.append("M\(point(value.points[0]))")
            case .addLineToPoint: parts.append("L\(point(value.points[0]))")
            case .addQuadCurveToPoint:
                parts.append("Q\(point(value.points[0])) \(point(value.points[1]))")
            case .addCurveToPoint:
                parts.append("C\(point(value.points[0])) \(point(value.points[1])) \(point(value.points[2]))")
            case .closeSubpath: parts.append("Z")
            @unknown default: preconditionFailure("Unsupported path element")
            }
        }
        return parts.joined(separator: " ")
    }

    private static func svgShapes() -> String {
        """
        <path d="\(svgPath(AlarmClockGeometry.bells))" fill="#\(standard.bells)"/>
        <path d="\(svgPath(AlarmClockGeometry.face))" fill="#\(standard.face)"/>
        <path d="\(svgPath(AlarmClockGeometry.triangle))" fill="none" stroke="#\(standard.background)" stroke-width="16" stroke-linejoin="round"/>
        """
    }

    private static func markSVG() -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 512 512" role="img" aria-labelledby="title description">
          <title id="title">Alarmed by Math</title>
          <desc id="description">A golden alarm clock with small cream right-triangle bells and a right triangle inside its face.</desc>
          <rect width="512" height="512" rx="112" fill="#\(standard.background)"/>
          \(svgShapes())
        </svg>

        """
    }

    private static func logoSVG(darkPage: Bool) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 72" role="img" aria-label="Alarmed by Math">
          <g transform="translate(4 4) scale(.125)">
            <rect width="512" height="512" rx="112" fill="#\(standard.background)"/>
            \(svgShapes())
          </g>
          <text x="82" y="46" font-family="ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif" font-size="27" font-weight="600" fill="#\(darkPage ? standard.bells : standard.background)">Alarmed by Math</text>
        </svg>

        """
    }

    enum ExportError: Error {
        case invalidRoot
        case invalidColor
        case renderFailed
        case missingBrandMarker
    }
}
