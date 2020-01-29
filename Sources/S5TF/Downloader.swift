import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Downloader: A helper class to download files.
public class Downloader: NSObject {
    private lazy var session = URLSession(configuration: .default,
                                          delegate: self,
                                          delegateQueue: nil)

    private var saveURL: URL?
    private var completionHandler: ((URL?, Error?) -> Void)?
    private var startingTime: Date?

    private var baseURL: URL = {
        // Create the base directory in the users home directory if non-existent.
        let home = URL(string: NSHomeDirectory())!
        let baseURL = home.appendingPathComponent(".s5tf-datasets")
        if !FileManager.default.fileExists(atPath: baseURL.absoluteString) {
            // Force the creation because if we can't create the path, something is
            // seriously wrong.
            // swiftlint:disable:next force_try
            try! FileManager.default.createDirectory(atPath: baseURL.absoluteString,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
        }
        return baseURL
    }()

    /// Downloads a file asynchronously.
    ///
    /// - Parameters:
    ///   - `fileAt`: the remote url
    ///   - `cacheName`: the directory in the base directory where the file will be saved. This
    ///                  directory should be consistent with subsequent requests to enable caching.
    ///   - `fileName`: the desired file name of the local file.
    ///   - `completionHandler`: will be called upon completion. First item might be the local path,
    ///                          second item might be an error. If the item can't be saved to the local
    ///                          url an error will be returned.
    ///
    /// ### Usage Example: ###
    ///
    /// - Download MNIST files:
    ///
    ///   ````
    ///   let semaphore = DispatchSemaphore(value: 0)
    ///   let downloader = Downloader()
    ///   var localURL: URL?
    ///   downloader.download(
    ///       fileAt: URL(string: "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz")!,
    ///       cacheName: "mnist",
    ///       fileName: "train-images.gz"
    ///   ) { url, error in
    ///       guard let url = url else {
    ///           if let error = error { print(error) }
    ///           fatalError("Data not downloaded.")
    ///       }
    ///       localURL = url
    ///       semaphore.signal()
    ///   }
    ///   semaphore.wait()
    ///   // Use the URL here.
    ///   ````
    public func download(fileAt remoteUrl: URL,
                         cacheName: String,
                         fileName: String,
                         completionHandler: @escaping (URL?, Error?) -> Void) {
        print("Downloading: \(remoteUrl)")

        // Create a cache directory if non-existent.
        let cacheURL = baseURL.appendingPathComponent(cacheName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: cacheURL.absoluteString) {
            // It's the users responsibility to check whether they can save to
            // the directory. If an error occurs, it will be visible to the user.
            // swiftlint:disable:next force_try
            try! FileManager.default.createDirectory(atPath: cacheURL.absoluteString,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
        }

        // Check whether the file is already downloaded.
        let saveURL = cacheURL.appendingPathComponent(fileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: saveURL.absoluteString) {
            print("Found cached version at: \(saveURL)")
            completionHandler(saveURL, nil)
            return
        } else {
            self.saveURL = saveURL
        }

        session.downloadTask(with: remoteUrl).resume()
        self.completionHandler = completionHandler
        startingTime = Date()
    }

    /// Downloads a file synchronously.
    ///
    /// - Parameters:
    ///   - `fileAt`: the remote url
    ///   - `cacheName`: the directory in the base directory where the file will be saved. This
    ///                  directory should be consistent with subsequent requests to enable caching.
    ///   - `fileName`: the desired file name of the local file.
    ///
    /// ### Usage Example: ###
    ///
    /// - Download MNIST files:
    ///
    ///   ```
    ///   let localURL = Downloader.download(
    ///       fileAt: URL(string: "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz")!,
    ///       cacheName: "mnist",
    ///       fileName: "train-images.gz"
    ///   )
    ///   // Use the URL here.
    ///   ```
    static public func download(fileAt remoteUrl: URL,
                                cacheName: String,
                                fileName: String) -> URL? {
        let semaphore = DispatchSemaphore(value: 0)
        let downloader = Downloader()
        var localURL: URL?
        downloader.download(fileAt: remoteUrl,
                            cacheName: cacheName,
                            fileName: fileName) { url, error in
            guard let url = url else {
                if let error = error { print(error) }
                fatalError("Data not downloaded.")
            }
            localURL = url
            semaphore.signal()
        }
        semaphore.wait()
        return localURL
    }
}

extension Downloader: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)

        // Generate a progress bar.
        let totalProgressBarWidth = 40
        let progressBarWidth = Int(progress * Float(totalProgressBarWidth))
        let progressBar = "[" + String(repeating: "-", count: progressBarWidth) +
                           String(repeating: " ", count: totalProgressBarWidth - progressBarWidth) + "]"

        // Calculate ETA.
        let eta: Any
        if let startingTime = startingTime {
            let now = Date()
            let elapsedTime = Float(now.timeIntervalSince(startingTime)) // In seconds.
            eta = Int((1 - progress) / (progress / elapsedTime))
        } else { eta = "Not Available"}

        // Create bar. Append an empty string to the end. This avoids a bug where shorter strings (decreasing ETA)
        // would partly keep the output of the previous print.
        let bar = "\(progressBar) \(Int(progress*100))% ETA: \(eta)s" + String(repeating: " ", count: 10)

        // Replace the pervious line with the new info.
        fflush(stdout)
        print(bar, terminator: "\r")
    }

    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        print() // Keep the progress bar.
        // Move the file to the desired local URL.
        guard let saveURL = self.saveURL else {
            fatalError("Done downloading, but I don't know where to move the file. ")
        }

        do {
            try FileManager.default.moveItem(at: location, to: URL(string: "file://"+saveURL.absoluteString)!)
            self.completionHandler?(saveURL, nil)
            self.saveURL = nil
            startingTime = nil
        } catch {
            completionHandler?(nil, error)
        }
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        // Both `didFinishDownloadingTo` and `didCompleteWithError` are called, so we have to make sure
        // we have an error before we continue.
        guard let error = error else {
            return
        }

        completionHandler?(nil, error)
    }
}
