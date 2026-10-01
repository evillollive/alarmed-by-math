import CoreGraphics
import SwiftUI
import XCTest
@testable import AlarmedByMath

final class ArtworkTests: XCTestCase {
    func testApprovedB3ProportionsArePreserved() {
        XCTAssertEqual(AlarmClockGeometry.bellScale, 0.65)
        XCTAssertEqual(AlarmClockGeometry.triangleScale, 0.8)
        XCTAssertEqual(AlarmClockGeometry.triangleLineWidth, 16)
        let bells = AlarmClockGeometry.bells.boundingBoxOfPath
        XCTAssertEqual(bells.minX, 120.65, accuracy: 0.001)
        XCTAssertEqual(bells.maxX, 391.35, accuracy: 0.001)
        XCTAssertEqual(bells.minY, 78.1, accuracy: 0.001)
        let triangle = AlarmClockGeometry.triangle.boundingBoxOfPath
        XCTAssertEqual(triangle.width, 97.6, accuracy: 0.001)
        XCTAssertEqual(triangle.height, 91.2, accuracy: 0.001)
        XCTAssertTrue(AlarmClockGeometry.clockBounds.contains(AlarmClockGeometry.face.boundingBoxOfPath))
        XCTAssertTrue(AlarmClockGeometry.clockBounds.contains(bells))
    }

    func testAllThreeTrianglesHaveRightAngles() {
        func points(in path: CGPath) -> [CGPoint] {
            var points: [CGPoint] = []
            path.applyWithBlock { element in
                if element.pointee.type == .moveToPoint || element.pointee.type == .addLineToPoint {
                    points.append(element.pointee.points[0])
                }
            }
            return points
        }
        func check(_ a: CGPoint, _ corner: CGPoint, _ b: CGPoint) {
            let dot = (a.x - corner.x) * (b.x - corner.x) + (a.y - corner.y) * (b.y - corner.y)
            XCTAssertEqual(dot, 0, accuracy: 0.001)
        }
        let bells = points(in: AlarmClockGeometry.bells)
        XCTAssertEqual(bells.count, 6)
        guard bells.count == 6 else { return }
        check(bells[0], bells[1], bells[2])
        check(bells[3], bells[4], bells[5])
        let triangle = points(in: AlarmClockGeometry.triangle)
        XCTAssertEqual(triangle.count, 3)
        guard triangle.count == 3 else { return }
        check(triangle[0], triangle[1], triangle[2])
    }

    func testLiveClockHandsStillShowTheCorrectTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let nine = Date(timeIntervalSince1970: 9 * 3600)
        let angles = AlarmClockGeometry.handAngles(for: nine, calendar: calendar)
        XCTAssertEqual(angles.hour, .pi, accuracy: 0.0001)
        XCTAssertEqual(angles.minute, -.pi / 2, accuracy: 0.0001)
        let quarterPastThree = Date(timeIntervalSince1970: 3 * 3600 + 15 * 60)
        let quarter = AlarmClockGeometry.handAngles(for: quarterPastThree, calendar: calendar)
        XCTAssertEqual(quarter.hour, .pi / 24, accuracy: 0.0001)
        XCTAssertEqual(quarter.minute, 0, accuracy: 0.0001)
        let noon = AlarmClockGeometry.handAngles(for: Date(timeIntervalSince1970: 12 * 3600), calendar: calendar)
        XCTAssertEqual(noon.hour, -.pi / 2, accuracy: 0.0001)
    }

    @MainActor
    func testStaticAndLiveArtworkRenderForEveryTheme() throws {
        for theme in AppTheme.allCases {
            let colors = theme.colors
            for date in [nil, Date(timeIntervalSince1970: 9 * 3600)] {
                let renderer = ImageRenderer(content: AlarmClockArtwork(
                    faceColor: colors.chalkYellow, bellColor: colors.chalk,
                    detailColor: colors.board, date: date
                ).frame(width: 128, height: 128))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.cgImage)
                XCTAssertEqual(image.width, 128)
                XCTAssertEqual(image.height, 128)
            }
        }
    }
}
