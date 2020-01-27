import XCTest
@testable import S5TF

final class S5TFDownloaderTests: XCTestCase {
    func testAsyncDownloader() {
        let semaphore = DispatchSemaphore(value: 0)
        let downloader = Downloader()
        var localURL: URL?
        downloader.download(
            fileAt: URL(string: "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz")!,
            cacheName: "mnist",
            fileName: "train-images.gz"
        ) { url, error in
            guard let url = url else {
                if let error = error { print(error) }
                fatalError("Data not downloaded.")
            }
            localURL = url
            semaphore.signal()
        }
        semaphore.wait()
        XCTAssertNotNil(localURL)

        // Delete file after we are done.
        try! FileManager.default.removeItem(atPath: localURL!.absoluteString)
    }

    func testSyncDownloader() {
        let localURL = Downloader.download(
            fileAt: URL(string: "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz")!,
            cacheName: "mnist",
            fileName: "train-images.gz"
        )
        XCTAssertNotNil(localURL)

        // Delete file after we are done.
        try! FileManager.default.removeItem(atPath: localURL!.absoluteString)
    }
}
