//
//  RemoteController.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Foundation

final class RemoteController: BaseController {
    private var latestSequence: UInt32?

    init(name: String = "MeloNX Remote Controller") {
        super.init(nativeController: nil, source: .remote, displayName: name)
        type = .proController
    }

    override public func setupController() {
        // Remote controller input comes only from received iPhone packets.
    }

    func apply(_ state: RemoteControllerState) {
        inputQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isStale(sequence: state.sequence) else { return }

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
                RyujinxBridge.setGamepadMotion(self.pointer, motionType: 0, axis: accel)
                RyujinxBridge.setGamepadMotion(self.pointer, motionType: 1, axis: gyro)
            }
        }
    }

    private func isStale(sequence: UInt32) -> Bool {
        guard let latestSequence = latestSequence else {
            self.latestSequence = sequence
            return false
        }

        let isNewer = Int32(bitPattern: sequence &- latestSequence) > 0
        if isNewer {
            self.latestSequence = sequence
        }
        return !isNewer
    }
}
