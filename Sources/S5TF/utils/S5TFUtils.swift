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
    static public func shell(_ launchPath: String, _ arguments: String...) throws -> (out: String?, status: Int32) {
        return try shell(launchPath, arguments)
    }

    /// Run a command in the shell.
    ///
    /// Wrapper for shell(_ launchPath: String, arguments: String...) because splatting is not supported in Swift.
    /// See https://bugs.swift.org/browse/SR-128 for more details.
    ///
    /// - Parameters:
    ///   - `launchPath`: the path to the command.
    ///   - `arguments`: a list of arguments passed to the command.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// - Usage Example:
    ///   - Execute `ls -l -g`:
    ///     ```
    ///     shell("/bin/ls", ["-l", "-g"])`
    ///     ```
    ///   - Execute `ls -lah`
    ///     ```
    ///     shell("/bin/ls", ["-lah"])`
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
    static public func extract(archiveURL: URL) -> URL {
        let path = archiveURL.path
        let fileExtension = archiveURL.pathExtension

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
        if !FileManager.default.fileExists(atPath: archiveURL.absoluteString.deletingPathExtension) {
            do {
                try shell(binary + tool, arguments)
            } catch {
                fatalError("Error extracting file.")
            }
        }

        return URL(string: archiveURL.absoluteString.deletingPathExtension)!
    }

    /// Download and extract an archive.
    /// 
    /// - Parameters:
    ///   - `remoteURL`: the remote URL for the archive.
    ///   - `cacheName`: name of the cache.
    ///   - `fileName`: name of the file.
    ///
    /// - Returns: URL of extracted archive.
    ///
    /// - Usage Example:
    ///   - Download and extract "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz":
    ///     ```
    ///     downloadAndExtract(remoteURL: URL(string: "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz")!,
    ///                        cacheName: "mnist", fileName: "train_images")
    ///     ```
    ///
    @discardableResult
    static public func downloadAndExtract(remoteURL: URL, cacheName: String, fileName: String) -> URL? {
        let archiveURL = Downloader.download(fileAt: remoteURL,
                                             cacheName: cacheName,
                                             fileName: fileName)
        return extract(archiveURL: archiveURL!)
    }
}
