import SwiftUI

struct SettingsHeaderView: View {
    @Binding var isSidebarVisible: NavigationSplitViewVisibility
    var activeDevice: String

    var body: some View {
        HStack {
            Button {
                withAnimation {
                    if isSidebarVisible == .all {
                        isSidebarVisible = .detailOnly
                    } else {
                        isSidebarVisible = .all
                    }
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(activeDevice)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
