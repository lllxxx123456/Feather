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
                        "P12 Certificate",
                        icon: "key.fill",
                        file: p12URL,
                        action: { isImportingP12 = true }
                    )

                    _fileButton(
                        "Provisioning Profile",
                        icon: "doc.text.fill",
                        file: provisionURL,
                        action: { isImportingProvision = true }
                    )
                } header: {
                    Text("Certificate Files")
                }

                Section {
                    Button(action: { isImportingZip = true }) {
                        HStack {
                            Image(systemName: "doc.zipper")
                                .foregroundColor(.accentColor)
                            Text("Import ZIP Archive")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                        }
                    }
                } header: {
                    Text("Import from ZIP")
                } footer: {
                    Text("ZIP should contain .p12 and .mobileprovision files")
                }

                Section {
                    SecureField("Certificate Password", text: $p12Password)
                } header: {
                    Text("Password")
                } footer: {
                    Text("Enter the password for the P12 private key. Leave blank if none.")
                }

                Section {
                    TextField("Nickname (Optional)", text: $certificateName)
                }
            }
            .navigationTitle("Import Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { _saveCertificate() }
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

            // Search recursively for .p12 and .mobileprovision
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
                ToastManager.shared.show("Found certificate files in ZIP", style: .success)
            } else {
                ToastManager.shared.show("ZIP missing certificate files", style: .error)
            }

            // Check for password file
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
            ToastManager.shared.show("Failed to extract ZIP", style: .error)
        }
    }

    private func _saveCertificate() {
        guard
            let p12URL = p12URL,
            let provisionURL = provisionURL,
            FR.checkPasswordForCertificate(for: p12URL, with: p12Password, using: provisionURL)
        else {
            ToastManager.shared.show("Invalid password, please check and try again", style: .error)
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
                ToastManager.shared.show("Certificate imported!", style: .success)
                dismiss()
            }
        }
    }
}
