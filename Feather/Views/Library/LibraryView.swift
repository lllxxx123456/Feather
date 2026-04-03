//
//  HomeView.swift (replaces LibraryView)
//  Feather778
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import UniformTypeIdentifiers
import Zip

// MARK: - HomeView
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var selectedTab: Int = 0
    private let tabTitles = ["未签名应用", "插件管理", "已签名应用"]

    @State private var isImportingFile = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                _segmentedHeader()

                TabView(selection: $selectedTab) {
                    UnsignedAppsTab()
                        .environment(\.managedObjectContext, viewContext)
                        .tag(0)
                    PluginsTab()
                        .tag(1)
                    SignedAppsTab()
                        .environment(\.managedObjectContext, viewContext)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
            }
            .navigationTitle("Feather778")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { isImportingFile = true }) {
                            Label("从文件导入", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $isImportingFile) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.ipa, .tipa, .deb, .dylib, .certZip],
                    allowsMultipleSelection: true,
                    onDocumentsPicked: { urls in
                        for url in urls {
                            _handleImportedFile(url)
                        }
                    }
                )
                .ignoresSafeArea()
            }
        }
        .navigationViewStyle(.stack)
        .withToast()
    }

    @ViewBuilder
    private func _segmentedHeader() -> some View {
        HStack(spacing: 0) {
            ForEach(0..<tabTitles.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tabTitles[index])
                            .font(.system(size: 14, weight: selectedTab == index ? .bold : .medium))
                            .foregroundColor(selectedTab == index ? .primary : .secondary)

                        Rectangle()
                            .fill(selectedTab == index ? Color.accentColor : Color.clear)
                            .frame(height: 2.5)
                            .cornerRadius(1.25)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .background(Color(UIColor.systemBackground))
    }

    private func _handleImportedFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "ipa", "tipa":
            let id = "FeatherManualDownload_\(UUID().uuidString)"
            let dl = downloadManager.startArchive(from: url, id: id)
            try? downloadManager.handlePachageFile(url: url, dl: dl)
        case "deb", "dylib":
            _importTweak(url)
        case "zip":
            _importTweak(url)
        default:
            ToastManager.shared.show("不支持的文件类型", style: .error)
        }
    }

    private func _importTweak(_ url: URL) {
        let fm = FileManager.default
        try? fm.createDirectoryIfNeeded(at: fm.tweaks)

        let dest = fm.tweaks.appendingPathComponent(url.lastPathComponent)
        do {
            try? fm.removeFileIfNeeded(at: dest)
            try fm.copyItem(at: url, to: dest)
            ToastManager.shared.show("插件已导入", style: .success)
        } catch {
            ToastManager.shared.show("导入失败: \(error.localizedDescription)", style: .error)
        }
    }
}

