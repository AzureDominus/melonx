//
//  RemoteController.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Foundation

final class RemoteController: BaseController {
    private let stateLock = NSLock()
    private var latestReceivedSequence: UInt32?
    private var pendingState: RemoteControllerState?
    private var isApplyScheduled = false

    init(name: String = "MeloNX Remote Controller") {
        super.init(nativeController: nil, source: .remote, displayName: name)
        type = .proController
    }

    override public func setupController() {
        // Remote controller input comes only from received iPhone packets.
    }

    func apply(_ state: RemoteControllerState) {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard isNewerThanLatestReceived(sequence: state.sequence) else { return }
        latestReceivedSequence = state.sequence
        pendingState = state

        guard !isApplyScheduled else { return }
        isApplyScheduled = true

        inputQueue.async { [weak self] in
            self?.drainLatestState()
        }
    }

    private func drainLatestState() {
        while true {
            stateLock.lock()
            guard let state = pendingState else {
                pendingState = nil
                isApplyScheduled = false
                stateLock.unlock()
                return
            }
            pendingState = nil
            stateLock.unlock()

            for button in VirtualControllerButton.allCases {
                RyujinxBridge.setGamepadButtonState(
                    self.pointer,
                    buttonId: button.rawValue,
                    pressed: state.isPressed(button)
                )
            }

            self.thumbstickMoved(.left, x: Double(state.leftStick.x), y: Double(state.leftStick.y))
            self.thumbstickMoved(.right, x: Double(state.rightStick.x), y: Double(state.rightStick.y))

            if let accel = state.accel, let gyro = state.gyro {
                RyujinxBridge.setGamepadMotion(self.pointer, motionType: 1, axis: accel)
                RyujinxBridge.setGamepadMotion(self.pointer, motionType: 2, axis: gyro)
            }
        }
    }

    private func isNewerThanLatestReceived(sequence: UInt32) -> Bool {
        guard let latestReceivedSequence = latestReceivedSequence else { return true }
        return Int32(bitPattern: sequence &- latestReceivedSequence) > 0
    }
}
