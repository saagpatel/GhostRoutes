import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            TabView {
                GhostMapView()
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }

                ComparisonView()
                    .tabItem {
                        Label("Compare", systemImage: "rectangle.split.2x1")
                    }

                GhostInboxView()
                    .tabItem {
                        Label("Inbox", systemImage: "bell.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
}
