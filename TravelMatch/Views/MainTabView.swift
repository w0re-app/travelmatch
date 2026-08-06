import SwiftUI

struct MainTabView: View {
    enum Tab: CaseIterable, Hashable {
        case home, discover, matches, profile

        var title: String {
            switch self {
            case .home:     return "Ana Sayfa"
            case .discover: return "Keşfet"
            case .matches:  return "Eşleşmeler"
            case .profile:  return "Profil"
            }
        }
        var icon: String {
            switch self {
            case .home:     return "house.fill"
            case .discover: return "person.2.fill"
            case .matches:  return "bubble.left.and.bubble.right.fill"
            case .profile:  return "person.crop.circle.fill"
            }
        }
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(onSeyahateGit: { selectedTab = .discover })
                case .discover:
                    DiscoveryView(onSeyahatEkle: { selectedTab = .home })
                case .matches:
                    MatchesListView()
                case .profile:
                    ProfileView()
                }
            }

            floatingTabBar
        }
    }

    private var floatingTabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .glassCard(cornerRadius: 28)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.primaryGradient)
                        .neonGlow(Theme.magenta, radius: 10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView().environmentObject(AppState()).preferredColorScheme(.dark)
}
