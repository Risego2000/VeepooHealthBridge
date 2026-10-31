import Foundation

// Integration boundary for the vendor's actual iOS SDK.
// Deliberately no made-up method calls: the API signatures and the A2 firmware
// capabilities must be verified against the checked-out vendor SDK on macOS.
protocol VeepooSDKAdapter {
    func connect(deviceID: UUID) async throws
    func supportedCapabilities() async throws -> Set<String>
    func readHistory(from: Date, to: Date) async throws -> [Measurement]
    func disconnect() async
}

enum VeepooSDKIntegrationError: LocalizedError {
    case notIntegrated
    var errorDescription: String? { "SDK Veepoo aún no integrado ni validado en A2" }
}

struct PlaceholderVeepooAdapter: VeepooSDKAdapter {
    func connect(deviceID: UUID) async throws { throw VeepooSDKIntegrationError.notIntegrated }
    func supportedCapabilities() async throws -> Set<String> { throw VeepooSDKIntegrationError.notIntegrated }
    func readHistory(from: Date, to: Date) async throws -> [Measurement] { throw VeepooSDKIntegrationError.notIntegrated }
    func disconnect() async {}
}
