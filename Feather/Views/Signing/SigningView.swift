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
        _options = State(initialValue: defaultOptions)
        _selectedCertIndex = State(initialValue: UserDefaults.standard.integer(forKey: "feather.selectedCert"))
        _customName = State(initialValue: app.name ?? "")
        _customBundleID = State(initialValue: app.identifier ?? "")
        _customVersion = State(initialValue: app.version ?? "")

        // Apply default signing config values
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
                // MARK: App Icon & Basic Info
                _appHeaderSection()

                // MARK: Basic Properties
                _propertiesSection()

                // MARK: Certificate
                _certificateSection()

                // MARK: Framework Management
                _frameworkSection()

                // MARK: Tweak Injection
                _tweakSection()

                // MARK: Injection Settings
                _injectionSettingsSection()

                // MARK: Other Settings
                _otherSettingsSection()

                // MARK: Sign Button
                _signButtonSection()
            }
            .navigationTitle("Sign Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCertPicker) {
                NavigationView {
                    CertificatesView(selection: $selectedCertIndex)
                        .navigationTitle("Select Certificate")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showCertPicker = false }
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
            .alert("Signing Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(signingError ?? "Unknown error")
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
                        Button("Choose Photo", systemImage: "photo") {
                            showPhotoPicker = true
                        }
                        Button("App Built-in Icons", systemImage: "app.gift") {
                            showAltIconPicker = true
                        }
                        if customIcon != nil {
                            Button("Reset Icon", systemImage: "arrow.counterclockwise", role: .destructive) {
                                customIcon = nil
                            }
                        }
                    } label: {
                        Text("Change Icon")
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
        Section(header: Text("App Properties")) {
            HStack {
                Text("Name")
                Spacer()
                TextField("App Name", text: $customName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
            }

            HStack {
                Text("Bundle ID")
                Spacer()
                TextField("com.example.app", text: $customBundleID)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            HStack {
                Text("Version")
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
        Section(header: Text("Certificate")) {
            Button(action: { showCertPicker = true }) {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.accentColor)

                    if let cert = certificate {
                        let decoded = Storage.shared.getProvisionFileDecoded(for: cert)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cert.nickname ?? decoded?.Name ?? "Certificate")
                                .foregroundColor(.primary)
                                .font(.system(size: 14, weight: .medium))
                            if let decoded = decoded {
                                Text(decoded.AppIDName)
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                        }
                    } else {
                        Text("Select Certificate")
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
        Section(header: Text("Internal Libraries")) {
            Button(action: { showFrameworkRemover = true }) {
                HStack {
                    Image(systemName: "folder.badge.minus")
                        .foregroundColor(.orange)
                    Text("Remove Libraries")
                        .foregroundColor(.primary)
                    Spacer()
                    if !options.removeFiles.isEmpty {
                        Text("\(options.removeFiles.count) selected")
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
        Section(header: Text("Plugin Injection")) {
            Button(action: { showTweakPicker = true }) {
                HStack {
                    Image(systemName: "puzzlepiece.extension")
                        .foregroundColor(.green)
                    Text("Add Plugins")
                        .foregroundColor(.primary)
                    Spacer()
                    if !selectedTweaks.isEmpty {
                        Text("\(selectedTweaks.count) selected")
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
        Section(header: Text("Injection Settings")) {
            Picker("Inject Path", selection: $options.injectPath) {
                Text("@executable_path").tag(Options.InjectPath.executable_path)
                Text("@rpath").tag(Options.InjectPath.rpath)
            }

            Picker("Inject Directory", selection: $options.injectFolder) {
                Text("/").tag(Options.InjectFolder.root)
                Text("Frameworks/").tag(Options.InjectFolder.frameworks)
            }
        }
    }

    @ViewBuilder
    private func _otherSettingsSection() -> some View {
        Section(header: Text("Other Settings")) {
            Toggle("Remove Min Version Limit", isOn: $options.removeMinVersionLimit)
            Toggle("Enable File Access", isOn: $options.enableFileAccess)
            Toggle("Auto-fix Jailbreak Deps", isOn: $options.autoFixJailbreakDeps)
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
                        Text("Start Signing")
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
                Text("Signing...")
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

        // Apply user modifications to options
        var signingOptions = options
        signingOptions.appName = customName.isEmpty ? nil : (customName == app.name ? nil : customName)
        signingOptions.appIdentifier = customBundleID.isEmpty ? nil : (customBundleID == app.identifier ? nil : customBundleID)
        signingOptions.appVersion = customVersion.isEmpty ? nil : (customVersion == app.version ? nil : customVersion)
        signingOptions.injectionFiles = selectedTweaks

        // Apply default config toggles
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
                ToastManager.shared.show("Signing completed!", style: .success)

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
                    Text("No plugins available.\nImport .deb or .dylib files first.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(availableTweaks, id: \.absoluteString) { tweak in
                        Button(action: { _toggle(tweak) }) {
                            HStack {
                                Image(systemName: selected.contains(tweak.absoluteString) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected.contains(tweak.absoluteString) ? .accentColor : .secondary)

                                Image(systemName: tweak.pathExtension == "deb" ? "shippingbox" : "puzzlepiece")
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
            .navigationTitle("Select Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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

    private func _toggle(_ url: URL) {
        let key = url.absoluteString
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
    }

    private func _loadTweaks() {
        let fm = FileManager.default
        try? fm.createDirectoryIfNeeded(at: fm.tweaks)
        let files = (try? fm.contentsOfDirectory(at: fm.tweaks, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        availableTweaks = files.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "dylib" || ext == "deb"
        }
    }
}
