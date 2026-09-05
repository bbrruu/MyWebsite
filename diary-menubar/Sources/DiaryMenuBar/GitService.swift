import Foundation

struct GitOutcome {
    var committed: Bool
    var pushed: Bool
    var pushError: String?
    /// 因為分支上還有別的未推送 commit 而刻意跳過 push
    var pushSkipped: Bool = false
}

enum GitService {
    /// git add 指定的檔案（可多個）+ commit + push。共用給日記文字與照片流程。
    ///
    /// push 是有隔離的：`git push` 推的是整條分支，不是單一 commit，所以如果使用者
    /// 手上有做到一半、還沒想推的 commit（例如改 diary-menubar 自己），寫一篇日記
    /// 就會順手把那些一起發佈出去。這裡在 commit 前先數 upstream 落後幾筆，
    /// 只有在「除了我們這筆之外沒有別的」時才 push。
    static func commitAndPush(paths: [String], message: String) throws -> GitOutcome {
        guard let gitPath = findExecutable("git") else {
            throw DiaryError.executableNotFound("git")
        }

        // commit 之前先記下已經存在的未推送 commit 數量
        let preexistingUnpushed = unpushedCount(gitPath: gitPath)

        let addResult = try runProcess(gitPath, ["add"] + paths, cwd: Config.repoRoot)
        guard addResult.exitCode == 0 else {
            throw DiaryError.gitFailed(addResult.stderr)
        }

        let commitResult = try runProcess(gitPath, ["commit", "-m", message], cwd: Config.repoRoot)
        guard commitResult.exitCode == 0 else {
            throw DiaryError.gitFailed(commitResult.stderr.isEmpty ? commitResult.stdout : commitResult.stderr)
        }

        // 有先前就存在的未推送 commit → 不要替使用者決定要不要發佈，只 commit 不 push
        if let preexisting = preexistingUnpushed, preexisting > 0 {
            return GitOutcome(
                committed: true,
                pushed: false,
                pushError: "分支上還有 \(preexisting) 筆你自己的未推送 commit，已跳過 push。日記已經 commit 好了，確認過之後手動 git push 即可。",
                pushSkipped: true
            )
        }

        let pushResult = try runProcess(gitPath, ["push"], cwd: Config.repoRoot)
        if pushResult.exitCode == 0 {
            return GitOutcome(committed: true, pushed: true, pushError: nil)
        } else {
            return GitOutcome(committed: true, pushed: false, pushError: pushResult.stderr)
        }
    }

    /// 目前分支領先 upstream 幾個 commit。沒有 upstream（或指令失敗）時回傳 nil，
    /// 此時維持原本行為直接 push，不要因為數不出來就整個不推。
    private static func unpushedCount(gitPath: String) -> Int? {
        guard let result = try? runProcess(
            gitPath,
            ["rev-list", "--count", "@{upstream}..HEAD"],
            cwd: Config.repoRoot
        ), result.exitCode == 0 else { return nil }

        return Int(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
