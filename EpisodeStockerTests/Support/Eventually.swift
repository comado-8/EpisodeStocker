import Foundation
import XCTest

enum Eventually {
    static func assertEventually(
        timeout: TimeInterval = 1.0,
        pollInterval: TimeInterval = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        XCTFail("Condition was not satisfied within \(timeout) seconds.", file: file, line: line)
    }
}
