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
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)

        return (output, task.terminationStatus)
    }
}
