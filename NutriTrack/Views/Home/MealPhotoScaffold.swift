import SwiftUI

struct MealPhotoScaffold<Content: View>: View {
    @Environment(\.theme) private var theme
    let image: UIImage?
    let content: Content

    private static var overlap: CGFloat { 28 }

    init(image: UIImage?, @ViewBuilder content: () -> Content) {
        self.image = image
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width,
                                   height: (proxy.size.height + proxy.safeAreaInsets.top) * 0.4)
                            .clipped()
                            .accessibilityHidden(true)
                    }
                    VStack(spacing: 14) {
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 110)
                    .frame(maxWidth: .infinity)
                    .background(theme.colors.background,
                                in: UnevenRoundedRectangle(topLeadingRadius: Self.overlap,
                                                           topTrailingRadius: Self.overlap,
                                                           style: .continuous))
                    .padding(.top, image == nil ? 0 : -Self.overlap)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: image == nil ? [] : .top)
        }
        .background(theme.colors.background.ignoresSafeArea())
    }
}
