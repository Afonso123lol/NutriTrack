import SwiftUI

struct StatusBarScrim: ViewModifier {
    let scrollOffset: CGFloat

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .frame(height: 0)
                .opacity(min(1, max(0, (scrollOffset - 4) / 24)))
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func statusBarScrim(scrollOffset: CGFloat) -> some View {
        modifier(StatusBarScrim(scrollOffset: scrollOffset))
    }
}
