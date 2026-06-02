//
//  RemoteControllerTransport.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Combine
import Foundation
import Network

#if canImport(WiFiAware)
import WiFiAware
#endif

final class RemoteControllerClient: ObservableObject, RemoteControllerPacketSender {
    static let shared = RemoteControllerClient()

    @Published private(set) var statusText = "Not connected"
    @Published private(set) var isConnected = false

    private var connectionTask: Task<Void, Never>?
    private var sendContinuation: AsyncStream<Data>.Continuation?

    var canSendPackets: Bool {
        isConnected && sendContinuation != nil
    }

    func sendPacket(_ data: Data) {
        sendContinuation?.yield(data)
    }

    func disconnect() {
        sendContinuation?.finish()
        sendContinuation = nil
        connectionTask?.cancel()
        connectionTask = nil
        updateStatus("Not connected", connected: false)
    }

#if canImport(WiFiAware)
    @available(iOS 26.0, *)
    func connect<Endpoint: Connectable>(to endpoint: Endpoint) {
        disconnect()
        updateStatus("Connecting", connected: false)

        let packets = AsyncStream<Data> { continuation in
            self.sendContinuation = continuation
        }

        connectionTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let connection = NetworkConnection(
                    to: endpoint,
                    using: .parameters {
                        TLS()
                    }
                    .wifiAware { parameters in
                        parameters.performanceMode = .realtime
                    }
                    .serviceClass(.interactiveVideo)
                )
                .onStateUpdate { _, state in
                    self.updateStatus(String(describing: state), connected: String(describing: state).contains("ready"))
                }

                self.updateStatus("Connected", connected: true)

                for await packet in packets {
                    try Task.checkCancellation()
                    try await connection.send(packet)
                }
            } catch {
                self.updateStatus("Connection failed: \(error.localizedDescription)", connected: false)
            }

            self.sendContinuation = nil
        }
    }
#endif

    private func updateStatus(_ status: String, connected: Bool) {
        DispatchQueue.main.async {
            self.statusText = status
            self.isConnected = connected
        }
    }
}

final class RemoteControllerHost: ObservableObject {
    static let shared = RemoteControllerHost()

    @Published private(set) var isRunning = false
    @Published private(set) var statusText = "Remote Controller Host stopped"
    @Published private(set) var connectedControllers = 0

    private var listenerTask: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        guard RemoteControllerWiFiAwareAvailability.isSupported else {
            updateStatus("Wi-Fi Aware entitlement is not active for this signed app", running: false)
            return
        }

#if canImport(WiFiAware)
        if #available(iOS 26.0, *) {
            listenerTask = Task { [weak self] in
                await self?.runWiFiAwareListener()
            }
        }
#else
        updateStatus("Wi-Fi Aware SDK support is not available", running: false)
#endif
    }

    func stop() {
        listenerTask?.cancel()
        listenerTask = nil
        updateStatus("Remote Controller Host stopped", running: false)
    }

#if canImport(WiFiAware)
    @available(iOS 26.0, *)
    private func runWiFiAwareListener() async {
        updateStatus("Remote Controller Host running", running: true)

        do {
            let listener = try NetworkListener(
                for: .wifiAware(.connecting(to: .melonxRemoteController, from: .allPairedDevices)),
                using: .parameters {
                    TLS()
                }
                .wifiAware { parameters in
                    parameters.performanceMode = .realtime
                }
                .serviceClass(.interactiveVideo)
            )
            .onStateUpdate { _, state in
                self.updateStatus("Remote Controller Host \(state)", running: true)
            }

            try await listener.run { connection in
                await self.receivePackets(from: connection)
            }
        } catch {
            updateStatus("Remote Controller Host failed: \(error.localizedDescription)", running: false)
        }
    }

    @available(iOS 26.0, *)
    private func receivePackets(from connection: NetworkConnection<TLS>) async {
        let controller = RemoteController(name: "MeloNX Remote Controller")
        ControllerManager.shared.registerRemoteController(controller)
        updateConnectedControllers(delta: 1)

        defer {
            ControllerManager.shared.unregisterRemoteController(controller)
            updateConnectedControllers(delta: -1)
        }

        do {
            while !Task.isCancelled {
                let data = try await connection.receive(exactly: RemoteControllerPacket.byteCount).content
                if let state = RemoteControllerPacket.decode(data) {
                    controller.apply(state)
                }
            }
        } catch {
            updateStatus("Remote Controller disconnected", running: isRunning)
        }
    }
#endif

    private func updateStatus(_ status: String, running: Bool) {
        DispatchQueue.main.async {
            self.statusText = status
            self.isRunning = running
        }
    }

    private func updateConnectedControllers(delta: Int) {
        DispatchQueue.main.async {
            self.connectedControllers = max(0, self.connectedControllers + delta)
        }
    }
}
