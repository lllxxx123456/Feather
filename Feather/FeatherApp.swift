//
//  FeatherApp.swift
//  Feather778
//

import SwiftUI
import Nuke
import IDeviceSwift
import OSLog
import Zip

@main
struct FeatherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let heartbeat = HeartbeatManager.shared

    @StateObject var downloadManager = DownloadManager.shared
    let storage = Storage.shared

    var body: some Scene {
        WindowGroup {
            VStack {
                DownloadHeaderView(downloadManager: downloadManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                VariedTabbarView()
                    .environment(\.managedObjectContext, storage.context)
                    .onOpenURL(perform: _handleURL)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            .animation(.smooth, value: downloadManager.manualDownloads.description)
            .onReceive(NotificationCenter.default.publisher(for: .heartbeatInvalidHost)) { _ in
                DispatchQueue.main.async {
                    UIAlertController.showAlertWithOk(
                        title: "InvalidHostID",
                        message: "Your pairing file is invalid and is incompatible with your device, please import a valid pairing file."
                    )
                }
            }
            .onAppear {
                if let style = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "Feather.userInterfaceStyle")) {
                    UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
                }

                UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#848ef9"))
            }
        }
    }

    private func _handleURL(_ url: URL) {
        // Handle feather778:// URL scheme
        if url.scheme == "feather778" {
            if url.host == "import-certificate" {
                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                    let queryItems = components.queryItems
                else { return }

                func queryValue(_ name: String) -> String? {
                    queryItems.first(where: { $0.name == name })?.value?.removingPercentEncoding
                }

                guard
                    let p12Base64 = queryValue("p12"),
                    let provisionBase64 = queryValue("mobileprovision"),
                    let passwordBase64 = queryValue("password"),
                    let passwordData = Data(base64Encoded: passwordBase64),
                    let password = String(data: passwordData, encoding: .utf8)
                else { return }

                let generator = UINotificationFeedbackGenerator()
                generator.prepare()

                guard
                    let p12URL = FileManager.default.decodeAndWrite(base64: p12Base64, pathComponent: ".p12"),
                    let provisionURL = FileManager.default.decodeAndWrite(base64: provisionBase64, pathComponent: ".mobileprovision"),
                    FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL)
                else {
                    generator.notificationOccurred(.error)
                    return
                }

                FR.handleCertificateFiles(
                    p12URL: p12URL,
                    provisionURL: provisionURL,
                    p12Password: password
                ) { error in
                    if let error = error {
                        UIAlertController.showAlertWithOk(title: "Error", message: error.localizedDescription)
                    } else {
                        generator.notificationOccurred(.success)
                        ToastManager.shared.show("Certificate imported!", style: .success)
                    }
                }
                return
            }

            if url.host == "export-certificate" {
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
                let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
                guard let callbackTemplate = queryItems["callback_template"]?.removingPercentEncoding else { return }
                FR.exportCertificateAndOpenUrl(using: callbackTemplate)
            }

            if let fullPath = url.validatedScheme(after: "/source/") {
                FR.handleSource(fullPath) { }
            }

            if let fullPath = url.validatedScheme(after: "/install/"),
               let downloadURL = URL(string: fullPath) {
                _ = DownloadManager.shared.startDownload(from: downloadURL)
            }
        } else {
            // Handle file sharing imports
            let ext = url.pathExtension.lowercased()

            switch ext {
            case "ipa", "tipa":
                if FileManager.default.isFileFromFileProvider(at: url) {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    FR.handlePackageFile(url) { error in
                        url.stopAccessingSecurityScopedResource()
                        if error == nil {
                            ToastManager.shared.show("IPA imported!", style: .success)
                        }
                    }
                } else {
                    FR.handlePackageFile(url) { error in
                        if error == nil {
                            ToastManager.shared.show("IPA imported!", style: .success)
                        }
                    }
                }

            case "deb", "dylib":
                _importTweakFile(url)

            case "zip":
                _handleZipImport(url)

            case "p12":
                // Store temporarily for later use with CertificatesAddView
                let fm = FileManager.default
                let dest = fm.temporaryDirectory.appendingPathComponent("pending_cert.p12")
                try? fm.removeFileIfNeeded(at: dest)
                try? fm.copyItem(at: url, to: dest)
                ToastManager.shared.show("P12 file ready - open Certificates to complete import", style: .info)

            case "mobileprovision":
                let fm = FileManager.default
                let dest = fm.temporaryDirectory.appendingPathComponent("pending_cert.mobileprovision")
                try? fm.removeFileIfNeeded(at: dest)
                try? fm.copyItem(at: url, to: dest)
                ToastManager.shared.show("Profile ready - open Certificates to complete import", style: .info)

            default:
                break
            }
        }
    }

    private func _importTweakFile(_ url: URL) {
        let fm = FileManager.default
        try? fm.createDirectoryIfNeeded(at: fm.tweaks)

        let shouldAccessSecurity = fm.isFileFromFileProvider(at: url)
        if shouldAccessSecurity {
            guard url.startAccessingSecurityScopedResource() else { return }
        }

        let dest = fm.tweaks.appendingPathComponent(url.lastPathComponent)
        do {
            try? fm.removeFileIfNeeded(at: dest)
            try fm.copyItem(at: url, to: dest)
            ToastManager.shared.show("Plugin imported!", style: .success)
        } catch {
            ToastManager.shared.show("Import failed", style: .error)
        }

        if shouldAccessSecurity {
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func _handleZipImport(_ url: URL) {
        // Check if ZIP contains certificate files
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("ZipImport_\(UUID().uuidString)")

        Task.detached {
            do {
                try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

                Zip.addCustomFileExtension("zip")
                try Zip.unzipFile(url, destination: tmpDir, overwrite: true, password: nil)

                var foundP12: URL?
                var foundProvision: URL?
                var foundPassword: String?

                func search(in dir: URL) throws {
                    let items = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    for item in items {
                        var isDir: ObjCBool = false
                        fm.fileExists(atPath: item.path, isDirectory: &isDir)
                        if isDir.boolValue {
                            try search(in: item)
                        } else {
                            let ext = item.pathExtension.lowercased()
                            if ext == "p12" { foundP12 = item }
                            if ext == "mobileprovision" { foundProvision = item }
                            if ext == "txt" || item.lastPathComponent.lowercased().contains("password") {
                                foundPassword = try? String(contentsOf: item, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }

                try search(in: tmpDir)

                if let p12 = foundP12, let provision = foundProvision {
                    let password = foundPassword ?? ""

                    await MainActor.run {
                        if FR.checkPasswordForCertificate(for: p12, with: password, using: provision) {
                            FR.handleCertificateFiles(
                                p12URL: p12,
                                provisionURL: provision,
                                p12Password: password
                            ) { error in
                                if error == nil {
                                    ToastManager.shared.show("Certificate imported from ZIP!", style: .success)
                                } else {
                                    ToastManager.shared.show("Certificate import failed", style: .error)
                                }
                                try? fm.removeItem(at: tmpDir)
                            }
                        } else {
                            ToastManager.shared.show("Invalid certificate password in ZIP", style: .error)
                            try? fm.removeItem(at: tmpDir)
                        }
                    }
                } else {
                    try? fm.removeItem(at: tmpDir)
                    await MainActor.run {
                        ToastManager.shared.show("No certificate files found in ZIP", style: .info)
                    }
                }
            } catch {
                try? fm.removeItem(at: tmpDir)
                await MainActor.run {
                    ToastManager.shared.show("Failed to process ZIP", style: .error)
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _createPipeline()
        _createDocumentsDirectories()
        ResetView.clearWorkCache()
        _addDefaultCertificates()
        return true
    }

    private func _createPipeline() {
        DataLoader.sharedUrlCache.diskCapacity = 0

        let pipeline = ImagePipeline {
            let dataLoader: DataLoader = {
                let config = URLSessionConfiguration.default
                config.urlCache = nil
                return DataLoader(configuration: config)
            }()
            let dataCache = try? DataCache(name: "com.jijiang.feather778.datacache")
            let imageCache = Nuke.ImageCache()
            dataCache?.sizeLimit = 500 * 1024 * 1024
            imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache
            $0.imageCache = imageCache
            $0.dataLoader = dataLoader
            $0.dataCachePolicy = .automatic
            $0.isStoringPreviewsInMemoryCache = false
        }

        ImagePipeline.shared = pipeline
    }

    private func _createDocumentsDirectories() {
        let fileManager = FileManager.default

        let directories: [URL] = [
            fileManager.archives,
            fileManager.certificates,
            fileManager.signed,
            fileManager.unsigned,
            fileManager.tweaks
        ]

        for url in directories {
            try? fileManager.createDirectoryIfNeeded(at: url)
        }
    }

    private func _addDefaultCertificates() {
        guard
            UserDefaults.standard.bool(forKey: "feather.didImportDefaultCertificates") == false,
            let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil)
        else {
            return
        }

        do {
            let folderContents = try FileManager.default.contentsOfDirectory(
                at: signingAssetsURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for folderURL in folderContents {
                guard folderURL.hasDirectoryPath else { continue }

                let certName = folderURL.lastPathComponent

                let p12Url = folderURL.appendingPathComponent("cert.p12")
                let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision")
                let passwordUrl = folderURL.appendingPathComponent("cert.txt")

                guard
                    FileManager.default.fileExists(atPath: p12Url.path),
                    FileManager.default.fileExists(atPath: provisionUrl.path),
                    FileManager.default.fileExists(atPath: passwordUrl.path)
                else {
                    Logger.misc.warning("Skipping \(certName): missing required files")
                    continue
                }

                let password = try String(contentsOf: passwordUrl, encoding: .utf8)

                FR.handleCertificateFiles(
                    p12URL: p12Url,
                    provisionURL: provisionUrl,
                    p12Password: password,
                    certificateName: certName,
                    isDefault: true
                ) { _ in }
            }
            UserDefaults.standard.set(true, forKey: "feather.didImportDefaultCertificates")
        } catch {
            Logger.misc.error("Failed to list signing-assets: \(error)")
        }
    }
}
