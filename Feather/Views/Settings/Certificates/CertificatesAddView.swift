//
//  CertificatesAddView.swift
//  Feather778
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers
import Zip

struct CertificatesAddView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var p12URL: URL?
    @State private var provisionURL: URL?
    @State private var p12Password: String = ""
    @State private var certificateName: String = ""

    @State private var isImportingP12 = false
    @State private var isImportingProvision = false
    @State private var isImportingZip = false
    @State private var isSaving = false

    var saveButtonDisabled: Bool {
        p12URL == nil || provisionURL == nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    _fileButton(
                        "P12 证书",
                        icon: "key.fill",
                        file: p12URL,
                        action: { isImportingP12 = true }
                    )

                    _fileButton(
                        "描述文件",
                        icon: "doc.text.fill",
                        file: provisionURL,
                        action: { isImportingProvision = true }
                    )
                } header: {
                    Text("证书文件")
                }

                Section {
                    Button(action: { isImportingZip = true }) {
                        HStack {
                            Image(systemName: "doc.zipper")
                                .foregroundColor(.accentColor)
                            Text("从 ZIP 压缩包导入")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                        }
                    }
                } header: {
                    Text("从 ZIP 导入")
                } footer: {
                    Text("ZIP 压缩包应包含 .p12 和 .mobileprovision 文件")
                }

                Section {
                    SecureField("证书密码", text: $p12Password)
                } header: {
                    Text("密码")
                } footer: {
                    Text("输入 P12 私钥的密码。如果没有密码请留空。")
                }

                Section {
                    TextField("备注名（可选）", text: $certificateName)
                }
            }
            .navigationTitle("导入证书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { _saveCertificate() }
                        .disabled(saveButtonDisabled || isSaving)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .sheet(isPresented: $isImportingP12) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.p12],
                    onDocumentsPicked: { urls in
                        p12URL = urls.first
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isImportingProvision) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.mobileProvision],
                    onDocumentsPicked: { urls in
                        provisionURL = urls.first
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isImportingZip) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.certZip],
                    onDocumentsPicked: { urls in
                        guard let zipURL = urls.first else { return }
                        _handleZipImport(zipURL)
                    }
                )
                .ignoresSafeArea()
            }
            .disabled(isSaving)
        }
    }

    @ViewBuilder
    private func _fileButton(_ title: String, icon: String, file: URL?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(file == nil ? .accentColor : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    if let file = file {
                        Text(file.lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                if file != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "arrow.up.circle")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    private func _handleZipImport(_ zipURL: URL) {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("CertZip_\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

            Zip.addCustomFileExtension("zip")
            try Zip.unzipFile(zipURL, destination: tmpDir, overwrite: true, password: nil)

            _ = try fm.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

            var foundP12: URL?
            var foundProvision: URL?

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
                    }
                }
            }

            try search(in: tmpDir)

            if let p12 = foundP12 { p12URL = p12 }
            if let prov = foundProvision { provisionURL = prov }

            if foundP12 != nil && foundProvision != nil {
                ToastManager.shared.show("已在 ZIP 中找到证书文件", style: .success)
            } else {
                ToastManager.shared.show("ZIP 中缺少证书文件", style: .error)
            }

            let items = try fm.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for item in items {
                let ext = item.pathExtension.lowercased()
                if ext == "txt" || item.lastPathComponent.lowercased().contains("password") {
                    if let pwd = try? String(contentsOf: item, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
                        p12Password = pwd
                    }
                }
            }
        } catch {
            ToastManager.shared.show("ZIP 解压失败", style: .error)
        }
    }

    private func _saveCertificate() {
        guard
            let p12URL = p12URL,
            let provisionURL = provisionURL,
            FR.checkPasswordForCertificate(for: p12URL, with: p12Password, using: provisionURL)
        else {
            ToastManager.shared.show("密码无效，请检查后重试", style: .error)
            return
        }

        isSaving = true

        FR.handleCertificateFiles(
            p12URL: p12URL,
            provisionURL: provisionURL,
            p12Password: p12Password,
            certificateName: certificateName
        ) { error in
            isSaving = false
            if let error = error {
                ToastManager.shared.show(error.localizedDescription, style: .error)
            } else {
                ToastManager.shared.show("证书已导入！", style: .success)
                dismiss()
            }
        }
    }
}
