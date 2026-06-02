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

    private let localNetworkQueue = DispatchQueue(label: "com.stossy11.MeloNX.remote-controller.local-client")
    private var connectionTask: Task<Void, Never>?
    private var sendContinuation: AsyncStream<Data>.Continuation?
    private var localConnection: NWConnection?

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
        localConnection?.cancel()
        localConnection = nil
        updateStatus("Not connected", connected: false)
    }

    func connectToLocalNetworkPeer(_ peer: RemoteControllerLocalPeer) {
        connectToLocalNetworkEndpoint(peer.endpoint, label: peer.name)
    }

    func connectToLocalNetworkHost(_ host: String, port: UInt16 = RemoteControllerLocalNetwork.defaultPort) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            updateStatus("Invalid port", connected: false)
            return
        }

        connectToLocalNetworkEndpoint(
            .hostPort(host: NWEndpoint.Host(host), port: nwPort),
            label: "\(host):\(port)"
        )
    }

    private func connectToLocalNetworkEndpoint(_ endpoint: NWEndpoint, label: String) {
        disconnect()
        updateStatus("Connecting to \(label)", connected: false)

        let packets = AsyncStream<Data> { continuation in
            self.sendContinuation = continuation
        }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let connection = NWConnection(to: endpoint, using: parameters)
        localConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.updateStatus("Connected to \(label)", connected: true)
            case .waiting(let error):
                self?.updateStatus(
                    RemoteControllerLocalNetwork.statusMessage(prefix: "LAN waiting", error: error),
                    connected: false
                )
            case .failed(let error):
                self?.updateStatus(
                    RemoteControllerLocalNetwork.statusMessage(prefix: "LAN connection failed", error: error),
                    connected: false
                )
                self?.sendContinuation?.finish()
            case .cancelled:
                self?.updateStatus("Not connected", connected: false)
            default:
                self?.updateStatus("LAN \(state)", connected: false)
            }
        }
        connection.start(queue: localNetworkQueue)

        connectionTask = Task { [weak self, connection] in
            do {
                for await packet in packets {
                    try Task.checkCancellation()
                    try await connection.sendPacket(packet)
                }
            } catch {
                self?.updateStatus("LAN send failed: \(error.localizedDescription)", connected: false)
            }

            connection.cancel()
            self?.sendContinuation = nil
        }
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

    private let localNetworkQueue = DispatchQueue(label: "com.stossy11.MeloNX.remote-controller.local-host")
    private var listenerTask: Task<Void, Never>?
    private var localListener: NWListener?
    private var localSessions: [ObjectIdentifier: RemoteControllerLocalNetworkSession] = [:]

    func start() {
        guard !isRunning else { return }

#if canImport(WiFiAware)
        if #available(iOS 26.0, *), RemoteControllerWiFiAwareAvailability.isSupported {
            listenerTask = Task { [weak self] in
                await self?.runWiFiAwareListener()
            }
            return
        }
#endif

        startLocalNetworkListener()
    }

    func stop() {
        listenerTask?.cancel()
        listenerTask = nil
        localListener?.cancel()
        localListener = nil
        localSessions.values.forEach { $0.cancel() }
        localSessions.removeAll()
        updateStatus("Remote Controller Host stopped", running: false)
        DispatchQueue.main.async {
            self.connectedControllers = 0
        }
    }

    private func startLocalNetworkListener() {
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters, on: RemoteControllerLocalNetwork.port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.acceptLocalNetworkConnection(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.updateStatus("LAN Host running at \(RemoteControllerLocalNetwork.endpointDescription)", running: true)
                case .waiting(let error):
                    self?.updateStatus(
                        RemoteControllerLocalNetwork.statusMessage(prefix: "LAN Host waiting", error: error),
                        running: true
                    )
                case .failed(let error):
                    self?.updateStatus(
                        RemoteControllerLocalNetwork.statusMessage(prefix: "LAN Host failed", error: error),
                        running: false
                    )
                case .cancelled:
                    self?.updateStatus("Remote Controller Host stopped", running: false)
                default:
                    self?.updateStatus("LAN Host \(state)", running: true)
                }
            }

            localListener = listener
            updateStatus("LAN Host starting", running: true)
            listener.start(queue: localNetworkQueue)
        } catch {
            updateStatus("LAN Host failed: \(error.localizedDescription)", running: false)
        }
    }

    private func acceptLocalNetworkConnection(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        let session = RemoteControllerLocalNetworkSession(
            connection: connection,
            queue: localNetworkQueue,
            onConnect: { [weak self] in
                self?.updateConnectedControllers(delta: 1)
                self?.updateStatus("LAN controller connected", running: true)
            },
            onDisconnect: { [weak self] in
                self?.localSessions[id] = nil
                self?.updateConnectedControllers(delta: -1)
                if self?.localListener != nil {
                    self?.updateStatus("LAN Host running at \(RemoteControllerLocalNetwork.endpointDescription)", running: true)
                }
            }
        )

        localSessions[id] = session
        session.start()
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

private final class RemoteControllerLocalNetworkSession {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let controller = RemoteController(name: "MeloNX LAN Remote Controller")
    private let onConnect: () -> Void
    private let onDisconnect: () -> Void
    private var isRegistered = false
    private var isFinished = false

    init(
        connection: NWConnection,
        queue: DispatchQueue,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) {
        self.connection = connection
        self.queue = queue
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                self.registerControllerIfNeeded()
                self.receiveNextPacket()
            case .failed, .cancelled:
                self.finish()
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    func cancel() {
        connection.cancel()
        finish()
    }

    private func registerControllerIfNeeded() {
        guard !isRegistered else { return }

        isRegistered = true
        ControllerManager.shared.registerRemoteController(controller)
        onConnect()
    }

    private func receiveNextPacket() {
        connection.receive(
            minimumIncompleteLength: RemoteControllerPacket.byteCount,
            maximumLength: RemoteControllerPacket.byteCount
        ) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, let state = RemoteControllerPacket.decode(data) {
                self.controller.apply(state)
            }

            if error != nil || isComplete {
                self.finish()
                return
            }

            self.receiveNextPacket()
        }
    }

    private func finish() {
        guard !isFinished else { return }

        isFinished = true
        if isRegistered {
            ControllerManager.shared.unregisterRemoteController(controller)
        }
        onDisconnect()
    }
}

private extension NWConnection {
    func sendPacket(_ packet: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            send(content: packet, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
