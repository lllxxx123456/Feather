//
//  CertificatesInfoView.swift
//  Feather778
//

import SwiftUI
import NimbleViews
import NimbleExtensions

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

                        Text(cert.nickname ?? data?.Name ?? "证书")
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
                    Button("在文件中打开", systemImage: "folder") {
                        if let url = Storage.shared.getUuidDirectory(for: cert)?.toSharedDocumentsURL() {
                            UIApplication.open(url)
                        }
                    }
                }
            }
            .navigationTitle("证书详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onAppear {
            data = Storage.shared.getProvisionFileDecoded(for: cert)
        }
    }

    @ViewBuilder
    private func _basicInfoSection(data: Certificate) -> some View {
        Section(header: Text("基本信息")) {
            _row("通用名称", value: data.Name)
            _row("AppID 名称", value: data.AppIDName)
            _row("团队名称", value: data.TeamName)
            if let prefix = data.ApplicationIdentifierPrefix?.first {
                _row("团队 ID", value: prefix)
            }
        }
    }

    @ViewBuilder
    private func _statusSection(data: Certificate) -> some View {
        Section(header: Text("状态")) {
            HStack {
                Text("到期时间")
                Spacer()
                let info = data.ExpirationDate.expirationInfo()
                Text(info.formatted)
                    .foregroundColor(info.color)
            }
            .copyableText(data.ExpirationDate.expirationInfo().formatted)

            HStack {
                Text("证书状态")
                Spacer()
                Text(cert.revoked ? "已吊销" : "有效")
                    .foregroundColor(cert.revoked ? .red : .green)
                    .font(.system(size: 14, weight: .semibold))
            }

            HStack {
                Text("平台")
                Spacer()
                Text(data.Platform.joined(separator: ", "))
                    .foregroundColor(.secondary)
            }

            if let ppq = data.PPQCheck {
                HStack {
                    Text("PPQCheck")
                    Spacer()
                    Text(ppq ? "是" : "否")
                        .foregroundColor(ppq ? .orange : .green)
                }
            }

            HStack {
                Text("设备支持")
                Spacer()
                if data.ProvisionsAllDevices == true {
                    Text("所有设备")
                        .foregroundColor(.green)
                } else {
                    Text("受限")
                        .foregroundColor(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func _entitlementsSection(data: Certificate) -> some View {
        if let entitlements = data.Entitlements {
            Section(header: Text("证书权限")) {
                NavigationLink("查看所有权限") {
                    CertificatesInfoEntitlementView(entitlements: entitlements)
                }

                if let taskAllow = entitlements["get-task-allow"]?.value as? Bool {
                    _row("调试 (get-task-allow)", value: taskAllow ? "是" : "否")
                }

                if let appGroups = entitlements["com.apple.security.application-groups"]?.value as? [String] {
                    NavigationLink("应用群组 (\(appGroups.count))") {
                        List {
                            ForEach(appGroups, id: \.self) { group in
                                Text(group)
                                    .font(.system(size: 13))
                                    .copyableText(group)
                            }
                        }
                        .navigationTitle("应用群组")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func _deviceSection(data: Certificate) -> some View {
        if let devices = data.ProvisionedDevices, !devices.isEmpty {
            Section(header: Text("绑定设备 (\(devices.count))")) {
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
        Section(header: Text("其他信息")) {
            if let identifiers = data.TeamIdentifier.first {
                _row("团队 ID", value: identifiers)
            }
            _row("UUID", value: data.UUID)
            _row("版本", value: "\(data.Version)")
            _row("有效期（天）", value: "\(data.TimeToLive)")

            if let managed = data.IsXcodeManaged {
                _row("Xcode 管理", value: managed ? "是" : "否")
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
