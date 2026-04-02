import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case home
    case certificates
    case settings

    var title: String {
        switch self {
        case .home: return "Home"
        case .certificates: return "Certificates"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .certificates: return "person.text.rectangle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    @ViewBuilder
    static func view(for tab: TabEnum) -> some View {
        switch tab {
        case .home: HomeView()
        case .certificates: CertificatesView()
        case .settings: SettingsView()
        }
    }

    static var defaultTabs: [TabEnum] {
        return [.home, .certificates, .settings]
    }

    static var customizableTabs: [TabEnum] {
        return []
    }
}
