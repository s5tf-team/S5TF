import Foundation

/// General helper functions for Swift.
public struct S5TFUtils {
    /// Run a command in the shell
    /// 
    /// - Parameters:
    ///   - `executableURL`: the path to the command as URL.
    ///   - `parameters`: a list of parameters passed to the command.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// - Usage Example:
    ///   - Execute `ls -l -g`:
    ///     ```
    ///     shell(URL(string: "/bin/ls")!, "-l", "-g")
    ///     ```
    ///   - Execute `ls -lah`
    ///     ```
    ///     shell(URL(string: "/bin/ls")!, "-lah")
    ///     ```
    @discardableResult
    static public func shell(_ executableURL: URL, _ arguments: String...) throws -> (out: String?, status: Int32) {
        let task = Process()
        task.executableURL = executableURL
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
    ///   - `archiveURL`: the URL for the archive.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// - Usage Example:
    ///   - Extract "archive.tgz":
    ///     ```
    ///     extract(archiveURL: URL(string: "archive.tgz")!, fileExtension: "tgz")
    ///     ```
    ///   - Extract "another_archive.gz"
    ///     ```
    ///     extract(archiveURL: URL(string: "archive_archive.gz")!, fileExtension: "gz")
    ///     ```
    ///
    @discardableResult
    static public func extract(archiveURL: URL, fileExtension: String) throws -> (out: String?, status: Int32) {
        
        let path = archiveURL.path

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

        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary+tool)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)

        return (output, task.terminationStatus)
    }

    @discardableResult
    static public func downloadAndExtract(fileAt: URL, cacheName: String, fileName: String, fileExtension: String) throws -> (out: String?, status: Int32) {
        let semaphore = DispatchSemaphore(value: 0)
        var archiveURL: URL? = nil
        let downloader = Downloader()
        downloader.download(fileAt: fileAt, cacheName: cacheName, fileName: fileName) {url, err in
            guard let url = url else {
                fatalError("Data not downloaded.")
            }
            archiveURL = url
            semaphore.signal()
        }
        semaphore.wait()

        do{
            return try extract(archiveURL: archiveURL!, fileExtension: fileExtension)
        } catch {
            fatalError("Unable to extract file.")
        }
    }
}
