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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .withToast()
    }

    // MARK: - Default Signing Config
    @ViewBuilder
    private func _signingConfigSection() -> some View {
        Section(header: Text("Default Signing Config")) {
            Toggle(isOn: $optionsManager.options.autoFixJailbreakDeps) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-fix Jailbreak Dependencies")
                        .font(.system(size: 14, weight: .medium))
                    Text("Automatically adjusts plugin dependencies and directory structure for device compatibility")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.autoFixJailbreakDeps) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.enableFileAccess) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Enable File Access")
                        .font(.system(size: 14, weight: .medium))
                    Text("View signed app data in the iOS Files app")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.enableFileAccess) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.removeAppJumps) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Remove App Redirects")
                        .font(.system(size: 14, weight: .medium))
                    Text("Remove URL Scheme redirects from the app")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.removeAppJumps) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.removeMinVersionLimit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Remove Min Version Limit")
                        .font(.system(size: 14, weight: .medium))
                    Text("Remove the minimum iOS version requirement")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.removeMinVersionLimit) { _ in optionsManager.saveOptions() }
        }

        Section {
            Toggle("Include App Name", isOn: Binding(
                get: { optionsManager.options.packageNameRule & 1 != 0 },
                set: { optionsManager.options.packageNameRule = $0 ? optionsManager.options.packageNameRule | 1 : optionsManager.options.packageNameRule & ~1; optionsManager.saveOptions() }
            ))
            Toggle("Include Version", isOn: Binding(
                get: { optionsManager.options.packageNameRule & 2 != 0 },
                set: { optionsManager.options.packageNameRule = $0 ? optionsManager.options.packageNameRule | 2 : optionsManager.options.packageNameRule & ~2; optionsManager.saveOptions() }
            ))
            Toggle("Include Timestamp", isOn: Binding(
                get: { optionsManager.options.packageNameRule & 4 != 0 },
                set: { optionsManager.options.packageNameRule = $0 ? optionsManager.options.packageNameRule | 4 : optionsManager.options.packageNameRule & ~4; optionsManager.saveOptions() }
            ))
        } header: {
            Text("Package Filename")
        } footer: {
            Text("At least one option must be selected for the output filename")
        }

        Section(header: Text("Post-Signing Actions")) {
            Toggle(isOn: $optionsManager.options.autoInstallAfterSign) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-install After Signing")
                        .font(.system(size: 14, weight: .medium))
                    Text("Prompt to install the IPA immediately after signing")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.autoInstallAfterSign) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.useLocalServer) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Local Server Install")
                        .font(.system(size: 14, weight: .medium))
                    Text("Use local server with itms-services:// for fully local installation")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: optionsManager.options.useLocalServer) { _ in optionsManager.saveOptions() }

            Toggle(isOn: $optionsManager.options.deleteAfterSign) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Delete After Signing")
                        .font(.system(size: 14, weight: .medium))
                    Text("Automatically delete the signed IPA file after signing")
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
        Section(header: Text("Installation")) {
            NavigationLink(destination: InstallationView()) {
                HStack {
                    Image(systemName: "arrow.down.app")
                        .foregroundColor(.accentColor)
                    Text("Installation Method")
                }
            }
        }
    }

    // MARK: - Directories
    @ViewBuilder
    private func _directoriesSection() -> some View {
        Section(header: Text("Directories")) {
            _directoryLink("Unsigned Apps", icon: "doc.zipper", url: FileManager.default.unsigned)
            _directoryLink("Signed Apps", icon: "checkmark.seal", url: FileManager.default.signed)
            _directoryLink("Certificates", icon: "person.text.rectangle", url: FileManager.default.certificates)
            _directoryLink("Plugins", icon: "puzzlepiece.extension", url: FileManager.default.tweaks)
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
        Section(header: Text("About")) {
            HStack {
                Text("Version")
                Spacer()
                Text("\(Bundle.main.version) (\(Bundle.main.buildNumber))")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("App Name")
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
            Button("Reset All Settings", role: .destructive) {
                showResetAlert = true
            }

            Button("Clear All Data", role: .destructive) {
                showClearDataAlert = true
            }
        }
        .alert("Reset Settings", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                optionsManager.resetToDefaults()
                ToastManager.shared.show("Settings reset", style: .success)
            }
        } message: {
            Text("This will reset all settings to default values.")
        }
        .alert("Clear Data", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                ResetView.clearWorkCache()
                ToastManager.shared.show("Cache cleared", style: .success)
            }
        } message: {
            Text("This will clear the work cache. Your apps and certificates will not be affected.")
        }
    }
}

// Extension for Bundle build number
extension Bundle {
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
