import Foundation

/// General helper functions for Swift.
public struct S5TFUtils {
    /// Run a command in the shell
    /// 
    /// - Parameters:
    ///   - `launchPath`: the path to the command.
    ///   - `parameters`: a list of parameters passed to the command.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// - Usage Example:
    ///   - Execute `ls -l -g`:
    ///     ```
    ///     shell("/bin/ls", "-l", "-g")
    ///     ```
    ///   - Execute `ls -lah`
    ///     ```
    ///     shell("/bin/ls", "-lah")
    ///     ```
    @discardableResult
    static public func shell(_ launchPath: String, _ arguments: [String]) throws -> (out: String?, status: Int32) {

        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)

        return (output, task.terminationStatus)
    }

    /// Extract a downloaded archive
    /// 
    /// - Parameters:
    ///   - `fileAtURL`: the URL for the archive.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// - Usage Example:
    ///   - Extract "archive.tgz":
    ///     ```
    ///     extract(fileAt: URL(string: "archive.tgz")!)
    ///     ```
    ///   - Extract "another_archive.gz"
    ///     ```
    ///     extract(fileAt: URL(string: "archive_archive.gz")!)
    ///     ```
    ///
    @discardableResult
    static public func extract(fileAt: URL) throws -> (out: String?, status: Int32) {
        let path = fileAt.path
        let fileExtension = fileAt.pathExtension

        #if os(macOS)
            let binary = "/usr/bin/"
        #else
            let binary = "/bin/"
        #endif

        let tool: String
        let arguments: [String]

        switch fileExtension {
            case "gz":
                tool = "gunzip"
                arguments = [path]
            case "tar.gz", "tgz":
                tool = "tar"
                arguments = ["xzf", path]
            default:
                fatalError("Unsupported file extension for archive.")
        }

        return try shell(binary+tool, arguments)
    }

    /// Download and extract an archive.
    /// 
    /// - Parameters:
    ///   - `fileAt`: the remote URL for the archive.
    ///   - `cacheName`: name of the cache.
    ///   - `fileName`: name of the file.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// - Usage Example:
    ///   - Download and extract "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz":
    ///     ```
    ///     downloadAndExtract(fileAt: URL(string: "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz")!,
    ///                        cacheName: "mnist", fileName: "train_images")
    ///     ```
    ///
    @discardableResult
    static public func downloadAndExtract(fileAt: URL, cacheName: String, fileName: String) throws -> (out: String?, status: Int32) {
        let semaphore = DispatchSemaphore(value: 0)
        var archiveURL: URL? = nil
        let downloader = Downloader()
        downloader.download(fileAt: fileAt, cacheName: cacheName, fileName: fileName) {url, error in
            guard let url = url else {
                if let error = error { print(error) }
                fatalError("Data not downloaded.")
            }
            archiveURL = url
            semaphore.signal()
        }
        semaphore.wait()

        return try extract(fileAt: archiveURL!)
    }
}
