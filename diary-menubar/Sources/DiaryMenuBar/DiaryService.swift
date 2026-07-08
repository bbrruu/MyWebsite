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

    static func yamlStr(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }

    static func yamlArr(_ values: [String]) -> String {
        "[" + values.map(yamlStr).joined(separator: ", ") + "]"
    }

    /// 同一個日期永遠對應同一個檔案——同一天的多篇（文字或照片）會合併進同一篇。
    static func diaryFilePath(dateStr: String) -> String {
        let base = dateStr.replacingOccurrences(of: "-", with: "")
        return "\(Config.blogDir)/\(base).md"
    }

    /// 給 UI 判斷「今天是否已經寫過」，以便在預覽畫面提示會附加而非新建。
    static func entryExists(dateStr: String) -> Bool {
        FileManager.default.fileExists(atPath: diaryFilePath(dateStr: dateStr))
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func buildFullMarkdown(fields: DiaryFields, dateStr: String) -> String {
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
        return lines.joined(separator: "\n") + "\n" + fields.content.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// 把已存在檔案切成 (frontmatter 行陣列, 內文) 兩部分；格式不符則回傳 nil。
    static func splitFrontmatter(_ text: String) -> (frontmatter: [String], body: String)? {
        var lines = text.components(separatedBy: "\n")
        guard lines.first == "---" else { return nil }
        lines.removeFirst()
        guard let endIndex = lines.firstIndex(of: "---") else { return nil }
        let frontmatter = Array(lines[0..<endIndex])
        let body = lines[(endIndex + 1)...].joined(separator: "\n")
        return (frontmatter, body)
    }

    private static func parseYamlArray(_ line: String) -> [String] {
        guard let start = line.firstIndex(of: "["), let end = line.firstIndex(of: "]") else { return [] }
        let inner = line[line.index(after: start)..<end]
        return inner.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
        }.filter { !$0.isEmpty }
    }

    private static func mergeUniqueTags(_ existing: [String], _ new: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in existing + new where !seen.contains(tag) {
            seen.insert(tag)
            result.append(tag)
        }
        return result
    }

    /// 附加到既有檔案：frontmatter 維持當天第一篇的內容，只合併 tags；內文用時間分段附加在後面。
    private static func appendMarkdown(existingText: String, fields: DiaryFields) -> String {
        guard let (frontmatter, body) = splitFrontmatter(existingText) else {
            // 既有檔案格式跟預期不同，保守處理：不動 frontmatter，直接把新內容接在檔案最後面
            let trimmedExisting = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
            let newSection = fields.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedExisting + "\n\n---\n\n" + newSection + "\n"
        }

        var mergedFrontmatter = frontmatter
        if !fields.tags.isEmpty {
            if let idx = mergedFrontmatter.firstIndex(where: { $0.hasPrefix("tags:") }) {
                let existingTags = parseYamlArray(mergedFrontmatter[idx])
                mergedFrontmatter[idx] = "tags: \(yamlArr(mergeUniqueTags(existingTags, fields.tags)))"
            } else {
                mergedFrontmatter.append("tags: \(yamlArr(fields.tags))")
            }
        }

        let timeLabel = timeFormatter.string(from: Date())
        let newSection = fields.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let mergedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            + "\n\n---\n\n### \(timeLabel)\n\n" + newSection + "\n"

        return (["---"] + mergedFrontmatter + ["---"]).joined(separator: "\n") + "\n" + mergedBody
    }

    /// 寫入 markdown 檔並自動 git add + commit + push。同一天已有日記時會附加到同一篇。
    static func save(fields: DiaryFields, dateStr: String) throws -> SaveOutcome {
        try FileManager.default.createDirectory(atPath: Config.blogDir, withIntermediateDirectories: true)
        let path = diaryFilePath(dateStr: dateStr)

        let markdown: String
        if FileManager.default.fileExists(atPath: path) {
            let existingText = try String(contentsOfFile: path, encoding: .utf8)
            markdown = appendMarkdown(existingText: existingText, fields: fields)
        } else {
            markdown = buildFullMarkdown(fields: fields, dateStr: dateStr)
        }
        try markdown.write(toFile: path, atomically: true, encoding: .utf8)

        let outcome = try GitService.commitAndPush(paths: [path], message: "上傳\(dateStr)日記")
        let relPath = Config.relativePath(path)
        return SaveOutcome(filePath: relPath, committed: outcome.committed, pushed: outcome.pushed, pushError: outcome.pushError)
    }
}
