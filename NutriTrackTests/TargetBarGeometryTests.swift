import XCTest
@testable import NutriTrack

final class TargetBarGeometryTests: XCTestCase {

    func testTheTargetSitsBelowTheEndOfTheTrack() {
        let empty = TargetBarGeometry.make(value: 0, target: 100)
        XCTAssertEqual(empty.fill, 0)
        XCTAssertEqual(empty.tick ?? 0, 1 / 1.2, accuracy: 0.0001)

        let reached = TargetBarGeometry.make(value: 100, target: 100)
        XCTAssertEqual(reached.fill, 1 / 1.2, accuracy: 0.0001)
    }

    func testTheFillStopsAtTheEndOfTheTrack() {
        XCTAssertEqual(TargetBarGeometry.make(value: 300, target: 100).fill, 1)
        XCTAssertEqual(TargetBarGeometry.make(value: -5, target: 100).fill, 0)
    }

    func testAZoneBetweenFloorAndCeiling() {
        let bar = TargetBarGeometry.make(value: 100, floor: 50, ceiling: 100)
        XCTAssertEqual(bar.zone?.lowerBound ?? 0, 50 / 120, accuracy: 0.0001)
        XCTAssertEqual(bar.zone?.upperBound ?? 0, 100 / 120, accuracy: 0.0001)
        XCTAssertFalse(bar.isOver)
        XCTAssertNil(bar.tick)
        XCTAssertTrue(TargetBarGeometry.make(value: 110, floor: 50, ceiling: 100).isOver)
    }

    func testAFloorWithoutACeilingHasNoZone() {
        let bar = TargetBarGeometry.make(value: 30, target: 60, floor: 60)
        XCTAssertNil(bar.zone)
        XCTAssertFalse(bar.isOver)
    }

    func testWithoutAnyReferenceTheBarIsFullOrEmpty() {
        XCTAssertEqual(TargetBarGeometry.make(value: 5), TargetBarGeometry(fill: 1, tick: nil, zone: nil, isOver: false))
        XCTAssertEqual(TargetBarGeometry.make(value: 0).fill, 0)
        XCTAssertEqual(TargetBarGeometry.make(value: 5, target: 0).fill, 1)
    }

    func testSegments() {
        XCTAssertEqual(TargetBarGeometry(fill: 0.53, tick: nil, zone: nil, isOver: false).filledSegments(of: 20), 11)
        XCTAssertEqual(TargetBarGeometry(fill: 0.01, tick: nil, zone: nil, isOver: false).filledSegments(of: 20), 1)
        XCTAssertEqual(TargetBarGeometry(fill: 0, tick: nil, zone: nil, isOver: false).filledSegments(of: 20), 0)
        XCTAssertEqual(TargetBarGeometry(fill: 1, tick: nil, zone: nil, isOver: false).filledSegments(of: 20), 20)
    }

    func testRangePutsTheFloorAtSixtyPercent() {
        let geometry = TargetBarGeometry.range(value: 8, floor: 8, ceiling: 45)
        XCTAssertEqual(geometry.fill, 0.6, accuracy: 0.0001)
        XCTAssertEqual(geometry.zone, 0.6...0.9)
        XCTAssertNil(geometry.tick)
        XCTAssertFalse(geometry.isOver)
    }

    func testRangeBelowTheFloorIsProportional() {
        XCTAssertEqual(TargetBarGeometry.range(value: 4, floor: 8, ceiling: 45).fill, 0.3, accuracy: 0.0001)
        XCTAssertEqual(TargetBarGeometry.range(value: -3, floor: 8, ceiling: 45).fill, 0)
    }

    func testRangeInsideTheZoneIsProportional() {
        let geometry = TargetBarGeometry.range(value: 20, floor: 10, ceiling: 30)
        XCTAssertEqual(geometry.fill, 0.75, accuracy: 0.0001)
        XCTAssertFalse(geometry.isOver)
    }

    func testRangeAboveTheCeilingIsOverAndCapped() {
        let justOver = TargetBarGeometry.range(value: 33, floor: 10, ceiling: 30)
        XCTAssertEqual(justOver.fill, 0.91, accuracy: 0.0001)
        XCTAssertTrue(justOver.isOver)
        XCTAssertEqual(TargetBarGeometry.range(value: 500, floor: 10, ceiling: 30).fill, 1)
    }

    func testRangeWithoutAFloorIsALimitBar() {
        XCTAssertEqual(TargetBarGeometry.range(value: 36, floor: 0, ceiling: 72),
                       TargetBarGeometry.make(value: 36, target: 72, ceiling: 72))
    }

    func testMinimumZoneRunsFromTheMinimumToTheTarget() {
        let geometry = TargetBarGeometry.make(value: 100, target: 300, minimum: 230)
        XCTAssertEqual(geometry.fill, 100 / 360, accuracy: 0.0001)
        XCTAssertEqual(geometry.tick ?? 0, 300 / 360, accuracy: 0.0001)
        XCTAssertEqual(geometry.zone?.lowerBound ?? 0, 230 / 360, accuracy: 0.0001)
        XCTAssertEqual(geometry.zone?.upperBound ?? 0, 300 / 360, accuracy: 0.0001)
    }

    func testMinimumZoneIsNeverOver() {
        let geometry = TargetBarGeometry.make(value: 400, target: 300, minimum: 230)
        XCTAssertFalse(geometry.isOver)
        XCTAssertEqual(geometry.fill, 1)
    }

    func testMinimumAtOrAboveTheTargetGivesNoZone() {
        XCTAssertNil(TargetBarGeometry.make(value: 100, target: 300, minimum: 300).zone)
        XCTAssertNil(TargetBarGeometry.make(value: 100, target: 300, minimum: 0).zone)
    }
}
