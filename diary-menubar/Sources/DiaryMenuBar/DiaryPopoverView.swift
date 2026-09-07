import SwiftUI

enum Phase {
    case editing
    case organizing
    case reviewing(dateStr: String)
    case saving(dateStr: String)
    case success(String)
    case failure(String)
}

enum DiaryTab {
    case diary
    case photo
}

struct DiaryPopoverView: View {
    @EnvironmentObject private var photoWatcher: PhotoWatcher
    @EnvironmentObject private var photoProcessor: PhotoProcessor
    @EnvironmentObject private var draftState: DiaryDraftState
    @EnvironmentObject private var auth: AuthService

    @State private var selectedTab: DiaryTab = .diary

    private var isOrganizing: Bool {
        if case .organizing = draftState.phase { return true }
        return false
    }
    private var isSaving: Bool {
        if case .saving = draftState.phase { return true }
        return false
    }
    private var canOrganize: Bool {
        !draftState.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isOrganizing
    }
    private var pendingPhotoPath: String? { photoWatcher.queue.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $selectedTab) {
                Text("日記").tag(DiaryTab.diary)
                Text(pendingPhotoPath != nil ? "圖片 ●" : "圖片").tag(DiaryTab.photo)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch selectedTab {
            case .diary:
                diaryTabView
            case .photo:
                photoTabView
            }

            Divider()
            authStatusBar
        }
        .padding(14)
        .frame(width: 360)
        .onAppear {
            auth.refreshLocally()
            // 有照片在等的時候先幫忙切過去，但使用者隨時可以自己切回「日記」，不會被鎖住。
            if pendingPhotoPath != nil {
                selectedTab = .photo
            }
            draftState.refreshDateIfFresh()
        }
    }

    // MARK: - 認證狀態

    private var authStatusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: auth.state.symbol)
                    .foregroundColor(auth.state.color)
                    .font(.caption)
                Text("Claude 認證")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Text(auth.state.label)
                    .font(.caption)
                    .foregroundColor(auth.state.color)

                Spacer()

                if case .checking = auth.state {
                    ProgressView().controlSize(.small)
                } else {
                    // 這個 App 用的是 Keychain 裡的 OAuth 登入憑證（訂閱帳號），
                    // 不是 API key，所以不會產生按次計費——用量算在方案額度上。
                    // 但每次呼叫仍要重建 CLI 的系統提示快取（約 1 萬 token），
                    // 所以還是把上次檢查時間顯示出來，避免無謂重複按。
                    if let last = auth.lastCheck {
                        Text(last, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Button("檢查") { auth.verify() }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .help("跑一次最小的 claude 呼叫確認憑證還能用（算在訂閱額度裡，不另外計費）")
                }

                if auth.state.needsAttention {
                    Button("登入") { auth.openLogin() }
                        .font(.caption.bold())
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            if case .expired(let detail) = auth.state {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("按「登入」會開一個 Terminal 視窗跑 claude login。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if case .noCredentials = auth.state {
                Text("Keychain 裡找不到 Claude 憑證，日記與圖說都無法產生。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Diary tab (文字)

    private var diaryTabView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .editing = draftState.phase {
                HStack {
                    Text("日期").font(.caption.bold()).foregroundColor(.secondary)
                    DatePicker("", selection: $draftState.date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
            }

            switch draftState.phase {
            case .editing, .organizing:
                editingView
            case .reviewing(let dateStr), .saving(let dateStr):
                reviewView(dateStr: dateStr)
            case .success(let message):
                resultView(message: message, isError: false)
            case .failure(let message):
                resultView(message: message, isError: true)
            }
        }
    }

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftState.rawText)
                    .font(.system(size: 13))
                    .frame(height: 160)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                    .disabled(isOrganizing)

                if draftState.rawText.isEmpty {
                    Text("今天想寫點什麼？想到什麼寫什麼，交給 Claude 整理成日記，內容不會被改寫。")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .padding(.top, 12)
                        .padding(.leading, 9)
                        .allowsHitTesting(false)
                }
            }

            if isOrganizing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Claude 整理中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button("清空") {
                    draftState.rawText = ""
                }
                .disabled(isOrganizing)

                Spacer()

                Button(isOrganizing ? "整理中..." : "整理") {
                    draftState.organize()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canOrganize)
            }
        }
    }

    // 標籤是陣列，UI 用一行字編輯；、和逗號都當分隔
    private var tagsBinding: Binding<String> {
        Binding(
            get: { draftState.fields.tags.joined(separator: "、") },
            set: { text in
                draftState.fields.tags = text
                    .split(whereSeparator: { "、,，".contains($0) })
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private func reviewView(dateStr: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude 只做了排版和 metadata，內文沒有被改寫。下面都可以直接改。")
                .font(.caption)
                .foregroundColor(.secondary)

            if DiaryService.entryExists(dateStr: dateStr) {
                Text("這天已經有日記了，會用時間分段附加到同一篇，不會另外開新檔案。")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    editRow("標題") {
                        TextField("", text: $draftState.fields.title)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("日期").font(.caption.bold()).foregroundColor(.secondary)
                            .frame(width: 36, alignment: .leading)
                        Text(dateStr).font(.caption).foregroundColor(.secondary)
                    }
                    editRow("心情") {
                        TextField("還行", text: $draftState.fields.mood)
                    }
                    // category 在 config.ts 是 enum，用選單避免打錯字讓 build 失敗
                    editRow("分類") {
                        Picker("", selection: $draftState.fields.category) {
                            ForEach(DiaryFields.categories, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                    editRow("地點") {
                        TextField("Taipei, Taiwan", text: $draftState.fields.location)
                    }
                    editRow("標籤") {
                        TextField("用、分隔", text: tagsBinding)
                    }
                    editRow("金句") {
                        TextField("可留空", text: $draftState.fields.quote)
                    }

                    Divider().padding(.vertical, 2)

                    Text("內文")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextEditor(text: $draftState.fields.content)
                        .font(.system(size: 12.5))
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.25)))
                }
                .padding(8)
            }
            .frame(height: 260)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            .disabled(isSaving)

            if isSaving {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("儲存並 push 中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button("重新編輯") {
                    draftState.phase = .editing
                }
                .disabled(isSaving)

                Spacer()

                Button(isSaving ? "上傳中..." : "確認上傳") {
                    draftState.confirmSave(dateStr: dateStr)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isSaving || draftState.fields.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func editRow<Content: View>(
        _ label: String,
        @ViewBuilder _ field: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
            field()
                .font(.caption)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func resultView(message: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundColor(isError ? .red : .green)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("寫下一篇") {
                    draftState.clear()
                }
            }
        }
    }

    // MARK: - Photo tab
    // 處理狀態全部來自 photoProcessor（跟 App 生命週期綁在一起的 singleton），
    // 這裡純粹是顯示，關掉再打開這個彈出視窗不會影響、也不會重複觸發背景處理。
    // claude 只會在使用者按下「整理」（startDescribing）時才被呼叫。

    private var photoTabView: some View {
        Group {
            if let path = pendingPhotoPath {
                photoFlowView(path: path)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("手機分享照片到 Google Drive 的 DiaryPhotos/Inbox 後，按下面的按鈕掃描。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let message = photoWatcher.lastScanMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    HStack {
                        Spacer()
                        Button(photoWatcher.isScanning ? "掃描中..." : "掃描 Inbox") {
                            photoWatcher.scanNow()
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(photoWatcher.isScanning)
                    }
                }
            }
        }
    }

    private func photoFlowView(path: String) -> some View {
        Group {
            switch photoProcessor.phase {
            case .idle:
                EmptyView()
            case .waiting:
                photoWaitingView(path: path)
            case .describing:
                VStack(spacing: 10) {
                    photoThumbnail(path: path)
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Claude 看圖中，並產生圖說...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            case .reviewing(let fields):
                photoReviewView(path: path, fields: fields, saving: false)
            case .saving(let fields):
                photoReviewView(path: path, fields: fields, saving: true)
            case .success(let message):
                photoResultView(message: message, isError: false)
            case .failure(let message):
                photoFailureView(message: message)
            }
        }
    }

    private func photoThumbnail(path: String) -> some View {
        Group {
            let imgPath = photoProcessor.normalizedImagePath.isEmpty ? path : photoProcessor.normalizedImagePath
            if let nsImage = NSImage(contentsOfFile: imgPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .cornerRadius(6)
            }
        }
    }

    /// 照片已經轉檔+讀完 EXIF，等使用者確認日期、按下「整理」才會真的呼叫 claude。
    /// 這天沒有日記的話「整理」會被鎖住——照片只能附加在已經有日記的日子。
    private func photoWaitingView(path: String) -> some View {
        let diaryExists = DiaryService.entryExists(dateStr: photoProcessor.dateStr)

        return VStack(alignment: .leading, spacing: 8) {
            photoThumbnail(path: path)

            HStack {
                Text("日期").font(.caption.bold()).foregroundColor(.secondary)
                DatePicker("", selection: $photoProcessor.photoDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            if diaryExists {
                Text("這天已經有日記了，整理後會附加到同一篇。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("這天（\(photoProcessor.dateStr)）還沒有日記，請先切到「日記」分頁寫一篇，才能替這天加照片。")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("跳過這張") {
                    photoProcessor.dismissCurrent()
                }

                Spacer()

                Button("整理") {
                    photoProcessor.startDescribing()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!diaryExists)
            }
        }
    }

    private func photoReviewView(path: String, fields: PhotoFields, saving: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            photoThumbnail(path: path)

            HStack {
                Text("日期").font(.caption.bold()).foregroundColor(.secondary)
                DatePicker("", selection: $photoProcessor.photoDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .disabled(saving)
            }

            Text("圖說（可自行修改）").font(.caption.bold()).foregroundColor(.secondary)
            TextField("圖說", text: $photoProcessor.editedCaption)
                .textFieldStyle(.roundedBorder)
                .disabled(saving)

            if saving {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("儲存並 push 中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button("跳過這張") {
                    photoProcessor.dismissCurrent()
                }
                .disabled(saving)

                Spacer()

                Button(saving ? "上傳中..." : "確認上傳") {
                    photoProcessor.confirmSave(fields: fields)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(saving || photoProcessor.editedCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func photoResultView(message: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundColor(isError ? .red : .green)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("繼續") {
                    photoProcessor.dismissCurrent()
                }
            }
        }
    }

    /// claude 呼叫失敗（自動重試 3 次後仍失敗，常見原因是 Google Drive 同步鎖遲遲沒放）：
    /// 除了「跳過這張」，也給「重試」，不用把照片丟到 Processed 才能再試一次。
    private func photoFailureView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("跳過這張") {
                    photoProcessor.dismissCurrent()
                }
                Spacer()
                Button("重試") {
                    photoProcessor.retryFromFailure()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}
