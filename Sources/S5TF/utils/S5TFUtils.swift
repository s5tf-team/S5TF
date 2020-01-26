import Foundation

/// General helper functions for Swift.
public struct S5TFUtils {
    /// Run a command in the shell
    /// 
    /// - Parameters:
    ///   - `launchPath`: the path to the command.
    ///   - `paramters`: a list of paramters passed to the command.
    ///
    /// - Returns: output, termination status of the command.
    ///
    /// - Usage Example:
    ///   - Execute `ls -l -g`:
    ///     ```
    ///     shell("/bin/ls", "-l", "-g")`
    ///     ```
    ///   - Execute `ls -lah`
    ///     ```
    ///     shell("/bin/ls", "-lah")`
    ///     ```
    @discardableResult
    static public func shell(_ launchPath: String, _ arguments: String...) throws -> (out: String?, status: Int32) {
        return shell(launchPath, arguments)
    }

    /// Run a command in the shell.
    ///
    /// Wrapper for shell(_ launchPath: String, arguments: String...) because splatting is not supported in Swift.
    /// See https://bugs.swift.org/browse/SR-128 for more details.
    ///
    /// - Parameters:
    ///   - `launchPath`: the path to the command.
    ///   - `paramters`: a list of paramters passed to the command.
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
}
