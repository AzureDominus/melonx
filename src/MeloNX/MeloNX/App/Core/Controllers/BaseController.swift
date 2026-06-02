//
//  BaseController.swift
//  MeloNX
//
//  Created by Stossy11 on 19/10/2025.
//

import Foundation
import CoreHaptics
import UIKit
import GameController
import CoreMotion

enum ControllerSource {
    case onScreenVirtual
    case native
    case remote
}

class BaseController: Equatable, Identifiable {
    private(set) lazy var pointer: UnsafeMutableRawPointer = {
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }()
    
    var id: String {
        let pointerInt64 = Int64(bitPattern: UInt64(UInt(bitPattern: self.pointer)))
        return String(pointerInt64, radix: 16, uppercase: true)
    }
    
    var type: ControllerType
    var source: ControllerSource
    var virtual: Bool = false
    var displayName: String?
    var name: String {
        if let displayName {
            return displayName
        }

        switch source {
        case .onScreenVirtual:
            return "MeloNX Virtual Controller"
        case .native:
            return nativeController?.vendorName ?? "Unknown"
        case .remote:
            return "MeloNX Remote Controller"
        }
    }
    var nativeController: GCController?
    
    // Motion
    var orientation: UIDeviceOrientation = UIDevice.current.orientation == .unknown ? .landscapeLeft : UIDevice.current.orientation
    let motionOperation = OperationQueue()
    var lastAccel = SIMD3<Float>(repeating: 0)
    var lastGyro = SIMD3<Float>(repeating: 0)
    let filterAlpha: Float = 0.05
    
    private var hapticEngine: CHHapticEngine?
    private var rumbleController: RumbleController?
    var motionManager = CMMotionManager()

    var inputQueue: DispatchQueue
    var motionQueue: DispatchQueue
    
    var usesDeviceHandlers: Bool {
        virtual ? true : (name.lowercased() == "Joy-Con (l/R)".lowercased() ||
                          name.lowercased().hasSuffix("backbone") ||
                          name.lowercased() == "backbone one")
    }

    init(nativeController: GCController?, source: ControllerSource? = nil, displayName: String? = nil) {
        self.nativeController = nativeController
        self.source = source ?? (nativeController == nil ? .onScreenVirtual : .native)
        self.displayName = displayName
        self.virtual = self.source == .onScreenVirtual
        self.type = virtual ? .joyconPair : .proController
        
        let identifier = UUID().uuidString
        let queueLabel = virtual ? "com.stossy11.MeloNX.controller.virtual" : "com.stossy11.MeloNX.controller.\(identifier)"
        
        self.inputQueue = DispatchQueue(label: queueLabel, qos: .userInteractive)
        self.motionQueue = DispatchQueue(label: queueLabel + ".motion", qos: .background)
        
        // Only attach once
        RyujinxBridge.attachGamepad(self.pointer, self.name)
        
        setupController()
    }

    public func setupController() {
        // Motion setup is usually low frequency, async is fine here
        inputQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupMotion()
        }
        
        setupHaptics()
    }
    
    func updateAxisValue(x: Float, y: Float, forAxis axis: Int) {
        RyujinxBridge.setGamepadStickAxis(self.pointer, stickId: axis, x: x, y: y)
    }
    
    func thumbstickMoved(_ stick: ThumbstickType, x: Double, y: Double) {
        if stick == .right {
            updateAxisValue(x: Float(x), y: Float(-y), forAxis: 2)
        } else {
            updateAxisValue(x: Float(x), y: Float(-y), forAxis: 1)
        }
    }
    
    func setButtonState(_ state: UInt8, for button: VirtualControllerButton) {
        RyujinxBridge.setGamepadButtonState(self.pointer, buttonId: button.rawValue, pressed: state == 1)
    }
    
    func setupHaptics() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let createHaptic: (Bool) -> Void = { device in
                if let engine = self.hapticEngine {
                    do {
                        try engine.start()
                        self.rumbleController = RumbleController(engine: engine, rumbleMultiplier: device ? 2.0 : 2.5)
                    } catch {
                        self.rumbleController = nil
                    }
                }
                
                RegisterCallbackWithData("rumble-\(self.id)") { data in
                    if let rumbleData = RumbleData(data: data ?? Data()) {
                        self.rumbleController?.rumble(lowFreq: rumbleData.lowFrequency,
                                                    highFreq: rumbleData.highFrequency,
                                                    durationMs: rumbleData.durationMs)
                    }
                }
            }
            
            if let nativeController = self.nativeController, !self.usesDeviceHandlers {
                self.hapticEngine = nativeController.haptics?.createEngine(withLocality: .all)
                createHaptic(false)
            } else {
                self.hapticEngine = try? CHHapticEngine()
                createHaptic(true)
            }
        }
    }

    func cleanup() {
        inputQueue.async { [weak self] in
            guard let self = self else { return }
            RyujinxBridge.detachGamepad(self.pointer)
        }
    }
    
    static func == (lhs: BaseController, rhs: BaseController) -> Bool {
        lhs.id == rhs.id
    }
}
