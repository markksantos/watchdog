import Foundation

struct WebhookManager {
    static func sendWebhook(for record: CaptureRecord) {
        guard SettingsManager.shared.webhookEnabled,
              !SettingsManager.shared.webhookURL.isEmpty else { return }

        guard SubscriptionManager.shared.hasAccess(to: .webhookAlerts) else { return }
        guard let url = URL(string: SettingsManager.shared.webhookURL) else { return }

        let payload = buildPayload(for: record)
        DispatchQueue.global(qos: .utility).async {
            sendPayload(payload, to: url)
        }
    }

    static func testWebhook(url: String, completion: @escaping (Bool) -> Void) {
        guard let webhookURL = URL(string: url) else {
            completion(false)
            return
        }

        let payload: [String: Any] = [
            "event": "test",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "message": "Watchdog webhook test"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(false)
            return
        }

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, response, error in
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode ?? 0 < 400
            DispatchQueue.main.async { completion(success) }
        }.resume()
    }

    private static func buildPayload(for record: CaptureRecord) -> [String: Any] {
        var payload: [String: Any] = [
            "event": "detection",
            "timestamp": ISO8601DateFormatter().string(from: record.timestamp),
            "detectionType": record.detectionType.rawValue,
            "confidence": record.confidence,
            "imagePath": record.imagePath
        ]
        if let videoPath = record.videoPath {
            payload["videoPath"] = videoPath
        }
        return payload
    }

    private static func sendPayload(_ payload: [String: Any], to url: URL) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error {
                print("[Watchdog] Webhook failed: \(error)")
            }
        }.resume()
    }
}
