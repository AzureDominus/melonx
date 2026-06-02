//
//  CopyLayoutView.swift
//  MeloNX
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI

struct CopyLayoutView: View {
    let targetGameId: String?
    @Binding var layout: LayoutConfig
    @Environment(\.presentationMode) var presentationMode
    @State private var availableLayouts: [String] = []
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Layouts")) {
                    Button(action: {
                        copyLayout(from: nil)
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            Text("Default Layout")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    ForEach(availableLayouts, id: \.self) { gameId in
                        if gameId != targetGameId {
                            Button(action: {
                                copyLayout(from: gameId)
                            }) {
                                HStack {
                                    Image(systemName: "gamecontroller.fill")
                                        .foregroundColor(.green)
                                    Text(gameId)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Copy Layout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            loadAvailableLayouts()
        }
    }
    
    private func loadAvailableLayouts() {
        availableLayouts = LayoutManager.shared.getAllGameLayouts()
    }
    
    private func copyLayout(from sourceGameId: String?) {
        let sourceLayout = LayoutManager.shared.load(for: sourceGameId)
        layout = sourceLayout
        LayoutManager.shared.save(layout, for: targetGameId)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditableButtonView: View {
    let button: VirtualControllerButton
    @Binding var layout: LayoutConfig
    var isEditing: Bool
    @Binding var selectedButton: String?
    @Binding var selectedJoystick: String?
    let inputSink: ControllerInputSink
    let joystickDpadPoint: JoystickDPadPoint
    @GestureState private var dragOffset = CGSize.zero

    init(
        button: VirtualControllerButton,
        layout: Binding<LayoutConfig>,
        isEditing: Bool,
        selectedButton: Binding<String?>,
        selectedJoystick: Binding<String?>,
        inputSink: ControllerInputSink = LocalControllerInputSink(),
        joystickDpadPoint: JoystickDPadPoint = .shared
    ) {
        self.button = button
        self._layout = layout
        self.isEditing = isEditing
        self._selectedButton = selectedButton
        self._selectedJoystick = selectedJoystick
        self.inputSink = inputSink
        self.joystickDpadPoint = joystickDpadPoint
    }

    var body: some View {
        Group {
            if isEditing {
                ButtonView(disabled: true, button: button)
                    .scaleEffect(layout.buttons[button.id]?.scale ?? 1.0)
                    .border(selectedButton == button.id ? Color.blue : Color.clear, width: 3)
                    .offset(
                        x: (layout.buttons[button.id]?.offset.width ?? 0) + dragOffset.width,
                        y: (layout.buttons[button.id]?.offset.height ?? 0) + dragOffset.height
                    )
                    .onTapGesture {
                        selectedButton = selectedButton == button.id ? nil : button.id
                        selectedJoystick = nil
                    }
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation
                                selectedButton = button.id
                                selectedJoystick = nil
                            }
                            .onEnded { value in
                                layout.buttons[button.id, default: ButtonLayout()].offset.width += value.translation.width
                                layout.buttons[button.id, default: ButtonLayout()].offset.height += value.translation.height
                            }
                    )
            } else {
                if layout.buttons[button.id, default: ButtonLayout()].hidden {
                    ButtonView(button: button, layout: $layout, inputSink: inputSink, joystickDpadPoint: joystickDpadPoint)
                        .scaleEffect(layout.buttons[button.id]?.scale ?? 1.0)
                        .offset(layout.buttons[button.id]?.offset ?? .zero)
                        .opacity(0)
                } else {
                    ButtonView(button: button, layout: $layout, inputSink: inputSink, joystickDpadPoint: joystickDpadPoint)
                        .scaleEffect(layout.buttons[button.id]?.scale ?? 1.0)
                        .offset(layout.buttons[button.id]?.offset ?? .zero)
                }
            }
        }
    }
}
