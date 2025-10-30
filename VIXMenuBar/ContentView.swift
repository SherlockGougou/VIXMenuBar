import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var service: VIXService
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("VIX")
                        .font(.headline)
                    if let v = service.latestValue {
                        Text(String(format: "%.2f", v))
                            .font(.largeTitle)
                            .bold()
                    } else {
                        Text("--")
                            .font(.largeTitle)
                            .bold()
                    }
                }
                Spacer()
            }

            HStack {
                if let d = service.lastUpdated {
                    Text("Updated: \(formatDate(d))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    Task { await service.fetchOnce() }
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Toggle(isOn: $launchAtLogin) {
                Text("Launch at Login")
            }
            .onChange(of: launchAtLogin) { oldValue, newValue in
                Task {
                    await setLaunchAtLogin(enabled: newValue)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f.string(from: d)
    }

    func setLaunchAtLogin(enabled: Bool) async {
        do {
            if enabled {
                try LaunchAtLogin.enable()
            } else {
                try LaunchAtLogin.disable()
            }
        } catch {
            // On error, revert the toggle and show an alert
            DispatchQueue.main.async {
                launchAtLogin = !enabled
                errorMessage = String(describing: error)
                showErrorAlert = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VIXService())
}
