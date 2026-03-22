import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @State private var currentStep = 0
    @State private var showDocumentPicker = false
    @State private var importPipeline = ImportPipeline()
    @State private var permissionManager = PermissionManager()
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            Spacer()

            Group {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    locationPermissionStep
                case 2:
                    importStep
                case 3:
                    importProgressStep
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                guard let db = appDatabase else { return }
                currentStep = 3
                Task {
                    // Copy file data before security scope ends
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    await importPipeline.importFile(url: url, database: db)
                }
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "map.fill")
                .font(.system(size: 72))
                .foregroundStyle(.primary)

            Text("Ghost Routes")
                .font(.largeTitle)
                .fontWeight(.black)

            Text("Discover the places you've stopped visiting. Import your location history to see your ghost map.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Get Started") {
                currentStep = 1
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var locationPermissionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Location Access")
                .font(.title)
                .fontWeight(.bold)

            Text("Ghost Routes needs location access to track your visits over time and detect when places become ghosts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Allow Location Access") {
                Task {
                    await permissionManager.requestLocationAlways()
                    await permissionManager.requestNotifications()
                    currentStep = 2
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for Now") {
                currentStep = 2
            }
            .foregroundStyle(.secondary)
        }
    }

    private var importStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 72))
                .foregroundStyle(.orange)

            Text("Import Location History")
                .font(.title)
                .fontWeight(.bold)

            Text("Import your Google Takeout location history to see your ghost map right away. You can also do this later from Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Choose Takeout JSON File") {
                showDocumentPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip — I'll import later") {
                hasCompleted = true
            }
            .foregroundStyle(.secondary)
        }
    }

    private var importProgressStep: some View {
        ImportProgressView(pipeline: importPipeline) {
            hasCompleted = true
        }
    }
}
