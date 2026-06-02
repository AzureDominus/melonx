//
//  RemoteControllerViews.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import SwiftUI

#if canImport(DeviceDiscoveryUI) && canImport(WiFiAware)
import DeviceDiscoveryUI
import WiFiAware
#endif

struct RemoteControllerModeView: View {
    @AppStorage("MeloNXAppMode") private var appModeRaw = MeloNXAppMode.controller.rawValue
    @StateObject private var client: RemoteControllerClient
    @State private var isPortrait = false
    private let inputSink: RemoteControllerClientInputSink

    init() {
        let client = RemoteControllerClient.shared
        self._client = StateObject(wrappedValue: client)
        self.inputSink = RemoteControllerClientInputSink(sender: client)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ControllerView(
                isEditing: .constant(false),
                gameId: "remote-controller",
                isPortrait: $isPortrait,
                inputSink: inputSink
            )
            .opacity(client.isConnected ? 1 : 0.35)
            .allowsHitTesting(client.isConnected)

            VStack {
                RemoteControllerClientToolbar(
                    statusText: client.statusText,
                    isConnected: client.isConnected,
                    switchToEmulator: {
                        inputSink.stopStreaming()
                        inputSink.stopMotionUpdates()
                        client.disconnect()
                        appModeRaw = ""
                    }
                )
                .padding()

                Spacer()
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            inputSink.startStreaming(framesPerSecond: 60)
            inputSink.startMotionUpdates(framesPerSecond: 60)
        }
        .onDisappear {
            inputSink.stopStreaming()
            inputSink.stopMotionUpdates()
        }
    }
}

private struct RemoteControllerClientToolbar: View {
    let statusText: String
    let isConnected: Bool
    let switchToEmulator: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(statusText, systemImage: isConnected ? "wifi" : "wifi.slash")
                .font(.footnote)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            Spacer()

            RemoteControllerDevicePicker()

            Menu {
                Button {
                    RemoteControllerClient.shared.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }

                Button {
                    switchToEmulator()
                } label: {
                    Label("Choose Mode", systemImage: "rectangle.2.swap")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }
}

private struct RemoteControllerDevicePicker: View {
    var body: some View {
        HStack(spacing: 8) {
            if RemoteControllerWiFiAwareAvailability.isSupported, #available(iOS 26.0, *) {
                WiFiAwareRemoteControllerDevicePicker()
            }

            LocalNetworkRemoteControllerDevicePicker()
        }
    }
}

private struct LocalNetworkRemoteControllerDevicePicker: View {
    @StateObject private var browser = RemoteControllerLocalNetworkBrowser.shared
    @State private var isManualConnectPresented = false
    @State private var hasStartedBonjourSearch = false

    var body: some View {
        Menu {
            Button {
                isManualConnectPresented = true
            } label: {
                Label("Manual Host", systemImage: "number")
            }

            Divider()

            Button {
                browser.stop()
                browser.start()
                hasStartedBonjourSearch = true
            } label: {
                Label("Search Bonjour", systemImage: "magnifyingglass")
            }

            if !browser.peers.isEmpty {
                Divider()

                ForEach(browser.peers) { peer in
                    Button {
                        RemoteControllerClient.shared.connectToLocalNetworkPeer(peer)
                    } label: {
                        Label(peer.name, systemImage: "ipad")
                    }
                }
            } else if hasStartedBonjourSearch {
                Label(browser.statusText, systemImage: "info.circle")
            }
        } label: {
            Label("LAN", systemImage: "network")
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .sheet(isPresented: $isManualConnectPresented) {
            LocalNetworkManualConnectSheet()
        }
    }
}

private struct LocalNetworkManualConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var port = String(RemoteControllerLocalNetwork.defaultPort)

    var body: some View {
        NavigationView {
            Form {
                TextField("Host or IP", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)

                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("LAN Host")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        connect()
                    }
                    .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || UInt16(port) == nil)
                }
            }
        }
    }

    private func connect() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = UInt16(port), !trimmedHost.isEmpty else { return }

        RemoteControllerClient.shared.connectToLocalNetworkHost(trimmedHost, port: port)
        dismiss()
    }
}

#if canImport(DeviceDiscoveryUI) && canImport(WiFiAware)
@available(iOS 26.0, *)
private struct WiFiAwareRemoteControllerDevicePicker: View {
    var body: some View {
        DevicePicker(.wifiAware(.connecting(to: .selected([]), from: .melonxRemoteController))) { endpoint in
            RemoteControllerClient.shared.connect(to: endpoint)
        } label: {
            Label("Connect", systemImage: "dot.radiowaves.left.and.right")
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        } fallback: {
            Label("Unavailable", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}
#endif

struct RemoteControllerHostPanel: View {
    @StateObject private var host = RemoteControllerHost.shared

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Remote Controller Host")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host.isRunning ? "Host Running" : "Host Stopped")
                            .font(.subheadline)
                        Text(host.statusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        host.isRunning ? host.stop() : host.start()
                    } label: {
                        Label(host.isRunning ? "Stop" : "Start", systemImage: host.isRunning ? "stop.circle" : "play.circle")
                    }
                    .buttonStyle(.bordered)
                }

                if host.isRunning {
                    RemoteControllerPairingControl()
                }

                if host.connectedControllers > 0 {
                    Label("\(host.connectedControllers) connected", systemImage: "gamecontroller.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RemoteControllerPairingControl: View {
    var body: some View {
        if RemoteControllerWiFiAwareAvailability.isSupported {
            if #available(iOS 26.0, *) {
                WiFiAwareRemoteControllerPairingControl()
            }
        } else {
            Label("LAN fallback active: connect from iPhone with Manual Host \(RemoteControllerLocalNetwork.endpointDescription)", systemImage: "network")
                .foregroundStyle(.secondary)
        }
    }
}

#if canImport(DeviceDiscoveryUI) && canImport(WiFiAware)
@available(iOS 26.0, *)
private struct WiFiAwareRemoteControllerPairingControl: View {
    var body: some View {
        DevicePairingView(.wifiAware(.connecting(to: .melonxRemoteController, from: .selected([])))) {
            Label("Pair iPhone Controller", systemImage: "iphone.radiowaves.left.and.right")
        } fallback: {
            Label("Pairing Unavailable", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}
#endif
