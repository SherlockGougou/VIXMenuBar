import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var service: VIXService
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var isChangingLoginItem = false
    @State private var suppressNextToggleChange = false

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
                // Debounce rapid toggles and avoid re-entrancy
                if suppressNextToggleChange {
                    suppressNextToggleChange = false
                    return
                }
                guard !isChangingLoginItem else { return }
                isChangingLoginItem = true
                Task { @MainActor in
                    await setLaunchAtLogin(enabled: newValue)
                    // After attempting change, reflect real status from system to keep UI consistent
                    suppressNextToggleChange = true
                    self.launchAtLogin = LaunchAtLogin.isEnabled()
                    isChangingLoginItem = false
                }
            }
            .onAppear {
                // sync toggle with actual system setting at app start
                let current = LaunchAtLogin.isEnabled()
                if launchAtLogin != current {
                    suppressNextToggleChange = true
                    launchAtLogin = current
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
            // Sync with actual status (may require user approval)
            DispatchQueue.main.async {
                launchAtLogin = LaunchAtLogin.isEnabled()
            }
        } catch {
            let friendly: String
            let msg = String(describing: error)
            if msg.contains("Operation not permitted") {
                friendly = "系统不允许更改登录项。请在 系统设置 → 通用 → 登录项 中手动允许或移除本应用。"
            } else if msg.contains("unsupported") {
                friendly = "当前系统版本不支持此功能（需要 macOS 13+）。"
            } else {
                friendly = msg
            }
            DispatchQueue.main.async {
                // Re-sync from system instead of naive revert to avoid mismatch
                launchAtLogin = LaunchAtLogin.isEnabled()
                errorMessage = friendly
                showErrorAlert = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VIXService())
}