// MARK: - Unsigned Apps Tab
struct UnsignedAppsTab: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
        animation: .default
    )
    private var apps: FetchedResults<Imported>

    @State private var selectedApp: AnyApp?
    @State private var extractApp: AnyApp?
    @State private var showDeleteAlert = false
    @State private var appToDelete: Imported?

    var body: some View {
        ScrollView {
            if apps.isEmpty {
                _emptyState(icon: "doc.zipper", text: "暂无未签名应用\n请导入 IPA 文件开始使用")
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(apps, id: \.uuid) { app in
                        AppCardView(
                            app: app,
                            actions: [
                                .init(title: "签名", icon: "signature", color: .accentColor) {
                                    selectedApp = AnyApp(base: app)
                                },
                                .init(title: "提取库", icon: "shippingbox", color: .orange) {
                                    extractApp = AnyApp(base: app)
                                },
                                .init(title: "分享", icon: "square.and.arrow.up", color: .blue) {
                                    _shareApp(app)
                                },
                                .init(title: "删除", icon: "trash", color: .red) {
                                    appToDelete = app
                                    showDeleteAlert = true
                                }
                            ]
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let app = appToDelete {
                    Storage.shared.deleteApp(for: app)
                    ToastManager.shared.show("已删除", style: .success)
                }
            }
        } message: {
            Text("确定要删除此应用吗？此操作不可撤销。")
        }
        .fullScreenCover(item: $selectedApp) { app in
            SigningView(app: app.base)
        }
        .fullScreenCover(item: $extractApp) { app in
            LibraryExtractView(app: app.base)
        }
    }

    private func _shareApp(_ app: AppInfoPresentable) {
        guard let appDir = Storage.shared.getUuidDirectory(for: app) else { return }
        UIActivityViewController.show(activityItems: [appDir])
    }
}

// MARK: - Library Extract View (Full Screen)
struct LibraryExtractView: View {
    @Environment(\.dismiss) private var dismiss

    let app: AppInfoPresentable
    @State private var allFiles: [ExtractableFile] = []
    @State private var selectedFiles: Set<String> = []
    @State private var isExtracting = false

    struct ExtractableFile: Identifiable {
        let id: String
        let url: URL
        let name: String
        let size: String
        let category: String // "Frameworks" or "动态库"

        init(url: URL, category: String) {
            self.id = url.absoluteString
            self.url = url
            self.name = url.lastPathComponent
            self.category = category
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let bytes = attrs?[.size] as? Int64 ?? 0
            self.size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    private var frameworkFiles: [ExtractableFile] {
        allFiles.filter { $0.category == "Frameworks" }
    }

    private var dylibFiles: [ExtractableFile] {
        allFiles.filter { $0.category == "动态库" }
    }

    private var allSelected: Bool {
        !allFiles.isEmpty && selectedFiles.count == allFiles.count
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if allFiles.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "shippingbox")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("未找到可提取的库文件")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Select all bar
                    HStack {
                        Button(action: _toggleSelectAll) {
                            HStack(spacing: 8) {
                                Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(allSelected ? .accentColor : .secondary)
                                Text(allSelected ? "取消全选" : "全选")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .foregroundColor(.primary)

                        Spacer()

                        Text("已选择 \(selectedFiles.count)/\(allFiles.count)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !frameworkFiles.isEmpty {
                                _sectionHeader("Frameworks (\(frameworkFiles.count))")
                                ForEach(frameworkFiles) { file in
                                    _fileRow(file)
                                }
                            }

                            if !dylibFiles.isEmpty {
                                _sectionHeader("动态库 (\(dylibFiles.count))")
                                ForEach(dylibFiles) { file in
                                    _fileRow(file)
                                }
                            }
                        }
                    }

                    // Extract button
                    Button(action: _extractSelected) {
                        HStack {
                            Spacer()
                            if isExtracting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "archivebox.fill")
                                Text("提取并压缩为 ZIP (\(selectedFiles.count))")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedFiles.isEmpty ? Color.gray : Color.accentColor)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .disabled(selectedFiles.isEmpty || isExtracting)
                }
            }
            .navigationTitle("提取库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(_loadFiles)
            .disabled(isExtracting)
        }
    }

    @ViewBuilder
    private func _sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }

    @ViewBuilder
    private func _fileRow(_ file: ExtractableFile) -> some View {
        let isSelected = selectedFiles.contains(file.id)

        Button(action: { _toggleFile(file) }) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.5))

                Image(systemName: file.name.hasSuffix(".framework") ? "building.columns" : "puzzlepiece.extension.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(file.size)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }

        Divider().padding(.leading, 62)
    }

    private func _toggleFile(_ file: ExtractableFile) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
        } else {
            selectedFiles.insert(file.id)
        }
    }

    private func _toggleSelectAll() {
        if allSelected {
            selectedFiles.removeAll()
        } else {
            selectedFiles = Set(allFiles.map(\.id))
        }
    }

    private func _loadFiles() {
        guard let appDir = Storage.shared.getAppDirectory(for: app) else { return }

        let fm = FileManager.default
        var results: [ExtractableFile] = []

        // Frameworks directory
        let frameworksDir = appDir.appendingPathComponent("Frameworks")
        if fm.fileExists(atPath: frameworksDir.path) {
            let contents = (try? fm.contentsOfDirectory(at: frameworksDir, includingPropertiesForKeys: nil)) ?? []
            for file in contents {
                let ext = file.pathExtension.lowercased()
                if ext == "dylib" || ext == "framework" {
                    results.append(ExtractableFile(url: file, category: "Frameworks"))
                }
            }
        }

        // Root dylibs
        let rootContents = (try? fm.contentsOfDirectory(at: appDir, includingPropertiesForKeys: nil)) ?? []
        for file in rootContents {
            if file.pathExtension.lowercased() == "dylib" {
                results.append(ExtractableFile(url: file, category: "动态库"))
            }
        }

        allFiles = results
    }

    private func _extractSelected() {
        isExtracting = true

        Task.detached {
            let fm = FileManager.default
            let tmpDir = fm.temporaryDirectory.appendingPathComponent("Extract_\(UUID().uuidString)")

            do {
                try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

                let filesToExtract = allFiles.filter { selectedFiles.contains($0.id) }
                for file in filesToExtract {
                    let dest = tmpDir.appendingPathComponent(file.name)
                    try? fm.removeItem(at: dest)
                    try fm.copyItem(at: file.url, to: dest)
                }

                // Create zip
                let appName = app.name ?? "Libraries"
                let zipName = "\(appName)_libs_\(Int(Date().timeIntervalSince1970)).zip"
                let zipPath = fm.tweaks.appendingPathComponent(zipName)

                try? fm.createDirectoryIfNeeded(at: fm.tweaks)
                try? fm.removeItem(at: zipPath)

                Zip.addCustomFileExtension("zip")
                try Zip.zipFiles(paths: filesToExtract.map { tmpDir.appendingPathComponent($0.name) }, zipFilePath: zipPath, password: nil, progress: nil)

                try? fm.removeItem(at: tmpDir)

                await MainActor.run {
                    isExtracting = false
                    ToastManager.shared.show("已提取 \(filesToExtract.count) 个库文件并压缩为 ZIP", style: .success)
                    dismiss()
                }
            } catch {
                try? fm.removeItem(at: tmpDir)
                await MainActor.run {
                    isExtracting = false
                    ToastManager.shared.show("提取失败: \(error.localizedDescription)", style: .error)
                }
            }
        }
    }
}

