//
//  JoystickDPadPoint.swift
//  MeloNX
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI
import Foundation

class JoystickDPadPoint: ObservableObject {
    static var shared = JoystickDPadPoint()
    @Published var joystickDpadPoint: (x: Double, y: Double) = (0, 0)
    @Published var currentlyPressed: Set<VirtualControllerButton> = []
    
    func pressed(_ button: VirtualControllerButton, inputSink: ControllerInputSink = LocalControllerInputSink()) {
        guard button.isDPad else { return }
        currentlyPressed.insert(button)
        print(button)
        print(currentlyPressed)
        recomputeDPad(inputSink: inputSink)
    }

    func released(_ button: VirtualControllerButton, inputSink: ControllerInputSink = LocalControllerInputSink()) {
        guard button.isDPad else { return }
        currentlyPressed.remove(button)
        print(button)
        print(currentlyPressed)
        recomputeDPad(inputSink: inputSink)
    }

    private func recomputeDPad(inputSink: ControllerInputSink) {
        // Y axis
        if currentlyPressed.contains(.dPadUp) {
            joystickDpadPoint.y = -1
        } else if currentlyPressed.contains(.dPadDown) {
            joystickDpadPoint.y = 1
        } else {
            joystickDpadPoint.y = 0
        }

        // X axis
        if currentlyPressed.contains(.dPadLeft) {
            joystickDpadPoint.x = -1
        } else if currentlyPressed.contains(.dPadRight) {
            joystickDpadPoint.x = 1
        } else {
            joystickDpadPoint.x = 0
        }
        
        print(joystickDpadPoint)
        
        inputSink.setLeftStick(x: Float(joystickDpadPoint.x), y: Float(joystickDpadPoint.y))
    }
}
