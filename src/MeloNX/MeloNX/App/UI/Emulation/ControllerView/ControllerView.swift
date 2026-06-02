//
//  ControllerView.swift
//  Pomelo-V2
//
//  Created by Stossy11 on 16/7/2024.
//

import SwiftUI
import GameController
import CoreMotion

// MARK: - Main Controller View

struct LayoutView: View {
    @Binding var isPortrait: Bool
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        Text("")
            .onChange(of: verticalSizeClass) { _ in updateOrientation() }
            .onAppear {
                updateOrientation()
            }
    }
    private func updateOrientation() {
        guard let window = AppDelegate.window else { return }
        isPortrait = window.bounds.size.height > window.bounds.size.width
    }
}

struct ControllerView: View {
    @AppStorage("On-ScreenControllerScale") private var controllerScale: Double = 1.0
    @AppStorage("stickButton") private var stickButton = false
    @State private var hideDpad = false
    @State private var hideABXY = false
    @Binding var isEditing: Bool
    @Binding var isPortrait: Bool
    @State private var selectedButton: String?
    @State private var selectedJoystick: String?
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var showEditControls = true
    @StateObject private var joystickDpadPoint = JoystickDPadPoint()
    let inputSink: ControllerInputSink
    
    // Game-specific layout support
    var gameId: String?
    @State private var layout: LayoutConfig = LayoutConfig()

    init(
        isEditing: Binding<Bool>,
        gameId: String? = nil,
        isPortrait: Binding<Bool> = .constant(false),
        inputSink: ControllerInputSink = LocalControllerInputSink()
    ) {
        self._isEditing = isEditing
        self.gameId = gameId
        self._isPortrait = isPortrait
        self.inputSink = inputSink
    }
    
