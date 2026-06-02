//
//  RemoteControllerLocalNetwork.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Combine
import Darwin
import Foundation
import Network

enum RemoteControllerLocalNetwork {
    static let serviceType = "_melonx-ctrl._tcp"
    static let defaultPort: UInt16 = 42069
    static let port = NWEndpoint.Port(rawValue: defaultPort)!

    static var endpointDescription: String {
        guard let address = localIPv4Addresses().first else {
            return "port \(defaultPort)"
        }

        return "\(address):\(defaultPort)"
    }

    static func statusMessage(prefix: String, error: NWError) -> String {
        let errorDescription = String(describing: error)
        if errorDescription.contains("NoAuth") || errorDescription.contains("-65555") {
            return "\(prefix): Local Network permission is denied. Enable MeloNX in Settings > Privacy & Security > Local Network."
        }

        return "\(prefix): \(error.localizedDescription)"
    }

    private static func localIPv4Addresses() -> [String] {
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacePointer) == 0, let firstInterface = interfacePointer else {
            return []
        }

        defer {
            freeifaddrs(interfacePointer)
        }

        var addresses: [String] = []
        var currentInterface: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let interface = currentInterface {
            defer {
                currentInterface = interface.pointee.ifa_next
            }

            let flags = Int32(interface.pointee.ifa_flags)
            guard let address = interface.pointee.ifa_addr,
                  (flags & IFF_UP) == IFF_UP,
                  (flags & IFF_LOOPBACK) == 0,
                  address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                addresses.append(String(cString: hostname))
            }
        }

        return addresses
    }
}

struct RemoteControllerLocalPeer: Identifiable, Hashable {
    let id: String
    let name: String
    let endpoint: NWEndpoint

    static func == (lhs: RemoteControllerLocalPeer, rhs: RemoteControllerLocalPeer) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class RemoteControllerLocalNetworkBrowser: ObservableObject {
    static let shared = RemoteControllerLocalNetworkBrowser()

    @Published private(set) var peers: [RemoteControllerLocalPeer] = []
    @Published private(set) var statusText = "Searching local network"

    private let queue = DispatchQueue(label: "com.stossy11.MeloNX.remote-controller.local-browser")
    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(type: RemoteControllerLocalNetwork.serviceType, domain: nil),
            using: parameters
        )

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let peers = results.compactMap { result -> RemoteControllerLocalPeer? in
                guard case let .service(name, type, domain, _) = result.endpoint else {
                    return nil
                }

                return RemoteControllerLocalPeer(
                    id: "\(name).\(type).\(domain)",
                    name: name.isEmpty ? "MeloNX Host" : name,
                    endpoint: result.endpoint
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self?.peers = peers
                self?.statusText = peers.isEmpty ? "Searching local network" : "\(peers.count) LAN host found"
            }
        }

        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    if self?.peers.isEmpty == true {
                        self?.statusText = "Searching local network"
                    }
                case .failed(let error):
                    self?.statusText = RemoteControllerLocalNetwork.statusMessage(prefix: "Bonjour search failed", error: error)
                case .waiting(let error):
                    self?.statusText = RemoteControllerLocalNetwork.statusMessage(prefix: "Bonjour search waiting", error: error)
                case .cancelled:
                    self?.statusText = "LAN search stopped"
                default:
                    self?.statusText = "LAN search \(state)"
                }
            }
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil

        DispatchQueue.main.async {
            self.peers = []
            self.statusText = "Searching local network"
        }
    }
}
