//
//  Joystick.swift
//  MeloNX
//
//  Created by Stossy11 on 21/03/2025.
//


import UIKit
import SwiftUI

final class JoystickView: UIView {
    var right: Bool = true
    var background: Bool = false
    var sensitivity: CGFloat = 1.2
    var inputSink: ControllerInputSink = LocalControllerInputSink()
    
    private var dragDiameter: CGFloat {
        let base: CGFloat = 160
        if UIDevice.current.systemName.contains("iPadOS") {
            return base * 1.2
        }
        return base
    }
    
    private var joystickSize: CGFloat {
        dragDiameter * 0.2
    }
    
    private var boundarySize: CGFloat {
        dragDiameter
    }
    
    var onPositionChanged: ((CGPoint) -> Void)?
    
    private let boundaryView = UIView()
    private let backgroundView = UIView()
    private let joystickView = UIView()
    private let joystickBackgroundView = UIView()
    
    private var offset: CGPoint = .zero
    
    private var extendedRadius: CGFloat {
        let maxRadius = (boundarySize - joystickSize) / 2
        return maxRadius + (joystickSize / 2)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        clipsToBounds = false
        
        addSubview(boundaryView)
        addSubview(backgroundView)
        addSubview(joystickBackgroundView)
        addSubview(joystickView)
        
        backgroundView.backgroundColor = UIColor.gray.withAlphaComponent(0.4)
        backgroundView.alpha = background ? 1 : 0
        
        joystickBackgroundView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        joystickView.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        joystickView.addGestureRecognizer(pan)
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let size = bounds.width
        boundaryView.frame = CGRect(origin: .zero, size: frame.size)
        boundaryView.layer.cornerRadius = size / 2
        
        backgroundView.frame = boundaryView.frame
        backgroundView.layer.cornerRadius = size / 2
        
        joystickBackgroundView.bounds = CGRect(
            x: 0, y: 0,
            width: joystickSize * 1.25,
            height: joystickSize * 1.25
        )
        joystickBackgroundView.layer.cornerRadius = joystickBackgroundView.bounds.width / 2
        
        joystickView.bounds = CGRect(
            x: 0, y: 0,
            width: joystickSize,
            height: joystickSize
        )
        joystickView.layer.cornerRadius = joystickSize / 2
        
        resetPosition()
        
    }
    
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began, .changed:
            animateBackground(show: true)
            
            let distance = hypot(translation.x, translation.y)
            
            if distance <= extendedRadius {
                offset = translation
            } else {
                let angle = atan2(translation.y, translation.x)
                offset = CGPoint(
                    x: cos(angle) * extendedRadius,
                    y: sin(angle) * extendedRadius
                )
            }
            
            updateJoystickPosition()
            
            let normalized = CGPoint(
                x: max(-1, min(1, (offset.x / extendedRadius) * sensitivity)),
                y: max(-1, min(1, (offset.y / extendedRadius) * sensitivity))
            )
            
            onPositionChanged?(normalized)
            sendToController(normalized)
            
        case .ended, .cancelled:
            resetPosition()
            animateBackground(show: false)
            
        default:
            break
        }
    }
    
    
    private func updateJoystickPosition() {
        let centerPoint = CGPoint(
            x: bounds.midX + offset.x,
            y: bounds.midY + offset.y
        )
        
        joystickView.center = centerPoint
        joystickBackgroundView.center = centerPoint
    }
    
    private func resetPosition() {
        offset = .zero
        
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        joystickView.center = centerPoint
        joystickBackgroundView.center = centerPoint
        
        let zero = CGPoint.zero
        onPositionChanged?(zero)
        sendToController(zero)
    }
    
    private func animateBackground(show: Bool) {
        if !background {
            UIView.animate(withDuration: 0.15) {
                self.backgroundView.alpha = show ? 1 : 0
            }
        }
    }
    
    private func sendToController(_ position: CGPoint) {
        if right {
            inputSink.setRightStick(x: Float(position.x), y: Float(position.y))
        } else {
            inputSink.setLeftStick(x: Float(position.x), y: Float(position.y))
        }
    }
}
