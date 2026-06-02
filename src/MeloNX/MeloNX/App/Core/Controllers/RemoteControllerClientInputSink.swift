//
//  RemoteControllerClientInputSink.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Foundation

protocol RemoteControllerPacketSender: AnyObject {
    var canSendPackets: Bool { get }
    func sendPacket(_ data: Data)
}

final class RemoteControllerClientInputSink: ControllerInputSink {
    private let sender: RemoteControllerPacketSender
    private let stateQueue = DispatchQueue(label: "com.stossy11.MeloNX.remote-controller.client-state", qos: .userInteractive)
    private var state = RemoteControllerState()
    private var timer: DispatchSourceTimer?
    private var sequence: UInt32 = 0

    init(sender: RemoteControllerPacketSender) {
        self.sender = sender
    }

    deinit {
        stopStreaming()
    }

    func startStreaming(framesPerSecond: Int = 60) {
        stopStreaming()

        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        let interval = DispatchTimeInterval.nanoseconds(1_000_000_000 / max(framesPerSecond, 1))
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.sendSnapshot()
        }
        timer.resume()
        self.timer = timer
    }

    func stopStreaming() {
        timer?.cancel()
        timer = nil
    }

    func setButtonState(_ pressed: Bool, for button: VirtualControllerButton) {
        stateQueue.async { [weak self] in
            self?.state.setButton(button, pressed: pressed)
        }
    }

    func setLeftStick(x: Float, y: Float) {
        stateQueue.async { [weak self] in
            self?.state.leftStick = SIMD2<Float>(x, y)
        }
    }

    func setRightStick(x: Float, y: Float) {
        stateQueue.async { [weak self] in
            self?.state.rightStick = SIMD2<Float>(x, y)
        }
    }

    func setMotion(accel: SIMD3<Float>, gyro: SIMD3<Float>) {
        stateQueue.async { [weak self] in
            self?.state.accel = accel
            self?.state.gyro = gyro
        }
    }

    private func sendSnapshot() {
        guard sender.canSendPackets else { return }

        sequence &+= 1
        state.sequence = sequence
        state.timestampNanoseconds = DispatchTime.now().uptimeNanoseconds
        sender.sendPacket(RemoteControllerPacket.encode(state))
    }
}
