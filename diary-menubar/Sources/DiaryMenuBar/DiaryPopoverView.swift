import SwiftUI

enum Phase {
    case editing
    case organizing
    case reviewing(DiaryFields, dateStr: String)
    case saving(DiaryFields, dateStr: String)
    case success(String)
    case failure(String)
}

enum PhotoPhase {
    case idle
    case describing
    case reviewing(PhotoFields)
    case saving(PhotoFields)
    case success(String)
    case failure(String)
}

struct DiaryPopoverView: View {
    @EnvironmentObject private var photoWatcher: PhotoWatcher

    @State private var rawText: String = ""
    @State private var date: Date = Date()
    @State private var phase: Phase = .editing

    @State private var photoPhase: PhotoPhase = .idle
    @State private var photoDate: Date = Date()
    @State private var normalizedImagePath: String = ""
    @State private var editedCaption: String = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var isOrganizing: Bool {
        if case .organizing = phase { return true }
        return false
    }
    private var isSaving: Bool {
        if case .saving = phase { return true }
        return false
    }
    private var canOrganize: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isOrganizing
    }
    private var pendingPhotoPath: String? { photoWatcher.queue.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pendingPhotoPath != nil ? "新照片" : "寫日記").font(.headline)
                Spacer()
                if pendingPhotoPath == nil, case .editing = phase {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
            }

            if let path = pendingPhotoPath {
                photoFlowView(path: path)
            } else {
                switch phase {
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
        .padding(14)
        .frame(width: 360)
    }

    // MARK: - Editing (文字)

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $rawText)
                    .font(.system(size: 13))
                    .frame(height: 160)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                    .disabled(isOrganizing)

                if rawText.isEmpty {
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
                    rawText = ""
                }
                .disabled(isOrganizing)

                Spacer()

                Button(isOrganizing ? "整理中..." : "整理") {
                    organize()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canOrganize)
            }
        }
    }

    // MARK: - Review (文字)

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
                    phase = .editing
                }
                .disabled(isSaving)

                Spacer()

                Button(isSaving ? "上傳中..." : "確認上傳") {
                    confirmSave(fields: fields, dateStr: dateStr)
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

    // MARK: - Result (文字)

    private func resultView(message: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundColor(isError ? .red : .green)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("寫下一篇") {
                    rawText = ""
                    phase = .editing
                }
            }
        }
    }

    // MARK: - Photo flow

    private func photoFlowView(path: String) -> some View {
        Group {
            switch photoPhase {
            case .idle, .describing:
                VStack(spacing: 10) {
                    photoThumbnail(path: path)
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Claude 看圖中，並判斷要放進哪篇日記...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            case .reviewing(let fields):
                photoReviewView(path: path, fields: fields, saving: false)
            case .saving(let fields):
                photoReviewView(path: path, fields: fields, saving: true)
            case .success(let message):
                photoResultView(path: path, message: message, isError: false)
            case .failure(let message):
                photoResultView(path: path, message: message, isError: true)
            }
        }
        .task(id: path) {
            await describePhoto(path: path)
        }
    }

    private func photoThumbnail(path: String) -> some View {
        Group {
            if let nsImage = NSImage(contentsOfFile: normalizedImagePath.isEmpty ? path : normalizedImagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .cornerRadius(6)
            }
        }
    }

    private func photoReviewView(path: String, fields: PhotoFields, saving: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            photoThumbnail(path: path)

            HStack {
                Text("日期").font(.caption.bold()).foregroundColor(.secondary)
                DatePicker("", selection: $photoDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .disabled(saving)
            }

            if DiaryService.entryExists(dateStr: Self.dateFormatter.string(from: photoDate)) {
                Text("這天已經有日記了，照片會附加到同一篇。")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Text("圖說（可自行修改）").font(.caption.bold()).foregroundColor(.secondary)
            TextField("圖說", text: $editedCaption)
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
                    photoWatcher.markHandled(path: path)
                    resetPhotoState()
                }
                .disabled(saving)

                Spacer()

                Button(saving ? "上傳中..." : "確認上傳") {
                    confirmSavePhoto(path: path, fields: fields)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(saving || editedCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func photoResultView(path: String, message: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundColor(isError ? .red : .green)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if isError {
                    Button("跳過這張") {
                        photoWatcher.markHandled(path: path)
                        resetPhotoState()
                    }
                }
                Spacer()
                Button("繼續") {
                    if !isError { photoWatcher.markHandled(path: path) }
                    resetPhotoState()
                }
            }
        }
    }

    private func resetPhotoState() {
        photoPhase = .idle
        normalizedImagePath = ""
        editedCaption = ""
    }

    // MARK: - Actions (文字)

    private func organize() {
        guard canOrganize else { return }
        let text = rawText
        let dateStr = Self.dateFormatter.string(from: date)
        phase = .organizing

        Task {
            do {
                let fields = try await Task.detached(priority: .userInitiated) {
                    try DiaryService.organize(rawText: text, dateStr: dateStr)
                }.value
                await MainActor.run {
                    phase = .reviewing(fields, dateStr: dateStr)
                }
            } catch {
                await MainActor.run {
                    phase = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func confirmSave(fields: DiaryFields, dateStr: String) {
        phase = .saving(fields, dateStr: dateStr)

        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try DiaryService.save(fields: fields, dateStr: dateStr)
                }.value
                await MainActor.run {
                    if outcome.pushed {
                        phase = .success("已儲存並推送：\(outcome.filePath)")
                    } else {
                        phase = .failure("已儲存＋commit，但 push 失敗（\(outcome.filePath)）：\(outcome.pushError ?? "未知錯誤")")
                    }
                    rawText = ""
                }
            } catch {
                await MainActor.run {
                    phase = .failure(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Actions (照片)

    private func describePhoto(path: String) async {
        photoPhase = .describing

        do {
            let normalizedPath = try await Task.detached(priority: .userInitiated) {
                try PhotoService.normalizeToJPEG(sourcePath: path, workDir: NSTemporaryDirectory())
            }.value

            // 日期預設用照片的 EXIF 拍攝時間，讀不到才 fallback 回今天；使用者仍可在畫面上手動改。
            let capturedDate = PhotoService.exifCaptureDate(imagePath: normalizedPath) ?? Date()
            let dateStr = Self.dateFormatter.string(from: capturedDate)

            await MainActor.run {
                normalizedImagePath = normalizedPath
                photoDate = capturedDate
            }

            let fields = try await Task.detached(priority: .userInitiated) {
                try PhotoService.describe(imagePath: normalizedPath, dateStr: dateStr)
            }.value
            await MainActor.run {
                editedCaption = fields.caption
                photoPhase = .reviewing(fields)
            }
        } catch {
            await MainActor.run {
                photoPhase = .failure(error.localizedDescription)
            }
        }
    }

    private func confirmSavePhoto(path: String, fields: PhotoFields) {
        photoPhase = .saving(fields)
        let dateStr = Self.dateFormatter.string(from: photoDate)
        let imagePath = normalizedImagePath.isEmpty ? path : normalizedImagePath
        let caption = editedCaption

        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try PhotoService.save(imagePath: imagePath, caption: caption, title: fields.title, dateStr: dateStr)
                }.value
                await MainActor.run {
                    if outcome.pushed {
                        photoPhase = .success("已儲存並推送：\(outcome.filePath)")
                    } else {
                        photoPhase = .failure("已儲存＋commit，但 push 失敗（\(outcome.filePath)）：\(outcome.pushError ?? "未知錯誤")")
                    }
                }
            } catch {
                await MainActor.run {
                    photoPhase = .failure(error.localizedDescription)
                }
            }
        }
    }
}
