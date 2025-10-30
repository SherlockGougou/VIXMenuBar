import Foundation
import Combine
import Security

struct ChartResponse: Codable {
    struct Chart: Codable {
        struct ResultItem: Codable {
            struct Meta: Codable {
                let currency: String?
                let symbol: String?
                let exchangeName: String?
                let instrumentType: String?
                let firstTradeDate: Int?
                let regularMarketTime: Int?
                let gmtoffset: Int?
                let timezone: String?
                let exchangeTimezoneName: String?
                let chartPreviousClose: Double?
                let previousClose: Double?
                let scale: Int?
                let priceHint: Int?
                // other fields omitted
            }
            struct Indicator: Codable {
                struct Quote: Codable {
                    let close: [Double?]?
                }
                let quote: [Quote]?
            }

            let meta: Meta?
            let timestamp: [Int]?
            let indicators: Indicator?
        }
        let result: [ResultItem]?
        let error: String?
    }
    let chart: Chart
}

@MainActor
final class VIXService: ObservableObject {
    @Published var latestValue: Double? {
        didSet {
            print("VIXService: latestValue set -> \(String(describing: latestValue))")
        }
    }
    @Published var lastUpdated: Date? {
        didSet {
            print("VIXService: lastUpdated set -> \(String(describing: lastUpdated))")
        }
    }
    @Published var history: [Double] = []
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1m")!

    func startPolling(interval: TimeInterval = 60) {
        // Don't trigger an immediate fetch here; caller can decide when to run the first fetch.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.fetchOnce() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func printDiagnostics() {
        print("VIXService diagnostics: request URL = \(url.absoluteString)")

        // Print system proxy settings (if any)
        if let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [AnyHashable: Any] {
            print("VIXService diagnostics: system proxy settings: \(proxySettings)")
        } else {
            print("VIXService diagnostics: no system proxy settings available")
        }

        // Check entitlements available to this process (app-sandbox and network.client)
        if let task = SecTaskCreateFromSelf(nil) {
            var cfErr: Unmanaged<CFError>?
            if let sandboxVal = SecTaskCopyValueForEntitlement(task, "com.apple.security.app-sandbox" as CFString, &cfErr) {
                print("VIXService diagnostics: entitlement com.apple.security.app-sandbox = \(sandboxVal)")
            } else if let err = cfErr?.takeRetainedValue() {
                print("VIXService diagnostics: error checking app-sandbox entitlement: \(err)")
            } else {
                print("VIXService diagnostics: app-sandbox entitlement = nil")
            }

            cfErr = nil
            if let netVal = SecTaskCopyValueForEntitlement(task, "com.apple.security.network.client" as CFString, &cfErr) {
                print("VIXService diagnostics: entitlement com.apple.security.network.client = \(netVal)")
            } else if let err = cfErr?.takeRetainedValue() {
                print("VIXService diagnostics: error checking network.client entitlement: \(err)")
            } else {
                print("VIXService diagnostics: network.client entitlement = nil")
            }
        } else {
            print("VIXService diagnostics: SecTaskCreateFromSelf returned nil")
        }
    }

    func fetchOnce() async {
        // Print diagnostics to help debug permission/proxy issues
        printDiagnostics()

        do {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if let http = resp as? HTTPURLResponse {
                    print("VIXService: bad response status = \(http.statusCode)")
                } else {
                    print("VIXService: bad response (non-HTTP)")
                }
                return
            }
            let decoder = JSONDecoder()
            let chart = try decoder.decode(ChartResponse.self, from: data)
            guard let result = chart.chart.result?.first,
                  let quote = result.indicators?.quote?.first,
                  let closes = quote.close else {
                print("VIXService: parse failure")
                return
            }

            // last non-nil close
            if let last = closes.compactMap({ $0 }).last {
                latestValue = last
                lastUpdated = Date()
                // append to history (keep last 120)
                history.append(last)
                if history.count > 120 { history.removeFirst(history.count - 120) }
            }
        } catch {
            let ns = error as NSError
            print("VIXService error: domain=\(ns.domain) code=\(ns.code) userInfo=\(ns.userInfo)")

            // If there's an underlying error in userInfo, print it too
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("VIXService underlying error: domain=\(underlying.domain) code=\(underlying.code) userInfo=\(underlying.userInfo)")
            }
        }
    }
}
