//
//  SettingsView.swift
//  Feather778
//

import SwiftUI
import NimbleViews

struct SettingsView: View {
    @ObservedObject private var optionsManager = OptionsManager.shared

    @State private var showResetAlert = false
    @State private var showClearDataAlert = false

    var body: some View {
        NavigationView {
            Form {
                _signingConfigSection()
                _installationSection()
                _directoriesSection()
                _aboutSection()
                _resetSection()
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .withToast()
    }

    // MARK: - Default Signing Config
    @ViewBuilder
    private func _signingConfigSection() -> some View {
        Section(header: Text("默认签名配置")) {
            Toggle(isOn: $optionsManager.options.autoFixJailbreakDeps) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动修复越狱依赖")
                        .font(.system(size: 14, weight: .medium))
                    Text("自动调整插件依赖和目录结构以兼容设备")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.autoFixJailbreakDeps) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.enableFileAccess) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("启用文件访问")
                        .font(.system(size: 14, weight: .medium))
                    Text("在 iOS 文件应用中查看已签名应用数据")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.enableFileAccess) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.removeAppJumps) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("移除应用跳转")
                        .font(.system(size: 14, weight: .medium))
                    Text("移除应用的 URL Scheme 跳转")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.removeAppJumps) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.removeMinVersionLimit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("移除最低版本限制")
                        .font(.system(size: 14, weight: .medium))
                    Text("移除 iOS 最低版本要求")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.removeMinVersionLimit) { _ in optionsManager.saveOptions() }
        }

        Section {
            Toggle("包含应用名称", isOn: Binding(
                get: { optionsManager.options.packageNameRule & 1 != 0 },
                set: { optionsManager.options.packageNameRule = $0 ? optionsManager.options.packageNameRule | 1 : optionsManager.options.packageNameRule & ~1; optionsManager.saveOptions() }
            ))
            Toggle("包含版本号", isOn: Binding(
                get: { optionsManager.options.packageNameRule & 2 != 0 },
                set: { optionsManager.options.packageNameRule = $0 ? optionsManager.options.packageNameRule | 2 : optionsManager.options.packageNameRule & ~2; optionsManager.saveOptions() }
            ))
            Toggle("包含时间戳", isOn: Binding(
                get: { optionsManager.options.packageNameRule & 4 != 0 },
                set: { optionsManager.options.packageNameRule = $0 ? optionsManager.options.packageNameRule | 4 : optionsManager.options.packageNameRule & ~4; optionsManager.saveOptions() }
            ))
        } header: {
            Text("输出文件名")
        } footer: {
            Text("至少需要选择一个选项作为输出文件名")
        }

        Section(header: Text("签名后操作")) {
            Toggle(isOn: $optionsManager.options.autoInstallAfterSign) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("签名后自动安装")
                        .font(.system(size: 14, weight: .medium))
                    Text("签名完成后立即提示安装 IPA")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.autoInstallAfterSign) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.useLocalServer) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本地服务器安装")
                        .font(.system(size: 14, weight: .medium))
                    Text("使用本地服务器通过 itms-services:// 进行完全本地安装")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.useLocalServer) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.deleteAfterSign) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("签名后删除原文件")
                        .font(.system(size: 14, weight: .medium))
                    Text("签名完成后自动删除已签名的 IPA 文件")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.deleteAfterSign) { _ in optionsManager.saveOptions() }
        }
    }

    // MARK: - Installation
    @ViewBuilder
    private func _installationSection() -> some View {
        Section(header: Text("安装")) {
            NavigationLink(destination: InstallationView()) {
                HStack {
                    Image(systemName: "arrow.down.app")
                        .foregroundColor(.accentColor)
                    Text("安装方式")
                }
            }
        }
    }

    // MARK: - Directories
    @ViewBuilder
    private func _directoriesSection() -> some View {
        Section(header: Text("目录")) {
            _directoryLink("未签名应用", icon: "doc.zipper", url: FileManager.default.unsigned)
            _directoryLink("已签名应用", icon: "checkmark.seal", url: FileManager.default.signed)
            _directoryLink("证书", icon: "person.text.rectangle", url: FileManager.default.certificates)
            _directoryLink("插件", icon: "puzzlepiece.extension", url: FileManager.default.tweaks)
        }
    }

    @ViewBuilder
    private func _directoryLink(_ title: String, icon: String, url: URL) -> some View {
        Button(action: {
            if let shared = url.toSharedDocumentsURL() {
                UIApplication.open(shared)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
        }
    }

    // MARK: - About
    @ViewBuilder
    private func _aboutSection() -> some View {
        Section(header: Text("关于")) {
            HStack {
                Text("版本")
                Spacer()
                Text("\(Bundle.main.version) (\(Bundle.main.buildNumber))")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("应用名称")
                Spacer()
                Text("Feather778")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Reset
    @ViewBuilder
    private func _resetSection() -> some View {
        Section {
            Button("重置所有设置", role: .destructive) {
                showResetAlert = true
            }

            Button("清除所有数据", role: .destructive) {
                showClearDataAlert = true
            }
        }
        .alert("重置设置", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                optionsManager.resetToDefaults()
                ToastManager.shared.show("设置已重置", style: .success)
            }
        } message: {
            Text("确定要将所有设置恢复为默认值吗？")
        }
        .alert("清除数据", isPresented: $showClearDataAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                ResetView.clearWorkCache()
                ToastManager.shared.show("缓存已清除", style: .success)
            }
        } message: {
            Text("这将清除工作缓存。您的应用和证书不会受到影响。")
        }
    }
}

// Extension for Bundle build number
extension Bundle {
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
