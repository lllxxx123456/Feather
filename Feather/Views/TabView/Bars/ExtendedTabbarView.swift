import SwiftUI

struct ExtendedTabbarView: View {
    @State private var _selection: TabEnum = .home

    var body: some View {
        if #available(iOS 18, *) {
            TabView(selection: $_selection) {
                ForEach(TabEnum.defaultTabs, id: \.self) { tab in
                    Tab(tab.title, systemImage: tab.icon, value: tab) {
                        TabEnum.view(for: tab)
                    }
                }
            }
        } else {
            TabbarView()
        }
    }
}
