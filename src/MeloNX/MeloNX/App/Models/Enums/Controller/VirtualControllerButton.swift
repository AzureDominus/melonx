//
//  VirtualControllerButton.swift
//  MeloNX
//
//  Created by Stossy11 on 19/10/2025.
//

import Foundation

enum VirtualControllerButton: Int, Codable, CaseIterable {
    case A
    case B
    case X
    case Y
    case back
    case guide
    case start
    case leftStick
    case rightStick
    case leftShoulder
    case rightShoulder
    case dPadUp
    case dPadDown
    case dPadLeft
    case dPadRight
    case leftTrigger
    case rightTrigger
    
    var isTrigger: Bool {
        switch self {
        case .leftTrigger, .rightTrigger, .leftShoulder, .rightShoulder:
            return true
        default:
            return false
        }
    }
    
    var isDPad: Bool {
        switch self {
        case .dPadUp, .dPadDown, .dPadLeft, .dPadRight:
            return true
        default:
            return false
        }
    }
    
    var isSmall: Bool {
        switch self {
        case .back, .start, .guide:
            return true
        default:
            return false
        }
    }
}
