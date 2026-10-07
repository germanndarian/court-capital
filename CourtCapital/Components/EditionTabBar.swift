import SwiftUI

/// Text-only tabs in letter-spaced caps; the active tab carries a brass lozenge and full ink.
struct EditionTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isActive = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 6) {
                        Lozenge()
                            .opacity(isActive ? 1 : 0)
                        Text(tab.title)
                            .typeStyle(.label(10))
                            .foregroundStyle(isActive ? Theme.ink : Theme.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 80)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
                .accessibilityShowsLargeContentViewer {
                    Text(tab.title)
                }
            }
        }
        // Like the system tab bar, the labels stop growing early; long-press shows them large.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .padding(.horizontal, 26)
        .padding(.top, 4)
        .frame(minHeight: 50, alignment: .top)
        .background(PaperBackground().ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Hairline(color: Theme.ruleStrong) }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
