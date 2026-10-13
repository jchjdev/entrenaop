import CoreHaptics
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testEveryCueIsFiniteAndShort() throws {
    for cue in ["preparationTick", "workEndingTick", "halfway", "tenSecondsRemaining",
                "workStarted", "workFinished", "restFinished"] {
      let pattern = try WorkoutVibration.pattern(for: cue)
      XCTAssertGreaterThan(pattern.duration, 0)
      XCTAssertLessThanOrEqual(pattern.duration, 0.5)
    }
  }

  func testFinishHasTwoSeparateHapticPulsesWithoutAudio() throws {
    for cue in ["workFinished", "restFinished"] {
      let pattern = try WorkoutVibration.pattern(for: cue)
      XCTAssertEqual(pattern.duration, 0.420, accuracy: 0.0001)
      let exported = try pattern.exportDictionary()
      let entries = try XCTUnwrap(exported[.pattern] as? [[String: Any]])
      let events = try entries.map { try XCTUnwrap($0["Event"] as? [String: Any]) }
      XCTAssertEqual(events.count, 2)
      XCTAssertEqual(events[0]["EventType"] as? String, "HapticContinuous")
      XCTAssertEqual(events[1]["EventType"] as? String, "HapticContinuous")
      XCTAssertEqual(try XCTUnwrap(events[0]["Time"] as? Double), 0, accuracy: 0.0001)
      XCTAssertEqual(try XCTUnwrap(events[1]["Time"] as? Double), 0.260, accuracy: 0.0001)
    }
  }

  func testUnknownCueIsRejected() {
    XCTAssertThrowsError(try WorkoutVibration.pattern(for: "unknown"))
  }
}
