import XCTest
@testable import S5TF

final class S5TFUtilsTests: XCTestCase {
    func testShell() {
        do {
            let output1 = try S5TFUtils.shell("/bin/ls", "-l", "-g")
            XCTAssertEqual(output1.status, 0)
        } catch { print(error) }

        do {
            let output2 = try S5TFUtils.shell("/bin/ls", "-lah")
            XCTAssertEqual(output2.status, 0)
        } catch { print(error) }
    }
}
