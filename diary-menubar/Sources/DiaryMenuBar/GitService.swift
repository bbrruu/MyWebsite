import Foundation

struct GitOutcome {
    var committed: Bool
    var pushed: Bool
    var pushError: String?
}

enum GitService {
    /// git add 指定的檔案（可多個）+ commit + push。共用給日記文字與照片流程。
    static func commitAndPush(paths: [String], message: String) throws -> GitOutcome {
        guard let gitPath = findExecutable("git") else {
            throw DiaryError.executableNotFound("git")
        }

        let addResult = try runProcess(gitPath, ["add"] + paths, cwd: Config.repoRoot)
        guard addResult.exitCode == 0 else {
            throw DiaryError.gitFailed(addResult.stderr)
        }

        let commitResult = try runProcess(gitPath, ["commit", "-m", message], cwd: Config.repoRoot)
        guard commitResult.exitCode == 0 else {
            throw DiaryError.gitFailed(commitResult.stderr.isEmpty ? commitResult.stdout : commitResult.stderr)
        }

        let pushResult = try runProcess(gitPath, ["push"], cwd: Config.repoRoot)
        if pushResult.exitCode == 0 {
            return GitOutcome(committed: true, pushed: true, pushError: nil)
        } else {
            return GitOutcome(committed: true, pushed: false, pushError: pushResult.stderr)
        }
    }
}
