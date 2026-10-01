import CoreGraphics
import Foundation
import SwiftUI

/// Geometry shared by the app, widget, and icon export tool.
enum AlarmClockGeometry {
    static let canvas = CGRect(x: 0, y: 0, width: 512, height: 512)
    static let clockBounds = CGRect(x: 104, y: 76, width: 304, height: 362)
    static let center = CGPoint(x: 256, y: 286)
    static let triangleLineWidth: CGFloat = 16
    static let bellScale: CGFloat = 0.65
    static let triangleScale: CGFloat = 0.8

    static var face: CGPath {
        CGPath(ellipseIn: CGRect(x: 104, y: 134, width: 304, height: 304), transform: nil)
    }

    static var bells: CGPath {
        let path = CGMutablePath()
        addTriangle(
            to: path, points: [CGPoint(x: 72, y: 155), CGPoint(x: 118, y: 62), CGPoint(x: 211, y: 108)],
            around: CGPoint(x: 211, y: 108), scale: bellScale
        )
        addTriangle(
            to: path, points: [CGPoint(x: 440, y: 155), CGPoint(x: 394, y: 62), CGPoint(x: 301, y: 108)],
            around: CGPoint(x: 301, y: 108), scale: bellScale
        )
        return path
    }

    static var triangle: CGPath {
        let path = CGMutablePath()
        addTriangle(
            to: path, points: [CGPoint(x: 215, y: 210), CGPoint(x: 215, y: 324), CGPoint(x: 337, y: 324)],
            around: center, scale: triangleScale
        )
        return path
    }

    static func handAngles(for date: Date, calendar: Calendar = .current) -> (hour: Double, minute: Double) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0).truncatingRemainder(dividingBy: 12)
        let minute = Double(components.minute ?? 0)
        return ((hour + minute / 60) * .pi / 6 - .pi / 2, minute * .pi / 30 - .pi / 2)
    }

    static func hand(length: CGFloat, angle: Double) -> CGPath {
        let path = CGMutablePath()
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + length * cos(angle), y: center.y + length * sin(angle)))
        return path
    }

    private static func addTriangle(to path: CGMutablePath, points: [CGPoint], around anchor: CGPoint, scale: CGFloat) {
        path.addLines(between: points.map {
            CGPoint(x: anchor.x + ($0.x - anchor.x) * scale, y: anchor.y + ($0.y - anchor.y) * scale)
        })
        path.closeSubpath()
    }
}

struct AlarmClockArtwork: View {
    let faceColor: Color
    let bellColor: Color
    let detailColor: Color
    var date: Date? = nil

    var body: some View {
        Canvas { context, size in
            let bounds = date == nil ? AlarmClockGeometry.canvas : AlarmClockGeometry.clockBounds
            let scale = min(size.width / bounds.width, size.height / bounds.height)
            context.translateBy(
                x: (size.width - bounds.width * scale) / 2,
                y: (size.height - bounds.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            context.fill(Path(AlarmClockGeometry.bells), with: .color(bellColor))
            context.fill(Path(AlarmClockGeometry.face), with: .color(faceColor))
            if let date {
                let angles = AlarmClockGeometry.handAngles(for: date)
                context.stroke(
                    Path(AlarmClockGeometry.hand(length: 72, angle: angles.hour)),
                    with: .color(detailColor), style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                context.stroke(
                    Path(AlarmClockGeometry.hand(length: 108, angle: angles.minute)),
                    with: .color(detailColor), style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: 247, y: 277, width: 18, height: 18)),
                    with: .color(detailColor)
                )
            } else {
                context.stroke(
                    Path(AlarmClockGeometry.triangle), with: .color(detailColor),
                    style: StrokeStyle(lineWidth: AlarmClockGeometry.triangleLineWidth, lineJoin: .round)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
