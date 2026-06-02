//
//  EmulationView.swift
//  MeloNX
//
//  Created by Stossy11 on 09/02/2025.
//

import SwiftUI

// Emulation View
struct EmulationView: View {
    @EnvironmentObject var gameHandler: LaunchGameHandler
    @ObservedObject var controllerManager: ControllerManager = .shared
    
    @AppStorage("performacehud") var performacehud: Bool = false
    @AppStorage("showScreenShotButton") var ssb: Bool = true
    @AppStorage("showlogsgame") var showlogsgame: Bool = false
    
    @AppStorage("On-ScreenControllerOpacity") var controllerOpacity: Double = 1.0
    
    @AppStorage("OldView") var oldView = true
    @State var isPresentedThree: Bool = false
    @State var isAirplaying = Air.shared.connected
    
    @Environment(\.scenePhase) var scenePhase
    @State private var isInBackground = false
    @State var showControllerSettings = false
    @State var pauseEmu = true
    @AppStorage("location-enabled") var locationenabled: Bool = false
    @FocusState private var isFocused: Bool
    @EnvironmentObject var ryujinx: Ryujinx
    @State var rotationlock = false
    @State private var isPortrait: Bool = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
            
            if isAirplaying, !ProcessInfo.processInfo.isiOSAppOnMac {
                TouchView()
                    .ignoresSafeArea()
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        if !ProcessInfo.processInfo.isiOSAppOnMac {
                            Air.play(AnyView(MetalView().ignoresSafeArea().edgesIgnoringSafeArea(.all)))
                        }
                    }
                    .overlay(alignment: .top) {
                        hudView
                    }
            } else {
                // The Emulation View
                if ryujinx.aspectRatio == .stretched || (ryujinx.aspectRatio == .fixed4x3 && isScreenAspectRatio(4, 3)) {
                    MetalView()
                        .allowsHitTesting(true)
                        .ignoresSafeArea(.all)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(alignment: .top) {
                            hudView
                        }
                } else {
                    MetalViewContainer(isPortrait: $isPortrait) {
                        hudView
                    }
                        .allowsHitTesting(true)
                        .if(!isPortrait) {
                            $0
                                .overlay(alignment: .top) {
                                    self.hudView
                                }
                        }
                }
            }
            
            // Above Emulation View
            if controllerManager.hasVirtualController() {
                ControllerView(isEditing: .constant(false), gameId: gameHandler.currentGame?.titleId, isPortrait: $gameHandler.isPortrait) // Virtual Controller
                    .opacity(controllerOpacity)
                    .allowsHitTesting(true)
            } else {
                LayoutView(isPortrait: $gameHandler.isPortrait)
                    .allowsHitTesting(false)
            }
            

            if showlogsgame, !Ryujinx.shared.showLoading {
                VStack {
                    LogView(isfps: false)
                    
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
                    .padding()
            }
        }
        .onAppear {
           Task { @MainActor in
                isFocused = true
            }
            
            // LocationManager.sharedInstance.startUpdatingLocation()
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                Air.shared.connectionCallbacks.append { cool in
                    Task { @MainActor in
                        isAirplaying = cool
                    }
                }
            }
            
            RegisterCallback("exit-emulation") { cool in
               Task { @MainActor in
                    print(cool)
                    self.stop()
                }
            }
        }
        .statusBar(hidden: true)
        .onKeyPress()
        .focused($isFocused)
        .onChange(of: scenePhase) { newPhase in
            // Detect when the app enters the background
            if newPhase == .background {
                RyujinxBridge.pauseEmulation(true)
                isInBackground = true
                pauseEmu = true
            } else if newPhase == .active {
                RyujinxBridge.pauseEmulation(false)
                isInBackground = false
                pauseEmu = false
            } else if newPhase == .inactive {
                RyujinxBridge.pauseEmulation(true)
                isInBackground = true
                pauseEmu = true
            }
        }
        .sheet(isPresented: $showControllerSettings) {
            List {
                VStack {
                    controllerListView
                    if !controllerManager.allControllers.filter({ !contains(controllerManager.selectedControllers, value: $0) }).isEmpty {
                        addControllerButton
                    }
                }
            }
            .onDisappear {
                ryujinx.reloadControllersWithInfo()
            }
        }
    }
    
    @ViewBuilder
    private var hudView: some View {
        HStack {
            if ssb {
                Menu {
                    menuButton
                } label: {
                    ButtonView(disabled: true, button: .guide, opacity: 0.4)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .padding()
            }
            
            Spacer()
            
            if performacehud, getenv("MTL_HUD_ENABLED").flatMap({ String(cString: $0) }) != "1" {
                PerformanceOverlayView()
                    .opacity(controllerOpacity)
                    .padding(5)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var menuButton: some View {
        Button {
            RyujinxBridge.pauseEmulation(pauseEmu)
            pauseEmu.toggle()
        } label: {
            Label {
                Text(pauseEmu ? "Pause" : "Play")
            } icon: {
                Image(systemName: pauseEmu ? "pause.circle" : "play.circle")
            }
        }
        
        Button {
            // ryujijnx.config?.aspectRatio
            ryujinx.aspectRatio = nextAspectRatio(current: ryujinx.aspectRatio)
            

        } label: {
            Label {
                Text(ryujinx.aspectRatio.displayName)
            } icon: {
                Image(systemName: "rectangle.expand.vertical")
            }
        }
        
        Button {
            showControllerSettings = true
        } label: {
            Label {
                Text("Configure Controllers")
            } icon: {
                Image(systemName: "gamecontroller")
            }
        }
        
        //  OrientationManager.lockOrientation(.landscape, rotateTo: .landscapeRight)
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            Button {
                // UIDevice.current.orientation
                rotationlock.toggle()
                if rotationlock {
                    OrientationManager.lockCurrentOrientation(UIDevice.current.orientation)
                } else {
                    OrientationManager.lockOrientation(.all, rotateTo: UIDevice.current.orientation)
                }
            } label: {
                Label {
                    Text("Rotation Lock")
                } icon: {
                    Image(systemName: rotationlock ? "lock" : "lock.open")
                }
            }
        }
        
        Button(role: .destructive) {
            stop()
        } label: {
            Label {
                Text("Exit (Unstable)")
            } icon: {
                Image(systemName: "x.circle")
            }
        }
    }
    
    private var controllerListView: some View {
        ForEach(Array(controllerManager.selectedControllers.enumerated()), id: \.offset) { index, id in
            ControllerRow(
                index: index,
                controllerId: id,
                controllerManager: controllerManager
            )
        }
        .onAppear {
            setupControllerTypes()
        }
    }
    
    private var addControllerButton: some View {
        Menu {
            ForEach(controllerManager.allControllers.filter({ !contains(controllerManager.selectedControllers, value: $0) })) { controller in
                Button {
                    controllerManager.selectedControllers.append(controller.id)
                } label: {
                    Text(controller.name)
                }
            }
        } label: {
            Label("Add Controller", systemImage: "plus.circle.fill")
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
        }
    }
    
    func contains(_ array: [String], value: BaseController) -> Bool {
        array.contains { $0 == value.id }
    }
    
    private func setupControllerTypes() {
        for (index, controllerId) in ControllerManager.shared.selectedControllers.enumerated() {
            let (controller, idx) = controllerManager.controllerAndIndexForString(controllerId)!
            let defaultType: ControllerType = controller.virtual ? .joyconPair : .proController
            ControllerManager.shared.allControllers[idx].type = ControllerManager.shared.controllerTypes[index] ?? defaultType
        }
    }
    
    
    func stop() {
        gameHandler.showApp = true
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            gameHandler.currentGame = nil
            RyujinxBridge.stopEmulation()
            try? ryujinx.stop()
        }
    }
    
    func nextAspectRatio(current: AspectRatio) -> AspectRatio {
        let all = AspectRatio.allCases
        if let index = all.firstIndex(of: current) {
            let nextIndex = (index + 1) % all.count
            return all[nextIndex]
        } else {
            return .fixed16x9 // Default fallback
        }
    }

}

// This is just to stop the sound on macOS when doing a keypress
extension View {
    func onKeyPress() -> some View {
        if #available(iOS 17.0, *), ProcessInfo.processInfo.isiOSAppOnMac {
            return AnyView(self
                .focusable()
                .focusEffectDisabled()
                .onKeyPress { _ in
                    return .handled
                })
        } else {
            return AnyView(self)
        }
    }
}
