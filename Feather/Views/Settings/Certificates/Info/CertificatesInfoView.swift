//
//  CertificatesInfoView.swift
//  Feather778
//

import SwiftUI
import NimbleViews

struct CertificatesInfoView: View {
    @Environment(\.dismiss) var dismiss
    @State var data: Certificate?

    var cert: CertificatePair

    var body: some View {
        NavigationView {
            Form {
                Section {} header: {
                    VStack(spacing: 12) {
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.accentColor)

                        Text(cert.nickname ?? data?.Name ?? "Certificate")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }

                if let data {
                    _basicInfoSection(data: data)
                    _statusSection(data: data)
                    _entitlementsSection(data: data)
                    _deviceSection(data: data)
                    _miscSection(data: data)
                }

                Section {
                    Button("Open in Files", systemImage: "folder") {
                        if let url = Storage.shared.getUuidDirectory(for: cert)?.toSharedDocumentsURL() {
                            UIApplication.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Certificate Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            data = Storage.shared.getProvisionFileDecoded(for: cert)
        }
    }

    @ViewBuilder
    private func _basicInfoSection(data: Certificate) -> some View {
        Section(header: Text("Basic Info")) {
            _row("Common Name", value: data.Name)
            _row("AppID Name", value: data.AppIDName)
            _row("Team Name", value: data.TeamName)
            if let prefix = data.ApplicationIdentifierPrefix?.first {
                _row("Team ID", value: prefix)
            }
        }
    }

    @ViewBuilder
    private func _statusSection(data: Certificate) -> some View {
        Section(header: Text("Status")) {
            HStack {
                Text("Expiration")
                Spacer()
                let info = data.ExpirationDate.expirationInfo()
                Text(info.formatted)
                    .foregroundColor(info.color)
            }
            .copyableText(data.ExpirationDate.expirationInfo().formatted)

            HStack {
                Text("Certificate Status")
                Spacer()
                Text(cert.revoked ? "Revoked" : "Valid")
                    .foregroundColor(cert.revoked ? .red : .green)
                    .font(.system(size: 14, weight: .semibold))
            }

            HStack {
                Text("Platform")
                Spacer()
                Text(data.Platform.joined(separator: ", "))
                    .foregroundColor(.secondary)
            }

            if let ppq = data.PPQCheck {
                HStack {
                    Text("PPQCheck")
                    Spacer()
                    Text(ppq ? "Yes" : "No")
                        .foregroundColor(ppq ? .orange : .green)
                }
            }

            HStack {
                Text("Device Support")
                Spacer()
                if data.ProvisionsAllDevices == true {
                    Text("All Devices")
                        .foregroundColor(.green)
                } else {
                    Text("Limited")
                        .foregroundColor(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func _entitlementsSection(data: Certificate) -> some View {
        if let entitlements = data.Entitlements {
            Section(header: Text("Certificate Permissions")) {
                NavigationLink("View All Permissions") {
                    CertificatesInfoEntitlementView(entitlements: entitlements)
                }

                // Show key entitlements inline
                if let taskAllow = entitlements["get-task-allow"]?.value as? Bool {
                    _row("Debug (get-task-allow)", value: taskAllow ? "Yes" : "No")
                }

                if let appGroups = entitlements["com.apple.security.application-groups"]?.value as? [String] {
                    NavigationLink("App Groups (\(appGroups.count))") {
                        List {
                            ForEach(appGroups, id: \.self) { group in
                                Text(group)
                                    .font(.system(size: 13))
                                    .copyableText(group)
                            }
                        }
                        .navigationTitle("App Groups")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func _deviceSection(data: Certificate) -> some View {
        if let devices = data.ProvisionedDevices, !devices.isEmpty {
            Section(header: Text("Bound Devices (\(devices.count))")) {
                ForEach(devices, id: \.self) { udid in
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.secondary)
                        Text(udid)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .copyableText(udid)
                }
            }
        }
    }

    @ViewBuilder
    private func _miscSection(data: Certificate) -> some View {
        Section(header: Text("Other Info")) {
            if let identifiers = data.TeamIdentifier.first {
                _row("Team ID", value: identifiers)
            }
            _row("UUID", value: data.UUID)
            _row("Version", value: "\(data.Version)")
            _row("Validity (days)", value: "\(data.TimeToLive)")

            if let managed = data.IsXcodeManaged {
                _row("Xcode Managed", value: managed ? "Yes" : "No")
            }
        }
    }

    @ViewBuilder
    private func _row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .copyableText(value)
    }
}
