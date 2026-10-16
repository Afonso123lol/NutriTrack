import SwiftUI

struct CaptureButtonHiddenKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func hidesCaptureButton() -> some View {
        preference(key: CaptureButtonHiddenKey.self, value: true)
    }
}
