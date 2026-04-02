//
//  HomeView.swift (replaces LibraryView)
//  Feather778
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import UniformTypeIdentifiers

// MARK: - HomeView
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var selectedTab: Int = 0
    private let tabTitles = ["Unsigned", "Dynamic Libs", "Signed"]

    @State private var isImportingFile = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                _segmentedHeader()

                TabView(selection: $selectedTab) {
                    UnsignedAppsTab()
                        .environment(\.managedObjectContext, viewContext)
                        .tag(0)
                    DylibsTab()
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
                            Label("Import from Files", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $isImportingFile) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.ipa, .tipa, .deb, .dylib],
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
        default:
            ToastManager.shared.show("Unsupported file type", style: .error)
        }
    }

    private func _importTweak(_ url: URL) {
        let fm = FileManager.default
        try? fm.createDirectoryIfNeeded(at: fm.tweaks)

        let dest = fm.tweaks.appendingPathComponent(url.lastPathComponent)
        do {
            try? fm.removeFileIfNeeded(at: dest)
            try fm.copyItem(at: url, to: dest)
            ToastManager.shared.show("Plugin imported", style: .success)
        } catch {
            ToastManager.shared.show("Import failed: \(error.localizedDescription)", style: .error)
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
    @State private var showingSignView = false
    @State private var showDeleteAlert = false
    @State private var appToDelete: Imported?

    var body: some View {
        ScrollView {
            if apps.isEmpty {
                _emptyState(icon: "doc.zipper", text: "No unsigned apps\nImport IPA files to get started")
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(apps, id: \.uuid) { app in
                        AppCardView(
                            app: app,
                            actions: [
                                .init(title: "Sign", icon: "signature", color: .accentColor) {
                                    selectedApp = AnyApp(base: app)
                                    showingSignView = true
                                },
                                .init(title: "Extract", icon: "shippingbox", color: .orange) {
                                    _extractLibs(app)
                                },
                                .init(title: "Share", icon: "square.and.arrow.up", color: .blue) {
                                    _shareApp(app)
                                },
                                .init(title: "Delete", icon: "trash", color: .red) {
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
        .alert("Confirm Delete", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let app = appToDelete {
                    Storage.shared.deleteApp(for: app)
                    ToastManager.shared.show("Deleted", style: .success)
                }
            }
        } message: {
            Text("Are you sure you want to delete this app? This cannot be undone.")
        }
        .fullScreenCover(isPresented: $showingSignView) {
            if let app = selectedApp {
                SigningView(app: app.base)
            }
        }
    }

    private func _extractLibs(_ app: AppInfoPresentable) {
        guard let appDir = Storage.shared.getAppDirectory(for: app) else {
            ToastManager.shared.show("App not found", style: .error)
            return
        }

        let frameworksDir = appDir.appendingPathComponent("Frameworks")
        let fm = FileManager.default

        guard fm.fileExists(atPath: frameworksDir.path) else {
            ToastManager.shared.show("No frameworks found", style: .info)
            return
        }

        do {
            let contents = try fm.contentsOfDirectory(at: frameworksDir, includingPropertiesForKeys: nil)
            var count = 0
            try fm.createDirectoryIfNeeded(at: fm.tweaks)

            for file in contents {
                let ext = file.pathExtension.lowercased()
                if ext == "dylib" || ext == "framework" {
                    let dest = fm.tweaks.appendingPathComponent(file.lastPathComponent)
                    try? fm.removeFileIfNeeded(at: dest)
                    try fm.copyItem(at: file, to: dest)
                    count += 1
                }
            }

            ToastManager.shared.show("Extracted \(count) libraries", style: .success)
        } catch {
            ToastManager.shared.show("Extraction failed", style: .error)
        }
    }

    private func _shareApp(_ app: AppInfoPresentable) {
        guard let appDir = Storage.shared.getUuidDirectory(for: app) else { return }
        UIActivityViewController.show(activityItems: [appDir])
    }
}

// MARK: - Dylibs Tab
struct DylibsTab: View {
    @State private var tweakFiles: [URL] = []
    @State private var showDeleteAlert = false
    @State private var fileToDelete: URL?
    @State private var isImporting = false

    var body: some View {
        ScrollView {
            if tweakFiles.isEmpty {
                _emptyState(icon: "puzzlepiece.extension", text: "No plugins\nImport .deb or .dylib files")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(tweakFiles, id: \.absoluteString) { file in
                        TweakCardView(url: file) {
                            fileToDelete = file
                            showDeleteAlert = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .onAppear(perform: _loadTweaks)
        .alert("Confirm Delete", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    try? FileManager.default.removeItem(at: file)
                    _loadTweaks()
                    ToastManager.shared.show("Plugin deleted", style: .success)
                }
            }
        } message: {
            Text("Delete this plugin?")
        }
    }

    private func _loadTweaks() {
        let fm = FileManager.default
        try? fm.createDirectoryIfNeeded(at: fm.tweaks)

        let files = (try? fm.contentsOfDirectory(at: fm.tweaks, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)) ?? []

        tweakFiles = files.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "dylib" || ext == "deb"
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
                _emptyState(icon: "checkmark.seal", text: "No signed apps\nSign an IPA to see it here")
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
        .alert("Confirm Delete", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let app = appToDelete {
                    Storage.shared.deleteApp(for: app)
                    ToastManager.shared.show("Deleted", style: .success)
                }
            }
        } message: {
            Text("Delete this signed app?")
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
                    Text(app.name ?? "Unknown")
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

// MARK: - Tweak Card View
struct TweakCardView: View {
    let url: URL
    let onDelete: () -> Void

    private var fileSize: String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? Int64 ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private var fileIcon: String {
        url.pathExtension.lowercased() == "deb" ? "shippingbox.fill" : "puzzlepiece.extension.fill"
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
                    Text(app.name ?? "Unknown")
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
                                title: "Install",
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
                _actionBtn("Install", icon: "arrow.down.circle", color: .green, action: onInstall)
                Divider().frame(height: 30)
                _actionBtn("Share", icon: "square.and.arrow.up", color: .blue, action: onShare)
                Divider().frame(height: 30)
                _actionBtn("Info", icon: "info.circle", color: .accentColor, action: onInfo)
                Divider().frame(height: 30)
                _actionBtn("Delete", icon: "trash", color: .red, action: onDelete)
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
