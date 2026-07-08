import Foundation

struct DiaryFields: Codable {
    var title: String
    var mood: String
    var category: String
    var location: String
    var tags: [String]
    var quote: String
    var content: String
}

struct SaveOutcome {
    var filePath: String
    var committed: Bool
    var pushed: Bool
    var pushError: String?
}

enum DiaryError: LocalizedError {
    case executableNotFound(String)
    case claudeFailed(String)
    case badResponse(String)
    case gitFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return "找不到 \(name) 執行檔，請確認已安裝"
        case .claudeFailed(let msg):
            return "Claude 整理失敗：\(msg)"
        case .badResponse(let msg):
            return "無法解析 Claude 回應：\(msg)"
        case .gitFailed(let msg):
            return "Git 操作失敗：\(msg)"
        }
    }
}

private struct ProcessResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

private func runProcess(_ executable: String, _ arguments: [String], cwd: String? = nil) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return ProcessResult(
        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
        stderr: String(data: stderrData, encoding: .utf8) ?? "",
        exitCode: process.terminationStatus
    )
}

enum DiaryService {
    /// 把使用者隨手寫的原文交給 claude -p 整理成結構化欄位。
    /// claude 這一步只做純文字生成，不給任何工具權限，所以不會去動檔案或執行指令。
    static func organize(rawText: String, dateStr: String) throws -> DiaryFields {
        guard let claudePath = findExecutable("claude") else {
            throw DiaryError.executableNotFound("claude")
        }

        let prompt = """
        你是我的私人日記編輯。以下是我剛剛隨手寫下的日記原文，可能很口語、沒有標點、想到什麼寫什麼。
        content 欄位是重點：我要原汁原味呈現，你「不可以」改寫、潤飾、修正語病、調整語序、替換用詞，也不可以新增原文沒有的句子或內容。你唯一能對原文做的事是排版層面的：適當分段（用 <br/> 換行）、把明顯缺漏的標點稍微補上以利閱讀、去除多餘空白。除此之外必須逐字保留我的原文，包括我的口語、贅字、錯字、語氣詞——那些都是我，不要幫我「修好」。

        請「只」輸出一個 JSON 物件，不要有任何其他文字、不要用 markdown code fence 包起來、不要加任何說明。

        JSON 欄位：
        - title: string，簡短有畫面感的標題，繁體中文
        - mood: string，一兩個詞描述當天心情，例如「還行」「興奮」「疲憊」「平靜」
        - category: 必須是 "日常"、"旅行"、"省思" 三選一
        - location: string，若原文有提到地點就用該地點，否則用 "Taipei, Taiwan"
        - tags: string 陣列，2 到 5 個從原文萃取的關鍵字標籤，繁體中文
        - quote: string，從原文「直接摘錄」一句最有感覺的話當金句，不要改寫；若原文情緒平淡可留空字串
        - content: string，見上方規則——只排版分段、補標點、不改寫

        日記日期：\(dateStr)

        原文：
        \"\"\"
        \(rawText)
        \"\"\"
        """

        let result = try runProcess(claudePath, ["-p", prompt, "--output-format", "json", "--model", "haiku"])

        guard result.exitCode == 0 else {
            throw DiaryError.claudeFailed(result.stderr.isEmpty ? "exit \(result.exitCode)" : result.stderr)
        }

        guard let wrapper = try? JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any],
              let resultText = wrapper["result"] as? String else {
            throw DiaryError.badResponse(result.stdout)
        }
        if let isError = wrapper["is_error"] as? Bool, isError {
            throw DiaryError.claudeFailed(resultText)
        }

        let cleaned = resultText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let fields = try? JSONDecoder().decode(DiaryFields.self, from: data) else {
            throw DiaryError.badResponse(cleaned)
        }
        return fields
    }

    private static func yamlStr(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }

    private static func yamlArr(_ values: [String]) -> String {
        "[" + values.map(yamlStr).joined(separator: ", ") + "]"
    }

    private static func resolveFilePath(dateStr: String) -> String {
        let base = dateStr.replacingOccurrences(of: "-", with: "")
        let fm = FileManager.default
        var candidate = "\(Config.blogDir)/\(base).md"
        if !fm.fileExists(atPath: candidate) { return candidate }
        var n = 2
        while fm.fileExists(atPath: "\(Config.blogDir)/\(base)-\(n).md") { n += 1 }
        candidate = "\(Config.blogDir)/\(base)-\(n).md"
        return candidate
    }

    /// 寫入 markdown 檔並自動 git add + commit + push。
    static func save(fields: DiaryFields, dateStr: String) throws -> SaveOutcome {
        let category = Config.allowedCategories.contains(fields.category) ? fields.category : "日常"

        var lines = ["---"]
        lines.append("title: \(yamlStr(fields.title))")
        lines.append("pubDate: \(dateStr)")
        if !fields.mood.isEmpty { lines.append("mood: \(yamlStr(fields.mood))") }
        lines.append("location: \(yamlStr(fields.location.isEmpty ? "Taipei, Taiwan" : fields.location))")
        lines.append("category: \(yamlStr(category))")
        if !fields.tags.isEmpty { lines.append("tags: \(yamlArr(fields.tags))") }
        if !fields.quote.isEmpty { lines.append("quote: \(yamlStr(fields.quote))") }
        lines.append("---")
        let markdown = lines.joined(separator: "\n") + "\n" + fields.content.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"

        try FileManager.default.createDirectory(atPath: Config.blogDir, withIntermediateDirectories: true)
        let filePath = resolveFilePath(dateStr: dateStr)
        try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)

        guard let gitPath = findExecutable("git") else {
            throw DiaryError.executableNotFound("git")
        }

        let addResult = try runProcess(gitPath, ["add", filePath], cwd: Config.repoRoot)
        guard addResult.exitCode == 0 else {
            throw DiaryError.gitFailed(addResult.stderr)
        }

        let commitMessage = "上傳\(dateStr)日記"
        let commitResult = try runProcess(gitPath, ["commit", "-m", commitMessage], cwd: Config.repoRoot)
        guard commitResult.exitCode == 0 else {
            throw DiaryError.gitFailed(commitResult.stderr.isEmpty ? commitResult.stdout : commitResult.stderr)
        }

        let pushResult = try runProcess(gitPath, ["push"], cwd: Config.repoRoot)
        let relPath = String(filePath.dropFirst(Config.repoRoot.count + 1))
        if pushResult.exitCode == 0 {
            return SaveOutcome(filePath: relPath, committed: true, pushed: true, pushError: nil)
        } else {
            return SaveOutcome(filePath: relPath, committed: true, pushed: false, pushError: pushResult.stderr)
        }
    }
}
