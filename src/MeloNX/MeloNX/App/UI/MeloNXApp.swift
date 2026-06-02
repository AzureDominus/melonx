//
//  MeloNXApp.swift
//  MeloNX
//
//  Created by Stossy11 on 09/11/2025.
//

import SwiftUI

struct EnvironmentVariable: Codable, Hashable {
    let string: String
    var value: String
    
    func set() {
        setenv(string, value, 1)
    }
    
    static func set(_ env: EnvironmentVariable) {
        setenv(env.string, env.value, 1)
    }
}

struct MeloNXApp: View {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasbeenfinished") var inSetup: Bool = true
    @AppStorage("skippedSetup") var skippedSetup: Bool = false
    @AppStorage("firstBoot") var firstBoot: Bool = false
    @AppStorage("MeloNXAppMode") var appModeRaw: String = ""
    @State var viewShown = false
    @State var showedSetup = false

    
    let environment: [EnvironmentVariable] = [
        EnvironmentVariable(string: "MVK_USE_METAL_PRIVATE_API", value: "1"),
        EnvironmentVariable(string: "MVK_CONFIG_USE_METAL_PRIVATE_API", value: "1"),
        EnvironmentVariable(string: "MVK_DEBUG", value: "0"),
        // EnvironmentVariable(string: "MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS", value: "0"),
        EnvironmentVariable(string: "MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE", value: "128"),
        // EnvironmentVariable(string: "MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM", value: "4"),
        EnvironmentVariable(string: "DOTNET_DefaultStackSize", value: "200000") // probably doesn't work on NativeAOT
    ]
    
    let fileManager = FileManager.default

    private static let runtimeInitializationLock = NSLock()
    private static var didInitializeEmulatorRuntime = false
    
    private var shouldShowModeRouter: Bool {
        appModeRaw.isEmpty && UIDevice.current.userInterfaceIdiom == .phone
    }

    private var selectedMode: MeloNXAppMode {
        if let mode = MeloNXAppMode(rawValue: appModeRaw) {
            return mode
        }

        return UIDevice.current.userInterfaceIdiom == .phone ? .controller : .emulator
    }
    
    var body: some View {
        Group {
            if shouldShowModeRouter {
                AppModeRouterView { mode in
                    appModeRaw = mode.rawValue
                }
            } else if selectedMode == .controller {
                RemoteControllerModeView()
            } else {
                EmulatorRuntimeView(environment: environment) {
                    emulatorBody
                }
            }
        }
    }

    @ViewBuilder
    private var emulatorBody: some View {
        Group {
            if !inSetup {
                ContentView(viewShown: $viewShown)
                    .onAppear() {
                        if skippedSetup {
                            return
                        }

                        if !Ryujinx.shared.checkIfKeysImported() {
                            inSetup = true
                        }
                        let firmware = Ryujinx.shared.fetchFirmwareVersion()

                        if (firmware == "" ? "0" : firmware) == "0" {
                            inSetup = true
                        }
                    }
            } else {
                SetupView(isInSetup: $inSetup)
                    .onAppear() {
                        let mp3 = MusicSelectorView.getMP3s().first(where: { $0.builtIn })
                        MusicSelectorView.playMusic(mp3)
                        skippedSetup = false
                    }
                    .onDisappear {
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                            let music = NativeSettingsManager.shared.backgroundMusic("").value
                            MusicSelectorView.stopMusic()
                            if music.isEmpty {
                                if let mp3 = MusicSelectorView.getMP3s().last(where: { $0.builtIn }) {
                                    MusicSelectorView.setMusicItemPath(mp3)
                                    MusicSelectorView.playMusic()
                                }
                            } else {
                                MusicSelectorView.playMusic()
                            }
                        }
                    }
            }
        }
    }
    
    static func initializeEmulatorRuntime(environment: [EnvironmentVariable]) {
        runtimeInitializationLock.lock()
        defer { runtimeInitializationLock.unlock() }

        guard !didInitializeEmulatorRuntime else { return }
        didInitializeEmulatorRuntime = true

        SDL_SetMainReady()
        SDL_iPhoneSetEventPump(SDL_TRUE)
        SDL_Init(SDL_INIT_EVENTS | SDL_INIT_AUDIO)

        environment.forEach { env in
            env.set()
        }
        
        EnvironmentVariable(string: "HAS_TXM", value: ProcessInfo.processInfo.hasTXM && !ProcessInfo.processInfo.isiOSAppOnMac ? "1" : "0").set()

        RyujinxBridge.initialize()
        
        let cool: Bool
        if #available(iOS 19, *) {
            if ProcessInfo.processInfo.hasTXM {
                NativeSettingsManager.shared.setting(forKey: "DUAL_MAPPED_JIT", default: true).value = true
            }
            
            cool = NativeSettingsManager.shared.setting(forKey: "DUAL_MAPPED_JIT", default: true).value
        } else {
            cool = NativeSettingsManager.shared.setting(forKey: "DUAL_MAPPED_JIT", default: false).value
        }
        
        JIT26BreakpointHandler()
        
        if cool {
            EnvironmentVariable(string: "DUAL_MAPPED_JIT", value: "1").set()
            LaunchGameHandler.succeededJIT = RyujinxBridge.initialize_dualmapped()
        } else {
            EnvironmentVariable(string: "DUAL_MAPPED_JIT", value: "0").set()
        }
    }
}

