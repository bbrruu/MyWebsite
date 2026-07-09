import Foundation

struct ProcessResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

func runProcess(_ executable: String, _ arguments: [String], cwd: String? = nil) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
    process.standardInput = FileHandle.nullDevice // 子行程不需要 stdin，明確關閉避免它卡在等輸入

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()

    // 一定要在 waitUntilExit() 之前（或同時）把兩條 pipe 讀空：
    // 如果子行程輸出量超過管線緩衝區，且沒人在讀，子行程會卡在自己的 write() 上，
    // 而我們卡在 waitUntilExit() 等它結束——典型的 pipe deadlock。兩條 pipe 要同時讀，
    // 只讀一條也可能卡住（另一條滿了換另一邊卡住）。
    var stdoutData = Data()
    var stderrData = Data()
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global(qos: .utility).async {
        stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
    }
    group.enter()
    DispatchQueue.global(qos: .utility).async {
        stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
    }
    group.wait()

    process.waitUntilExit()

    return ProcessResult(
        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
        stderr: String(data: stderrData, encoding: .utf8) ?? "",
        exitCode: process.terminationStatus
    )
}
