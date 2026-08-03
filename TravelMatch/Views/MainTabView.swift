import SwiftUI

struct MainTabView: View {
    enum Tab: CaseIterable, Hashable {
        case discover, matches, profile

        var title: String {
            switch self {
            case .discover: return "Keşfet"
            case .matches: return "Eşleşmeler"
            case .profile: return "Profil"
            }
        }
        var icon: String {
            switch self {
            case .discover: return "person.2.fill"
            case .matches: return "bubble.left.and.bubble.right.fill"
            case .profile: return "person.crop.circle.fill"
            }
        }
    }

    @State private var selectedTab: Tab = .discover

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .discover: DiscoveryView()
                case .matches: MatchesListView()
                case .profile: ProfileView()
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
        .padding(.horizontal, 24)
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
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(.caption2.weight(.semibold))
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
    let state = AppState()
    state.currentTrip = MockData.sampleFlightTrip
    state.fellowTravelers = MockData.fellowTravelers(for: MockData.sampleFlightTrip)
    return MainTabView().environmentObject(state).preferredColorScheme(.dark)
}
