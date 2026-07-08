import Foundation
import ImageIO

struct PhotoFields: Codable {
    var title: String
    var caption: String
}

enum PhotoService {
    /// 讀照片的 EXIF 拍攝時間，當作日期預設值（比「處理當下」更貼近實際拍攝日）。讀不到就回傳 nil。
    static func exifCaptureDate(imagePath: String) -> Date? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let dateString: String?
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let dto = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            dateString = dto
        } else if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                  let dt = tiff[kCGImagePropertyTIFFDateTime] as? String {
            dateString = dt
        } else {
            dateString = nil
        }

        guard let dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }

    /// HEIC（iPhone 預設格式）轉成 JPEG，因為不是所有瀏覽器都能顯示 HEIC。其他格式原樣使用。
    static func normalizeToJPEG(sourcePath: String, workDir: String) throws -> String {
        let ext = (sourcePath as NSString).pathExtension.lowercased()
        guard ext == "heic" || ext == "heif" else { return sourcePath }

        guard let sipsPath = findExecutable("sips") else {
            throw DiaryError.executableNotFound("sips")
        }
        let outputPath = workDir + "/" + ((sourcePath as NSString).lastPathComponent as NSString)
            .deletingPathExtension + ".jpg"
        let result = try runProcess(sipsPath, ["-s", "format", "jpeg", sourcePath, "--out", outputPath])
        guard result.exitCode == 0 else {
            throw DiaryError.claudeFailed("HEIC 轉檔失敗：\(result.stderr)")
        }
        return outputPath
    }

    /// 幫照片配一句圖說（必要時也給新日記一個標題），用 claude -p 搭配 Read 工具「看」這張照片。
    /// 只開放 Read 這一張圖片（以及當天日記檔案，如果存在），不給寫入/執行權限。
    static func describe(imagePath: String, dateStr: String) throws -> PhotoFields {
        guard let claudePath = findExecutable("claude") else {
            throw DiaryError.executableNotFound("claude")
        }

        let diaryPath = DiaryService.diaryFilePath(dateStr: dateStr)
        let diaryExists = FileManager.default.fileExists(atPath: diaryPath)

        var allowedTools = "Read(\(imagePath))"
        if diaryExists { allowedTools += " Read(\(diaryPath))" }

        let contextNote = diaryExists
            ? "今天已經有日記了（\(diaryPath)），可以讀取參考內容，讓圖說跟當天語境更貼合。"
            : "今天還沒有日記文字，這張照片會是當天唯一的內容。"

        let prompt = """
        你是我的私人日記編輯。請讀取這張照片：\(imagePath)
        \(contextNote)

        請「只」輸出一個 JSON 物件，不要有其他文字、不要用 markdown code fence。

        JSON 欄位：
        - caption: string，繁體中文，幫這張照片寫一句有畫面感的圖說，不要太長，一句話就好
        - title: string，簡短的日記標題，繁體中文（只有在今天還沒有日記時才會被用到，若已有日記可留空字串）

        日期：\(dateStr)
        """

        let result = try runProcess(
            claudePath,
            ["-p", prompt, "--output-format", "json", "--model", "sonnet", "--allowedTools", allowedTools]
        )

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
              let fields = try? JSONDecoder().decode(PhotoFields.self, from: data) else {
            throw DiaryError.badResponse(cleaned)
        }
        return fields
    }

    /// public/images/ 底下找一個不會撞名的檔名：YYYYMMDD-n.jpg
    static func nextImageFilename(dateStr: String, ext: String) -> String {
        let base = dateStr.replacingOccurrences(of: "-", with: "")
        let fm = FileManager.default
        var n = 1
        while fm.fileExists(atPath: "\(Config.publicImagesDir)/\(base)-\(n).\(ext)") { n += 1 }
        return "\(base)-\(n).\(ext)"
    }

    /// 把照片複製進 public/images/，附加圖說進當天日記檔案，然後 git add 兩個檔案 + commit + push。
    static func save(imagePath: String, caption: String, title: String, dateStr: String) throws -> SaveOutcome {
        try FileManager.default.createDirectory(atPath: Config.publicImagesDir, withIntermediateDirectories: true)

        let ext = (imagePath as NSString).pathExtension.lowercased()
        let filename = nextImageFilename(dateStr: dateStr, ext: ext.isEmpty ? "jpg" : ext)
        let destPath = "\(Config.publicImagesDir)/\(filename)"
        try FileManager.default.copyItem(atPath: imagePath, toPath: destPath)

        let imageMarkdown = "![\(caption)](/images/\(filename))"

        let diaryPath = DiaryService.diaryFilePath(dateStr: dateStr)
        try FileManager.default.createDirectory(atPath: Config.blogDir, withIntermediateDirectories: true)

        let markdown: String
        if FileManager.default.fileExists(atPath: diaryPath) {
            let existingText = try String(contentsOfFile: diaryPath, encoding: .utf8)
            markdown = appendImage(existingText: existingText, imageMarkdown: imageMarkdown)
        } else {
            markdown = buildMinimalMarkdown(title: title.isEmpty ? "照片日記" : title, dateStr: dateStr, imageMarkdown: imageMarkdown)
        }
        try markdown.write(toFile: diaryPath, atomically: true, encoding: .utf8)

        let outcome = try GitService.commitAndPush(paths: [destPath, diaryPath], message: "上傳\(dateStr)日記")
        let relPath = Config.relativePath(diaryPath)
        return SaveOutcome(filePath: relPath, committed: outcome.committed, pushed: outcome.pushed, pushError: outcome.pushError)
    }

    private static func appendImage(existingText: String, imageMarkdown: String) -> String {
        guard let (frontmatter, body) = DiaryService.splitFrontmatter(existingText) else {
            let trimmedExisting = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedExisting + "\n\n---\n\n" + imageMarkdown + "\n"
        }
        let timeLabel = DiaryService.timeFormatter.string(from: Date())
        let mergedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            + "\n\n---\n\n### \(timeLabel)\n\n" + imageMarkdown + "\n"
        return (["---"] + frontmatter + ["---"]).joined(separator: "\n") + "\n" + mergedBody
    }

    private static func buildMinimalMarkdown(title: String, dateStr: String, imageMarkdown: String) -> String {
        var lines = ["---"]
        lines.append("title: \(DiaryService.yamlStr(title))")
        lines.append("pubDate: \(dateStr)")
        lines.append("location: \(DiaryService.yamlStr("Taipei, Taiwan"))")
        lines.append("category: \(DiaryService.yamlStr("日常"))")
        lines.append("---")
        return lines.joined(separator: "\n") + "\n" + imageMarkdown + "\n"
    }
}
