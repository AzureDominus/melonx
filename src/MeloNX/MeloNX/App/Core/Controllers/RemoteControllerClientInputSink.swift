//
//  RemoteControllerClientInputSink.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import CoreMotion
import Foundation
import UIKit

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
    private let motionManager = CMMotionManager()
    private let motionOperationQueue = OperationQueue()

    init(sender: RemoteControllerPacketSender) {
        self.sender = sender
    }

    deinit {
        stopStreaming()
        stopMotionUpdates()
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

    func startMotionUpdates(framesPerSecond: Int = 60) {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / Double(max(framesPerSecond, 1))
        motionManager.startDeviceMotionUpdates(to: motionOperationQueue) { [weak self] data, _ in
            guard let self = self, let motion = data else { return }

            let rawAccel = SIMD3<Float>(
                -Float(motion.gravity.x + motion.userAcceleration.x),
                -Float(motion.gravity.y + motion.userAcceleration.y),
                -Float(motion.gravity.z + motion.userAcceleration.z)
            )

            let rawGyro = SIMD3<Float>(
                Float(motion.rotationRate.x),
                -Float(motion.rotationRate.y),
                -Float(motion.rotationRate.z)
            ) * (180.0 / Float.pi)

            let (mappedAccel, mappedGyro) = Self.remapToSwitchCoords(accel: rawAccel, gyro: rawGyro)
            self.setMotion(accel: mappedAccel, gyro: mappedGyro)
        }
    }

    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        stateQueue.async { [weak self] in
            self?.state.accel = nil
            self?.state.gyro = nil
        }
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

    private static func remapToSwitchCoords(accel: SIMD3<Float>, gyro: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return (
                SIMD3<Float>(accel.y, -accel.x, accel.z),
                SIMD3<Float>(gyro.y, -gyro.x, gyro.z)
            )
        case .landscapeRight:
            return (
                SIMD3<Float>(-accel.y, accel.x, accel.z),
                SIMD3<Float>(-gyro.y, gyro.x, gyro.z)
            )
        default:
            return (
                SIMD3<Float>(accel.x, accel.z, -accel.y),
                SIMD3<Float>(gyro.x, gyro.z, -gyro.y)
            )
        }
    }
}
