//
//  JoystickView.swift
//  MeloNX
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI

struct EditableJoystickView: View {
    let id: String
    let iscool: Bool
    @Binding var showBackground: Bool
    @Binding var layout: LayoutConfig
    var isEditing: Bool
    @Binding var selectedJoystick: String?
    @Binding var selectedButton: String?
    let inputSink: ControllerInputSink
    @GestureState private var dragOffset = CGSize.zero
    @AppStorage("On-ScreenControllerScale") var controllerScale: Double = 1.0

    init(
        id: String,
        iscool: Bool,
        showBackground: Binding<Bool>,
        layout: Binding<LayoutConfig>,
        isEditing: Bool,
        selectedJoystick: Binding<String?>,
        selectedButton: Binding<String?>,
        inputSink: ControllerInputSink = LocalControllerInputSink()
    ) {
        self.id = id
        self.iscool = iscool
        self._showBackground = showBackground
        self._layout = layout
        self.isEditing = isEditing
        self._selectedJoystick = selectedJoystick
        self._selectedButton = selectedButton
        self.inputSink = inputSink
    }
    
    var body: some View {
        if isEditing {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 160, height: 160)
                .overlay(
                    Text("Joystick")
                        .font(.caption)
                        .foregroundColor(.white)
                )
                .scaleEffect((layout.joysticks[id]?.scale ?? 1.0) * controllerScale)
                .border(selectedJoystick == id ? Color.green : Color.clear, width: 3)
                .offset(
                    x: (layout.joysticks[id]?.offset.width ?? 0) + dragOffset.width,
                    y: (layout.joysticks[id]?.offset.height ?? 0) + dragOffset.height
                )
                .onTapGesture {
                    selectedJoystick = selectedJoystick == id ? nil : id
                    selectedButton = nil
                }
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                            selectedJoystick = id
                            selectedButton = nil
                        }
                        .onEnded { value in
                            layout.joysticks[id, default: JoystickLayout()].offset.width += value.translation.width
                            layout.joysticks[id, default: JoystickLayout()].offset.height += value.translation.height
                        }
                )
        } else {
            JoystickViewRepresentable(right: iscool, showBackground: layout.joysticks[id]?.background ?? false, inputSink: inputSink)
                .frame(width: 160, height: 160)
                .scaleEffect(layout.joysticks[id]?.scale ?? CGFloat(controllerScale))
                .offset(layout.joysticks[id]?.offset ?? .zero)
        }
    }
}
