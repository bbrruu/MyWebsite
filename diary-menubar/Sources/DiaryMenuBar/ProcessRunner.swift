import Foundation

struct ProcessResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

/// 用底層 POSIX read() 把一個檔案描述符讀到 EOF。刻意不用 FileHandle.readDataToEndOfFile()——
/// 那個讀取失敗時丟的是 Objective-C exception，Swift 的 try/catch 接不住，會直接讓整個
/// App crash（在 PhotoWatcher 那邊真的撞過一次）。POSIX read() 只會回傳 -1，不會拋例外。
private func readAllData(fromFileDescriptor fd: Int32) -> Data {
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 65536)
    while true {
        let n = buffer.withUnsafeMutableBytes { ptr in
            read(fd, ptr.baseAddress, ptr.count)
        }
        if n <= 0 { break } // 0 = EOF，負數 = 錯誤，兩種都停止
        result.append(buffer, count: n)
    }
    return result
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
        stdoutData = readAllData(fromFileDescriptor: stdoutPipe.fileHandleForReading.fileDescriptor)
        group.leave()
    }
    group.enter()
    DispatchQueue.global(qos: .utility).async {
        stderrData = readAllData(fromFileDescriptor: stderrPipe.fileHandleForReading.fileDescriptor)
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
