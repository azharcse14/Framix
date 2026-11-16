import Flutter
import UIKit
import XCTest

@testable import Runner

/// A value whose deinit is observable, standing for an open reader or photo texture.
private final class Opened {
  let key: String
  init(_ key: String) { self.key = key }
}

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  // MARK: RecentCache (P1-098): FrameDecoder's per-media LRU

  /// Looks `keys` up in order in a cache of 2 and returns the keys that had to be made.
  private func made(_ keys: [String]) -> [String] {
    var cache = RecentCache<Opened>(capacity: 2)
    var made: [String] = []
    for key in keys {
      let value = cache.value(key) {
        made.append(key)
        return Opened(key)
      }
      XCTAssertEqual(value?.key, key)
    }
    return made
  }

  func testTwoMediaAlternatingAreMadeOnce() {
    XCTAssertEqual(made(["a", "b", "a", "b", "a", "b"]), ["a", "b"])
  }

  func testAThirdMediaEvictsTheLeastRecentlyUsed() {
    // b is the least recently used when c comes, so a stays.
    XCTAssertEqual(made(["a", "b", "a", "c", "a", "b"]), ["a", "b", "c", "b"])
  }

  func testTheEvictedEntryIsReleasedBeforeTheNewOneIsMade() {
    var cache = RecentCache<Opened>(capacity: 2)
    weak var first: Opened?
    _ = cache.value("a") {
      let opened = Opened("a")
      first = opened
      return opened
    }
    _ = cache.value("b") { Opened("b") }
    var aliveWhileMaking = true
    _ = cache.value("c") {
      aliveWhileMaking = first != nil
      return Opened("c")
    }
    XCTAssertFalse(aliveWhileMaking, "never capacity + 1 open at once")
  }

  func testAFailedMakeCachesNothing() {
    var cache = RecentCache<Opened>(capacity: 2)
    var tries = 0
    for _ in 0..<2 {
      XCTAssertNil(
        cache.value("a") {
          tries += 1
          return nil
        })
    }
    XCTAssertEqual(tries, 2)
  }
}
