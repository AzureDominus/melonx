//
//  ControllerInputSink.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Foundation

protocol ControllerInputSink: AnyObject {
    func setButtonState(_ pressed: Bool, for button: VirtualControllerButton)
    func setLeftStick(x: Float, y: Float)
    func setRightStick(x: Float, y: Float)
    func setMotion(accel: SIMD3<Float>, gyro: SIMD3<Float>)
}

extension ControllerInputSink {
    func setStick(_ stick: ThumbstickType, x: Float, y: Float) {
        switch stick {
        case .left:
            setLeftStick(x: x, y: y)
        case .right:
            setRightStick(x: x, y: y)
        }
    }
}

final class NoOpControllerInputSink: ControllerInputSink {
    static let shared = NoOpControllerInputSink()

    private init() {}

    func setButtonState(_ pressed: Bool, for button: VirtualControllerButton) {}
    func setLeftStick(x: Float, y: Float) {}
    func setRightStick(x: Float, y: Float) {}
    func setMotion(accel: SIMD3<Float>, gyro: SIMD3<Float>) {}
}

final class LocalControllerInputSink: ControllerInputSink {
    private let controller: BaseController

    init(controller: BaseController = ControllerManager.shared.virtualController) {
        self.controller = controller
    }

    func setButtonState(_ pressed: Bool, for button: VirtualControllerButton) {
        controller.setButtonState(pressed ? 1 : 0, for: button)
    }

    func setLeftStick(x: Float, y: Float) {
        controller.thumbstickMoved(.left, x: Double(x), y: Double(y))
    }

    func setRightStick(x: Float, y: Float) {
        controller.thumbstickMoved(.right, x: Double(x), y: Double(y))
    }

    func setMotion(accel: SIMD3<Float>, gyro: SIMD3<Float>) {
        RyujinxBridge.setGamepadMotion(controller.pointer, motionType: 1, axis: accel)
        RyujinxBridge.setGamepadMotion(controller.pointer, motionType: 2, axis: gyro)
    }
}
