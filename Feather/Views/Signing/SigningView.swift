//
//  SigningView.swift
//  Feather778
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers
import PhotosUI

struct SigningView: View {
    @Environment(\.dismiss) private var dismiss

    let app: AppInfoPresentable
    @State private var options: Options
    @State private var selectedCertIndex: Int

    // App modifications
    @State private var customName: String = ""
    @State private var customBundleID: String = ""
    @State private var customVersion: String = ""
    @State private var customIcon: UIImage?

    // Injection files from Tweaks directory
    @State private var selectedTweaks: [URL] = []

    // Sheet states
    @State private var showCertPicker = false
    @State private var showFrameworkRemover = false
    @State private var showTweakPicker = false
    @State private var showIconPicker = false
    @State private var showAltIconPicker = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    // Signing state
    @State private var isSigning = false
    @State private var signingError: String?
    @State private var showError = false

    init(app: AppInfoPresentable) {
        self.app = app
        let defaultOptions = OptionsManager.shared.options
        _selectedCertIndex = State(initialValue: UserDefaults.standard.integer(forKey: "feather.selectedCert"))
        _customName = State(initialValue: app.name ?? "")
        _customBundleID = State(initialValue: app.identifier ?? "")
        _customVersion = State(initialValue: app.version ?? "")

        var opts = defaultOptions
        opts.injectionFiles = []
        opts.disInjectionFiles = []
        opts.removeFiles = []
        _options = State(initialValue: opts)
    }

    private var certificate: CertificatePair? {
        Storage.shared.getCertificate(for: selectedCertIndex)
    }