    var body: some View {
        ZStack {
            Group {
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                if isPortrait && !isPad {
                    portraitLayout
                } else {
                    landscapeLayout
                }
            }
            .padding()
            .onChange(of: verticalSizeClass) { _ in updateOrientation() }
            .onAppear {
                updateOrientation()
                loadLayout()
            }

            // Edit Controls
            if isEditing {
                if showEditControls {
                    LayoutEditorView(hideDpad: $hideDpad, hideABXY: $hideABXY, isEditing: $isEditing, showEditControls: $showEditControls, gameId: gameId, layout: $layout)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                } else {
                    VStack {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showEditControls = true
                                }
                            }) {
                                Image(systemName: showEditControls ? "eye.slash" : "eye")
                                    .padding(12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                        }
                     
                        Spacer()
                    }
                }

            }
        }
    }
    
    private func loadLayout() {
        layout = LayoutManager.shared.load(for: gameId)
        
        let legacyLayout = LayoutManager.shared.loadLegacy(for: gameId)
        if !legacyLayout.isEmpty && layout.buttons.isEmpty {
            layout.buttons = legacyLayout
            LayoutManager.shared.save(layout, for: gameId)
        }
    }
    
    private var portraitLayout: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                HStack(spacing: 30) {
                    VStack(spacing: 15) {
                        shoulderButtonsLeft
                        ZStack {
                            editableJoystick(id: "leftJoystick", showBackground: $hideDpad)
                            
                            if layout.joysticks["leftJoystick"]?.hide ?? true {
                                dpadView
                                    .opacity(hideDpad ? 0 : 1)
                                    .allowsHitTesting(!hideDpad)
                                    .animation(.easeInOut(duration: 0.2), value: hideDpad)
                            } else {
                                dpadView
                            }
                        }
                    }
                    
                    VStack(spacing: 15) {
                        shoulderButtonsRight
                        ZStack {
                            editableJoystick(id: "rightJoystick", iscool: true, showBackground: $hideABXY)
                            if layout.joysticks["rightJoystick"]?.hide ?? true {
                                abxyView
                                    .opacity(hideABXY ? 0 : 1)
                                    .allowsHitTesting(!hideABXY)
                                    .animation(.easeInOut(duration: 0.2), value: hideABXY)
                            } else {
                                abxyView
                            }
                        }
                    }
                }
                
                HStack(spacing: 60) {
                    HStack {
                        editableButton(.leftStick).padding()
                        editableButton(.back)
                    }
                    HStack {
                        editableButton(.start)
                        editableButton(.rightStick).padding()
                    }
                }
            }
        }
    }
    
    private var landscapeLayout: some View {
        VStack {
            Spacer()
            HStack {
                VStack(spacing: 20) {
                    shoulderButtonsLeft
                    ZStack {
                        editableJoystick(id: "leftJoystick", showBackground: $hideDpad)
                        
                        if layout.joysticks["leftJoystick"]?.hide ?? true {
                            dpadView
                                .opacity(hideDpad ? 0 : 1)
                                .allowsHitTesting(!hideDpad)
                                .animation(.easeInOut(duration: 0.2), value: hideDpad)
                        } else {
                            dpadView
                        }
                    }
                }
                
                Spacer()
                centerButtons
                Spacer()
                
                VStack(spacing: 20) {
                    shoulderButtonsRight
                    ZStack {
                        editableJoystick(id: "rightJoystick", iscool: true, showBackground: $hideABXY)
                        if layout.joysticks["rightJoystick"]?.hide ?? true {
                            abxyView
                                .opacity(hideABXY ? 0 : 1)
                                .allowsHitTesting(!hideABXY)
                                .animation(.easeInOut(duration: 0.2), value: hideABXY)
                        } else {
                            abxyView
                        }
                    }
                }
            }
        }
    }
    
    private var centerButtons: some View {
        Group {
            if stickButton {
                VStack {
                    HStack(spacing: 50) {
                        editableButton(.leftStick).padding()
                        Spacer()
                        editableButton(.rightStick).padding()
                    }
                    .padding(.top, 30)
                    
                    HStack(spacing: 50) {
                        editableButton(.back)
                        Spacer()
                        editableButton(.start)
                    }
                }
                .padding(.bottom, 20)
            } else {
                HStack(spacing: 50) {
                    editableButton(.back)
                    Spacer()
                    editableButton(.start)
                }
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Button Groups
    
    private var shoulderButtonsLeft: some View {
        HStack(spacing: 20) {
            editableButton(.leftTrigger)
            editableButton(.leftShoulder)
        }
        .frame(width: 160 * CGFloat(controllerScale), height: 20 * CGFloat(controllerScale))
    }
    
    private var shoulderButtonsRight: some View {
        HStack(spacing: 20) {
            editableButton(.rightShoulder)
            editableButton(.rightTrigger)
        }
        .frame(width: 160 * CGFloat(controllerScale), height: 20 * CGFloat(controllerScale))
    }
    
    private var dpadView: some View {
        VStack(spacing: 7) {
            editableButton(.dPadUp)
            HStack(spacing: 22) {
                editableButton(.dPadLeft)
                Spacer(minLength: 22)
                editableButton(.dPadRight)
            }
            editableButton(.dPadDown)
        }
        .frame(width: 145 * CGFloat(controllerScale), height: 145 * CGFloat(controllerScale))
    }
    
    private var abxyView: some View {
        VStack(spacing: 7) {
            editableButton(.X)
            HStack(spacing: 22) {
                editableButton(.Y)
                Spacer(minLength: 22)
                editableButton(.A)
            }
            editableButton(.B)
        }
        .frame(width: 145 * CGFloat(controllerScale), height: 145 * CGFloat(controllerScale))
    }

    // MARK: - Helper Methods
    
    private func editableButton(_ button: VirtualControllerButton) -> some View {
        EditableButtonView(
            button: button,
            layout: $layout,
            isEditing: isEditing,
            selectedButton: $selectedButton,
            selectedJoystick: $selectedJoystick,
            inputSink: inputSink,
            joystickDpadPoint: joystickDpadPoint
        )
    }
    
    private func editableJoystick(
        id: String,
        iscool: Bool = false,
        showBackground: Binding<Bool>
    ) -> some View {
        EditableJoystickView(
            id: id,
            iscool: iscool,
            showBackground: showBackground,
            layout: $layout,
            isEditing: isEditing,
            selectedJoystick: $selectedJoystick,
            selectedButton: $selectedButton,
            inputSink: inputSink
        )
    }

    private func updateOrientation() {
        guard let window = AppDelegate.window else { return }
        isPortrait = window.bounds.size.height > window.bounds.size.width
    }
}
