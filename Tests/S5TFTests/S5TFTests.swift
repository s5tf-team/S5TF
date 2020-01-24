import XCTest
@testable import S5TF

final class S5TFTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(S5TF().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