    var body: some View {
        NavigationView {
            Form {
                _appHeaderSection()
                _propertiesSection()
                _certificateSection()
                _frameworkSection()
                _tweakSection()
                _injectionSettingsSection()
                _otherSettingsSection()
                _signButtonSection()
            }
            .navigationTitle("签名配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showCertPicker) {
                NavigationView {
                    CertificatesView(selection: $selectedCertIndex, embedded: true)
                        .navigationTitle("选择证书")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") { showCertPicker = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showFrameworkRemover) {
                SigningFrameworksView(app: app, options: .constant(options as Options?))
            }
            .sheet(isPresented: $showTweakPicker) {
                TweakPickerView(selectedTweaks: $selectedTweaks)
            }
            .sheet(isPresented: $showAltIconPicker) {
                SigningAlternativeIconView(app: app, appIcon: $customIcon, isModifing: .constant(true))
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { newItem in
                Task {
                    if let newItem,
                       let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        customIcon = image
                    }
                }
            }
            .alert("签名错误", isPresented: $showError) {
                Button("确定") { }
            } message: {
                Text(signingError ?? "未知错误")
            }
            .disabled(isSigning)
            .overlay {
                if isSigning {
                    _signingOverlay()
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func _appHeaderSection() -> some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    if let icon = customIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(18)
                    } else {
                        FRAppIconView(app: app, size: 80)
                            .cornerRadius(18)
                    }

                    Menu {
                        Button("选择照片", systemImage: "photo") {
                            showPhotoPicker = true
                        }
                        Button("应用内置图标", systemImage: "app.gift") {
                            showAltIconPicker = true
                        }
                        if customIcon != nil {
                            Button("重置图标", systemImage: "arrow.counterclockwise", role: .destructive) {
                                customIcon = nil
                            }
                        }
                    } label: {
                        Text("更换图标")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func _propertiesSection() -> some View {
        Section(header: Text("应用属性")) {
            HStack {
                Text("名称")
                Spacer()
                TextField("应用名称", text: $customName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
            }

            HStack {
                Text("包名")
                Spacer()
                TextField("com.example.app", text: $customBundleID)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            HStack {
                Text("版本")
                Spacer()
                TextField("1.0.0", text: $customVersion)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.decimalPad)
            }
        }
    }

    @ViewBuilder
    private func _certificateSection() -> some View {
        Section(header: Text("证书")) {
            Button(action: { showCertPicker = true }) {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.accentColor)

                    if let cert = certificate {
                        let decoded = Storage.shared.getProvisionFileDecoded(for: cert)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cert.nickname ?? decoded?.Name ?? "证书")
                                .foregroundColor(.primary)
                                .font(.system(size: 14, weight: .medium))
                            if let decoded = decoded {
                                Text(decoded.AppIDName)
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                        }
                    } else {
                        Text("选择证书")
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
            }
        }
    }

    @ViewBuilder
    private func _frameworkSection() -> some View {
        Section(header: Text("内部库")) {
            Button(action: { showFrameworkRemover = true }) {
                HStack {
                    Image(systemName: "folder.badge.minus")
                        .foregroundColor(.orange)
                    Text("移除库文件")
                        .foregroundColor(.primary)
                    Spacer()
                    if !options.removeFiles.isEmpty {
                        Text("已选 \(options.removeFiles.count) 个")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
            }
        }
    }

    @ViewBuilder
    private func _tweakSection() -> some View {
        Section(header: Text("插件注入")) {
            Button(action: { showTweakPicker = true }) {
                HStack {
                    Image(systemName: "puzzlepiece.extension")
                        .foregroundColor(.green)
                    Text("添加插件")
                        .foregroundColor(.primary)
                    Spacer()
                    if !selectedTweaks.isEmpty {
                        Text("已选 \(selectedTweaks.count) 个")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
            }

            if !selectedTweaks.isEmpty {
                ForEach(selectedTweaks, id: \.absoluteString) { tweak in
                    HStack {
                        Image(systemName: tweak.pathExtension == "deb" ? "shippingbox" : "puzzlepiece")
                            .foregroundColor(.secondary)
                        Text(tweak.lastPathComponent)
                            .font(.system(size: 13))
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    selectedTweaks.remove(atOffsets: indexSet)
                }
            }
        }
    }

    @ViewBuilder
    private func _injectionSettingsSection() -> some View {
        Section(header: Text("注入设置")) {
            Picker("注入路径", selection: $options.injectPath) {
                Text("@executable_path").tag(Options.InjectPath.executable_path)
                Text("@rpath").tag(Options.InjectPath.rpath)
            }

            Picker("注入目录", selection: $options.injectFolder) {
                Text("/").tag(Options.InjectFolder.root)
                Text("Frameworks/").tag(Options.InjectFolder.frameworks)
            }
        }
    }

    @ViewBuilder
    private func _otherSettingsSection() -> some View {
        Section(header: Text("其他设置")) {
            Toggle("移除最低版本限制", isOn: $options.removeMinVersionLimit)
            Toggle("启用文件访问", isOn: $options.enableFileAccess)
            Toggle("自动修复越狱依赖", isOn: $options.autoFixJailbreakDeps)
        }
    }

    @ViewBuilder
    private func _signButtonSection() -> some View {
        Section {
            Button(action: _startSigning) {
                HStack {
                    Spacer()
                    if isSigning {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "signature")
                        Text("开始签名")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .foregroundColor(.white)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(certificate == nil ? Color.gray : Color.accentColor)
            )
            .disabled(certificate == nil || isSigning)
        }
    }

    @ViewBuilder
    private func _signingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("签名中...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - Signing Logic

    private func _startSigning() {
        guard let cert = certificate else { return }

        isSigning = true

        var signingOptions = options
        signingOptions.appName = customName.isEmpty ? nil : (customName == app.name ? nil : customName)
        signingOptions.appIdentifier = customBundleID.isEmpty ? nil : (customBundleID == app.identifier ? nil : customBundleID)
        signingOptions.appVersion = customVersion.isEmpty ? nil : (customVersion == app.version ? nil : customVersion)
        signingOptions.injectionFiles = selectedTweaks

        if signingOptions.enableFileAccess {
            signingOptions.fileSharing = true
            signingOptions.itunesFileSharing = true
        }
        if signingOptions.removeMinVersionLimit {
            signingOptions.minimumAppRequirement = .v14
        }
        if signingOptions.removeAppJumps {
            signingOptions.removeURLScheme = true
        }

        FR.signPackageFile(
            app,
            using: signingOptions,
            icon: customIcon,
            certificate: cert
        ) { error in
            isSigning = false

            if let error = error {
                signingError = error.localizedDescription
                showError = true
            } else {
                ToastManager.shared.show("签名完成！", style: .success)

                if signingOptions.post_deleteAppAfterSigned || signingOptions.deleteAfterSign {
                    Storage.shared.deleteApp(for: app)
                }

                dismiss()

                if signingOptions.post_installAppAfterSigned || signingOptions.autoInstallAfterSign {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: Notification.Name("Feather.installApp"), object: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Tweak Picker View
struct TweakPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTweaks: [URL]
    @State private var availableTweaks: [URL] = []
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationView {
            List {
                if availableTweaks.isEmpty {
                    Text("暂无可用插件\n请先导入 .deb 或 .dylib 文件")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Section {
                        Button(action: _toggleAll) {
                            HStack {
                                Image(systemName: selected.count == availableTweaks.count ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected.count == availableTweaks.count ? .accentColor : .secondary)
                                Text("全选")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                        }
                    }

                    ForEach(availableTweaks, id: \.absoluteString) { tweak in
                        Button(action: { _toggle(tweak) }) {
                            HStack {
                                Image(systemName: selected.contains(tweak.absoluteString) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected.contains(tweak.absoluteString) ? .accentColor : .secondary)

                                Image(systemName: _tweakIcon(tweak))
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tweak.lastPathComponent)
                                        .foregroundColor(.primary)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(tweak.pathExtension.uppercased())
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 11))
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择插件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        selectedTweaks = availableTweaks.filter { selected.contains($0.absoluteString) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                _loadTweaks()
                selected = Set(selectedTweaks.map(\.absoluteString))
            }
        }
    }

    private func _tweakIcon(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "deb": return "shippingbox"
        case "zip": return "doc.zipper"
        default: return "puzzlepiece"
        }
    }

    private func _toggle(_ url: URL) {
        let key = url.absoluteString
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
    }

    private func _toggleAll() {
        if selected.count == availableTweaks.count {
            selected.removeAll()
        } else {
            selected = Set(availableTweaks.map(\.absoluteString))
        }
    }

    private func _loadTweaks() {
        let fm = FileManager.default
        try? fm.createDirectoryIfNeeded(at: fm.tweaks)
        let files = (try? fm.contentsOfDirectory(at: fm.tweaks, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        availableTweaks = files.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "dylib" || ext == "deb" || ext == "zip"
        }
    }
}
