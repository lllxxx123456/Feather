import Foundation
import UIKit

// MARK: - OptionsManager
class OptionsManager: ObservableObject {
    static let shared = OptionsManager()

    @Published var options: Options
    private let _key = "signing_options"

    init() {
        if
            let data = UserDefaults.standard.data(forKey: _key),
            let savedOptions = try? JSONDecoder().decode(Options.self, from: data)
        {
            self.options = savedOptions
        } else {
            self.options = Options.defaultOptions
            self.saveOptions()
        }
    }

    func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: _key)
            objectWillChange.send()
        }
    }

    func resetToDefaults() {
        options = Options.defaultOptions
        saveOptions()
    }
}

// MARK: - Options
struct Options: Codable, Equatable {

    // MARK: Pre Modifications
    var appName: String?
    var appVersion: String?
    var appIdentifier: String?
    var appEntitlementsFile: URL?
    var appAppearance: AppAppearance
    var minimumAppRequirement: MinimumAppRequirement
    var signingOption: SigningOption

    // MARK: Injection Options
    var injectPath: InjectPath
    var injectFolder: InjectFolder
    var ppqString: String
    var ppqProtection: Bool
    var dynamicProtection: Bool
    var identifiers: [String: String]
    var displayNames: [String: String]
    var injectionFiles: [URL]
    var disInjectionFiles: [String]
    var removeFiles: [String]

    // MARK: App Features
    var fileSharing: Bool
    var itunesFileSharing: Bool
    var proMotion: Bool
    var gameMode: Bool
    var ipadFullscreen: Bool
    var removeURLScheme: Bool
    var removeProvisioning: Bool
    var changeLanguageFilesForCustomDisplayName: Bool
    var injectIntoExtensions: Bool

    // MARK: Experiments
    var experiment_supportLiquidGlass: Bool
    var experiment_replaceSubstrateWithEllekit: Bool

    // MARK: Default Signing Config (Settings page)
    var autoFixJailbreakDeps: Bool
    var enableFileAccess: Bool
    var removeMinVersionLimit: Bool
    var removeAppJumps: Bool
    var packageNameRule: Int // bitmask: 1=name, 2=version, 4=time
    var autoInstallAfterSign: Bool
    var useLocalServer: Bool
    var deleteAfterSign: Bool

    // MARK: Post Modifications
    var post_installAppAfterSigned: Bool
    var post_deleteAppAfterSigned: Bool

    // MARK: - Defaults
    static let defaultOptions = Options(
        appAppearance: .default,
        minimumAppRequirement: .default,
        signingOption: .default,

        injectPath: .executable_path,
        injectFolder: .root,
        ppqString: randomString(),
        ppqProtection: false,
        dynamicProtection: false,
        identifiers: [:],
        displayNames: [:],
        injectionFiles: [],
        disInjectionFiles: [],
        removeFiles: [],
        fileSharing: false,
        itunesFileSharing: false,
        proMotion: false,
        gameMode: false,
        ipadFullscreen: false,
        removeURLScheme: false,
        removeProvisioning: false,
        changeLanguageFilesForCustomDisplayName: false,
        injectIntoExtensions: false,

        experiment_supportLiquidGlass: false,
        experiment_replaceSubstrateWithEllekit: false,

        autoFixJailbreakDeps: true,
        enableFileAccess: false,
        removeMinVersionLimit: false,
        removeAppJumps: false,
        packageNameRule: 7,
        autoInstallAfterSign: false,
        useLocalServer: true,
        deleteAfterSign: false,

        post_installAppAfterSigned: false,
        post_deleteAppAfterSigned: false
    )

    enum AppAppearance: String, Codable, CaseIterable, LocalizedDescribable {
        case `default`
        case light = "Light"
        case dark = "Dark"

        var localizedDescription: String {
            switch self {
            case .default: "Default"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
    }

    enum MinimumAppRequirement: String, Codable, CaseIterable, LocalizedDescribable {
        case `default`
        case v16 = "16.0"
        case v15 = "15.0"
        case v14 = "14.0"
        case v13 = "13.0"
        case v12 = "12.0"

        var localizedDescription: String {
            switch self {
            case .default: "Default"
            case .v16: "16.0"
            case .v15: "15.0"
            case .v14: "14.0"
            case .v13: "13.0"
            case .v12: "12.0"
            }
        }
    }

    enum SigningOption: String, Codable, CaseIterable, LocalizedDescribable {
        case `default`
        case onlyModify

        var localizedDescription: String {
            switch self {
            case .default: "Default"
            case .onlyModify: "Modify"
            }
        }
    }

    enum InjectPath: String, Codable, CaseIterable, LocalizedDescribable {
        case executable_path = "@executable_path"
        case rpath = "@rpath"
    }

    enum InjectFolder: String, Codable, CaseIterable, LocalizedDescribable {
        case root = "/"
        case frameworks = "/Frameworks/"
    }

    static func randomString() -> String {
        String((0..<6).compactMap { _ in UUID().uuidString.randomElement() })
    }
}

// MARK: - LocalizedDescribable
protocol LocalizedDescribable {
    var localizedDescription: String { get }
}

extension LocalizedDescribable where Self: RawRepresentable, RawValue == String {
    var localizedDescription: String {
        let localized = NSLocalizedString(self.rawValue, comment: "")
        return localized == self.rawValue ? self.rawValue : localized
    }
}
