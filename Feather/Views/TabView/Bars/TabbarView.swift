import SwiftUI

struct TabbarView: View {
    @State private var _selection: TabEnum = .home

    var body: some View {
        TabView(selection: $_selection) {
            ForEach(TabEnum.defaultTabs, id: \.self) { tab in
                TabEnum.view(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
    }
}
