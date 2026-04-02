//
//  CertificatesInfoEntitlementView.swift
//  Feather778
//

import SwiftUI
import NimbleViews

struct CertificatesInfoEntitlementView: View {
    let entitlements: [String: AnyCodable]

    private let _translations: [String: String] = [
        "application-identifier": "Application ID",
        "com.apple.developer.team-identifier": "Team ID",
        "get-task-allow": "Debug Mode",
        "keychain-access-groups": "Keychain Groups",
        "com.apple.security.application-groups": "App Groups",
        "com.apple.developer.associated-domains": "Associated Domains",
        "aps-environment": "Push Notification",
        "com.apple.developer.icloud-container-identifiers": "iCloud Containers",
        "com.apple.developer.ubiquity-kvstore-identifier": "KV Store ID",
        "com.apple.developer.networking.vpn.api": "VPN Permission",
        "com.apple.developer.healthkit": "HealthKit",
        "com.apple.developer.homekit": "HomeKit",
        "com.apple.developer.siri": "Siri Permission",
        "com.apple.developer.nfc.readersession.formats": "NFC Permission",
        "com.apple.developer.applesignin": "Apple Sign In",
        "com.apple.developer.in-app-payments": "In-App Payments",
        "beta-reports-active": "Beta Reports",
        "com.apple.developer.game-center": "Game Center",
        "com.apple.external-accessory.wireless-configuration": "Wireless Config",
        "inter-app-audio": "Inter-App Audio",
        "com.apple.developer.networking.multipath": "Multipath Network",
        "com.apple.developer.networking.wifi-info": "WiFi Info"
    ]

    var body: some View {
        List {
            ForEach(entitlements.keys.sorted(), id: \.self) { key in
                if let value = entitlements[key]?.value {
                    Section(header: Text(_translateKey(key))) {
                        CertificatesInfoEntitlementCellView(key: key, value: value)
                    }
                }
            }
        }
        .navigationTitle("Permissions")
        .listStyle(.insetGrouped)
    }

    private func _translateKey(_ key: String) -> String {
        _translations[key] ?? key
    }
}
