//
//  JoystickViewRepresentable.swift
//  MeloNX
//
//  Created by Stossy11 on 28/2/2026.
//


import SwiftUI

struct JoystickViewRepresentable: UIViewRepresentable {
    
    var right: Bool
    var showBackground: Bool
    var inputSink: ControllerInputSink
    @Binding var position: CGPoint
    var mPosition: Bool = true
    
    init(right: Bool, showBackground: Bool = false, inputSink: ControllerInputSink = LocalControllerInputSink(), position: Binding<CGPoint>) {
        self.right = right
        self._position = position
        self.showBackground = showBackground
        self.inputSink = inputSink
    }
    
    init(right: Bool, showBackground: Bool = false, inputSink: ControllerInputSink = LocalControllerInputSink()) {
        self.right = right
        self._position = .constant(.zero)
        self.showBackground = showBackground
        self.inputSink = inputSink
        mPosition = false
    }
    
    func makeUIView(context: Context) -> JoystickView {
        let view = JoystickView()
        view.right = right
        view.background = showBackground
        view.inputSink = inputSink
        
        if mPosition {
            view.onPositionChanged = { newPosition in
                DispatchQueue.main.async {
                    self.position = newPosition
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: JoystickView, context: Context) {
        uiView.right = right
        uiView.background = showBackground
        uiView.inputSink = inputSink
    }
}
