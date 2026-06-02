//
//  AppModeRouterView.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import SwiftUI

enum MeloNXAppMode: String {
    case emulator
    case controller
}

struct AppModeRouterView: View {
    let selectMode: (MeloNXAppMode) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("MeloNX")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    Button {
                        selectMode(.controller)
                    } label: {
                        Label("Use this iPhone as Controller", systemImage: "iphone.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        selectMode(.emulator)
                    } label: {
                        Label("Set up MeloNX on this device", systemImage: "gamecontroller")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Choose Mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EmulatorRuntimeView<Content: View>: View {
    private let content: Content

    init(environment: [EnvironmentVariable], @ViewBuilder content: () -> Content) {
        MeloNXApp.initializeEmulatorRuntime(environment: environment)
        self.content = content()
    }

    var body: some View {
        content
    }
}