// MARK: - Plugins Tab (replaces DylibsTab)
struct PluginsTab: View {
    @State private var tweakFiles: [URL] = []
    @State private var isEditing = false
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteAlert = false
    @State private var fileToDelete: URL?
    @State private var showBatchDeleteAlert = false
    @State private var isImporting = false

    private var zipFiles: [URL] { tweakFiles.filter { $0.pathExtension.lowercased() == "zip" } }
    private var debFiles: [URL] { tweakFiles.filter { $0.pathExtension.lowercased() == "deb" } }
    private var dylibFiles: [URL] { tweakFiles.filter { $0.pathExtension.lowercased() == "dylib" } }

    private var allSelectedForDeletion: Bool {
        !tweakFiles.isEmpty && selectedForDeletion.count == tweakFiles.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if tweakFiles.isEmpty && !isEditing {
                ScrollView {
                    _emptyState(icon: "puzzlepiece.extension", text: "暂无插件\n请导入 .zip、.deb 或 .dylib 文件")
                }
            } else {
                // Toolbar
                HStack {
                    if isEditing {
                        Button(action: _toggleSelectAllForDeletion) {
                            HStack(spacing: 6) {
                                Image(systemName: allSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(allSelectedForDeletion ? .accentColor : .secondary)
                                Text(allSelectedForDeletion ? "取消全选" : "全选")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .foregroundColor(.primary)

                        Spacer()

                        if !selectedForDeletion.isEmpty {
                            Button(action: { showBatchDeleteAlert = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("删除 (\(selectedForDeletion.count))")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.red)
                            }
                        }

                        Button("完成") {
                            withAnimation { isEditing = false }
                            selectedForDeletion.removeAll()
                        }
                        .font(.system(size: 13, weight: .semibold))
                    } else {
                        Spacer()
                        if !tweakFiles.isEmpty {
                            Button("编辑") {
                                withAnimation { isEditing = true }
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !zipFiles.isEmpty {
                            _categorySection("ZIP 文件", icon: "doc.zipper", files: zipFiles)
                        }
                        if !debFiles.isEmpty {
                            _categorySection("DEB 包", icon: "shippingbox.fill", files: debFiles)
                        }
                        if !dylibFiles.isEmpty {
                            _categorySection("DYLIB 动态库", icon: "puzzlepiece.extension.fill", files: dylibFiles)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear(perform: _loadTweaks)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let file = fileToDelete {
                    try? FileManager.default.removeItem(at: file)
                    _loadTweaks()
                    ToastManager.shared.show("插件已删除", style: .success)
                }
            }
        } message: {
            Text("确定要删除此插件吗？")
        }
        .alert("批量删除", isPresented: $showBatchDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除 \(selectedForDeletion.count) 个", role: .destructive) {
                _batchDelete()
            }
        } message: {
            Text("确定要删除选中的 \(selectedForDeletion.count) 个插件吗？此操作不可撤销。")
        }
    }

    @ViewBuilder
    private func _categorySection(_ title: String, icon: String, files: [URL]) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(title) (\(files.count))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))

        ForEach(files, id: \.absoluteString) { file in
            _pluginRow(file)
            Divider().padding(.leading, isEditing ? 62 : 16)
        }
    }

    @ViewBuilder
    private func _pluginRow(_ file: URL) -> some View {
        let isSelected = selectedForDeletion.contains(file.absoluteString)

        HStack(spacing: 14) {
            if isEditing {
                Button(action: { _toggleSelection(file) }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .red : .secondary.opacity(0.5))
                }
            }

            _fileIcon(for: file)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.lastPathComponent)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.pathExtension.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(_badgeColor(for: file).opacity(0.15))
                        .foregroundColor(_badgeColor(for: file))
                        .cornerRadius(3)

                    Text(_fileSize(file))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !isEditing {
                Button(action: {
                    fileToDelete = file
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing { _toggleSelection(file) }
        }
    }

    @ViewBuilder
    private func _fileIcon(for file: URL) -> some View {
        switch file.pathExtension.lowercased() {
        case "zip": Image(systemName: "doc.zipper")
        case "deb": Image(systemName: "shippingbox.fill")
        default: Image(systemName: "puzzlepiece.extension.fill")
        }
    }

    private func _badgeColor(for file: URL) -> Color {
        switch file.pathExtension.lowercased() {
        case "zip": return .purple
        case "deb": return .orange
        default: return .blue
        }
    }

    private func _fileSize(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? Int64 ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func _toggleSelection(_ file: URL) {
        let key = file.absoluteString
        if selectedForDeletion.contains(key) {
            selectedForDeletion.remove(key)
        } else {
            selectedForDeletion.insert(key)
        }
    }

    private func _toggleSelectAllForDeletion() {
        if allSelectedForDeletion {
            selectedForDeletion.removeAll()
        } else {
            selectedForDeletion = Set(tweakFiles.map(\.absoluteString))
        }
    }

    private func _batchDelete() {
        let fm = FileManager.default
        var count = 0
        for file in tweakFiles {
            if selectedForDeletion.contains(file.absoluteString) {
                try? fm.removeItem(at: file)
                count += 1
            }
        }
        selectedForDeletion.removeAll()
        isEditing = false
        _loadTweaks()
        ToastManager.shared.show("已删除 \(count) 个插件", style: .success)
    }

    private func _loadTweaks() {
        let fm = FileManager.default
        try? fm.createDirectoryIfNeeded(at: fm.tweaks)

        let files = (try? fm.contentsOfDirectory(at: fm.tweaks, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)) ?? []

        tweakFiles = files.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "dylib" || ext == "deb" || ext == "zip"
        }.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return dateA > dateB
        }
    }
}

// MARK: - Signed Apps Tab
struct SignedAppsTab: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
        animation: .default
    )
    private var apps: FetchedResults<Signed>

    @State private var selectedApp: Signed?
    @State private var showingInstall = false
    @State private var showDeleteAlert = false
    @State private var appToDelete: Signed?
    @State private var showingInfo = false

    var body: some View {
        ScrollView {
            if apps.isEmpty {
                _emptyState(icon: "checkmark.seal", text: "暂无已签名应用\n签名 IPA 后将显示在此处")
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(apps, id: \.uuid) { app in
                        SignedAppCardView(app: app) {
                            selectedApp = app
                            showingInstall = true
                        } onDelete: {
                            appToDelete = app
                            showDeleteAlert = true
                        } onShare: {
                            _shareApp(app)
                        } onInfo: {
                            selectedApp = app
                            showingInfo = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let app = appToDelete {
                    Storage.shared.deleteApp(for: app)
                    ToastManager.shared.show("已删除", style: .success)
                }
            }
        } message: {
            Text("确定要删除此已签名应用吗？")
        }
        .sheet(isPresented: $showingInstall) {
            if let app = selectedApp {
                InstallPreviewView(app: app)
                    .presentationDetents([.height(200)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingInfo) {
            if let app = selectedApp {
                LibraryInfoView(app: app)
            }
        }
    }

    private func _shareApp(_ app: AppInfoPresentable) {
        guard let appDir = Storage.shared.getUuidDirectory(for: app) else { return }
        UIActivityViewController.show(activityItems: [appDir])
    }
}

// MARK: - App Card View
struct AppCardView: View {
    let app: AppInfoPresentable
    let actions: [CardAction]

    struct CardAction {
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                FRAppIconView(app: app, size: 56)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name ?? "未知")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    Text(app.identifier ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("v\(app.version ?? "?")")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)

                        if let date = app.date {
                            Text(date, style: .date)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)

            Divider()

            HStack(spacing: 0) {
                ForEach(actions.indices, id: \.self) { index in
                    Button(action: actions[index].action) {
                        VStack(spacing: 4) {
                            Image(systemName: actions[index].icon)
                                .font(.system(size: 16))
                            Text(actions[index].title)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(actions[index].color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }

                    if index < actions.count - 1 {
                        Divider()
                            .frame(height: 30)
                    }
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

// MARK: - Tweak Card View (kept for backward compat)
struct TweakCardView: View {
    let url: URL
    let onDelete: () -> Void

    private var fileSize: String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? Int64 ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private var fileIcon: String {
        switch url.pathExtension.lowercased() {
        case "deb": return "shippingbox.fill"
        case "zip": return "doc.zipper"
        default: return "puzzlepiece.extension.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: fileIcon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(url.pathExtension.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(3)

                    Text(fileSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Signed App Card View
struct SignedAppCardView: View {
    let app: Signed
    let onInstall: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    let onInfo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                FRAppIconView(app: app, size: 56)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name ?? "未知")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    Text(app.identifier ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("v\(app.version ?? "?")")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .foregroundColor(.green)
                            .cornerRadius(4)

                        if let cert = app.certificate {
                            FRExpirationPillView(
                                title: "安装",
                                revoked: cert.revoked,
                                expiration: cert.expiration?.expirationInfo()
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding(14)

            Divider()

            HStack(spacing: 0) {
                _actionBtn("安装", icon: "arrow.down.circle", color: .green, action: onInstall)
                Divider().frame(height: 30)
                _actionBtn("分享", icon: "square.and.arrow.up", color: .blue, action: onShare)
                Divider().frame(height: 30)
                _actionBtn("详情", icon: "info.circle", color: .accentColor, action: onInfo)
                Divider().frame(height: 30)
                _actionBtn("删除", icon: "trash", color: .red, action: onDelete)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    @ViewBuilder
    private func _actionBtn(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Empty State Helper
@ViewBuilder
func _emptyState(icon: String, text: String) -> some View {
    VStack(spacing: 16) {
        Spacer()
        Image(systemName: icon)
            .font(.system(size: 48))
            .foregroundColor(.secondary.opacity(0.5))
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        Spacer()
    }
    .frame(maxWidth: .infinity, minHeight: 400)
}
