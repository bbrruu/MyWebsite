import SwiftUI

enum Phase {
    case editing
    case organizing
    case reviewing(DiaryFields, dateStr: String)
    case saving(DiaryFields, dateStr: String)
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
        }
        .padding(14)
        .frame(width: 360)
        .onAppear {
            // 有照片在等的時候先幫忙切過去，但使用者隨時可以自己切回「日記」，不會被鎖住。
            if pendingPhotoPath != nil {
                selectedTab = .photo
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
            case .reviewing(let fields, let dateStr), .saving(let fields, let dateStr):
                reviewView(fields: fields, dateStr: dateStr)
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

    private func reviewView(fields: DiaryFields, dateStr: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("送出前先確認，內容沒有被改寫，只是排版跟補上 metadata：")
                .font(.caption)
                .foregroundColor(.secondary)

            if DiaryService.entryExists(dateStr: dateStr) {
                Text("這天已經有日記了，會用時間分段附加到同一篇，不會另外開新檔案。")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    metaRow("標題", fields.title)
                    metaRow("日期", dateStr)
                    metaRow("心情", fields.mood)
                    metaRow("分類", fields.category)
                    metaRow("地點", fields.location)
                    if !fields.tags.isEmpty {
                        metaRow("標籤", fields.tags.joined(separator: "、"))
                    }
                    if !fields.quote.isEmpty {
                        metaRow("金句", fields.quote)
                    }
                    Divider()
                    Text(fields.content)
                        .font(.system(size: 12.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
            }
            .frame(height: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))

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
                    draftState.confirmSave(fields: fields, dateStr: dateStr)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isSaving)
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
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
                Text("目前沒有待處理的照片。手機分享照片到 Google Drive 的 DiaryPhotos/Inbox 後，會自動出現在這裡。")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                photoResultView(message: message, isError: true)
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
}
