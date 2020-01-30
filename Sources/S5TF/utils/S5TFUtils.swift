import Foundation

/// General helper functions for Swift.
public struct S5TFUtils {
    /// Run a command in the shell.
    /// 
    /// - Parameters:
    ///   - `launchPath`: the path to the command.
    ///   - `parameters`: a list of parameters passed to the command.
    ///
    /// - Returns: Output, termination status of the command.
    ///
    /// ### Usage Example: ###
    ///
    ///  - Execute `ls -l -g`:
    ///
    ///    ````
    ///    shell("/bin/ls", "-l", "-g")
    ///    ````
    ///
    ///  - Execute `ls -lah`
    ///
    ///    ````
    ///    shell("/bin/ls", "-lah")
    ///    ````
    @discardableResult
    static public func shell(_ launchPath: String, _ arguments: String...) throws -> (out: String?, status: Int32) {
        return try shell(launchPath, arguments)
    }

    /// Run a command in the shell.
    ///
    /// Wrapper for `shell(_ launchPath: String, arguments: String...)` because splatting is not supported in Swift.
    /// See https://bugs.swift.org/browse/SR-128 for more details.
    ///
    /// - Parameters:
    ///   - `launchPath`: The path to the command.
    ///   - `paramters`: A list of paramters passed to the command.
    ///
    /// - Returns: Output, termination status of the command.
    ///
    /// - Usage Example:
    ///
    ///   - Execute `ls -l -g`:
    ///
    ///     ````
    ///     shell("/bin/ls", ["-l", "-g"])
    ///     ````
    ///
    ///   - Execute `ls -lah`
    ///
    ///     ````
    ///     shell("/bin/ls", ["-lah"])
    ///     ````
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
    /// Supported file extensions:
    /// - `.gz`
    /// - `.tgz`
    ///
    /// - Parameters:
    ///   - `fileAtURL`: the URL for the archive.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// ### Usage Example: ###
    ///
    /// - Extract `archive.tgz`:
    ///
    ///   ```
    ///   extract(fileAt: URL(string: "archive.tgz")!)
    ///   ```
    ///
    /// - Extract `another_archive.gz`
    ///
    ///   ```
    ///   extract(fileAt: URL(string: "archive_archive.gz")!)
    ///   ```
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
        if !FileManager.default.fileExists(atPath: archiveURL.deletingPathExtension().absoluteString) {
            do {
                try shell(binary + tool, arguments)
            } catch {
                fatalError("Error extracting file.")
            }
        }

        return archiveURL.deletingPathExtension()
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
    /// ### Usage Example: ###
    ///
    /// - Download and extract "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz":
    ///
    ///   ```
    ///   downloadAndExtract(remoteURL: URL(string: "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz")!,
    ///                      cacheName: "mnist", fileName: "train_images")
    ///   ```
    static public func downloadAndExtract(remoteURL: URL, cacheName: String, fileName: String) -> URL? {
        guard let archiveURL = Downloader.download(fileAt: remoteURL,
                                                   cacheName: cacheName,
                                                   fileName: fileName) else {
                                                       fatalError("File could not be downloaded.")
        }
        return extract(archiveURL: archiveURL)
    }

    /// Create a data loader from a comma seperated value (CSV) file.
    ///
    /// - Parameters:
    ///   - at path: The path of the csv file.
    ///   - columnNames: The columns of the csv file to load. If no column names
    ///                  are supplied the items in the first row are intperted as column names.
    ///
    /// - Returns:
    ///   - An array of an array where the inner array represents a single row and the outer
    ///     array contains the rows. All values are Strings.
    ///   - An array of column names.
    public static func readCSV(at path: String, columnNames: [String]? = nil) -> ([[String]], [String]) {
        // Validate file exists.
        guard FileManager.default.fileExists(atPath: path) else {
            fatalError("File not found at \(path).")
        }

        // Load data from disk.
        guard let rawData = try? String(contentsOfFile: path) else {
            fatalError("Data at \(path) could not be loaded.")
        }
        var rows = rawData.split(separator: "\n").map(String.init)
        let firstRow = rows[0]

        // Get column names.
        let definiteColumnNames: [String]
        if let columnNames = columnNames, !columnNames.isEmpty {
            definiteColumnNames = columnNames
        } else {
            definiteColumnNames = firstRow.split(separator: ",").map(String.init)
            // Use `.map({String($0)})` because `.map(String.init)` does not compile.
            rows = rows.dropFirst().map({ String($0) }) // Drop column row.
        }

        // Load file.
        let totalNumberOfColumns = firstRow.split(separator: ",").count
        var values = [[String]]()
        for (line, row) in rows.enumerated() {
            let items = row.split(separator: ",").map(String.init)

            // Make sure rows are consitent.
            guard items.count <= definiteColumnNames.count else {
                fatalError("Found \(items.count) items on row \(line) while \(definiteColumnNames.count) are needed.")
            }

            guard items.count == totalNumberOfColumns else {
                fatalError("First row had \(totalNumberOfColumns) items but row \(line) has \(items.count) columns.")
            }

            // Add a new empty row to the `values array`.
            values.append([String]())

            // Load columns in this row.
            for (columnIndex, value) in items.enumerated() {
                let column = definiteColumnNames[columnIndex]
                if definiteColumnNames.contains(column) {
                    values[line].append(value)
                }
            }
        }

        return (values, definiteColumnNames)
    }
}
