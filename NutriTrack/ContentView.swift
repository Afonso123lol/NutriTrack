import SwiftUI
import CoreData

struct ContentView: View {
    @FetchRequest(entity: UserProfile.entity(), sortDescriptors: [])
    private var profiles: FetchedResults<UserProfile>

    var body: some View {
        if profiles.isEmpty {
            OnboardingContainerView()
        } else {
            MainTabView(profile: profiles[0])
        }
    }
}
