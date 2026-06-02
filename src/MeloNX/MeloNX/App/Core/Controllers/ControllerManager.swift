//
//  ControllerManager.swift
//  MeloNX
//
//  Created by Stossy11 on 19/10/2025.
//

import Foundation
import Combine
import GameController
import SwiftUI

class ControllerManager: ObservableObject {
    static var shared = ControllerManager()
    let virtualController = BaseController(nativeController: nil)
    @AppStorage("isVirtualController") var isVCA: Bool = true
    
    private let controllerQueue = DispatchQueue(label: "com.stossy11.melonx.controllermanager", attributes: .concurrent)
    
    private var _privAllControllers: [BaseController] = []
    @Published var allControllers: [BaseController] = []
    
    @Published var selectedControllers: [String] = [] {
        didSet {
            print(selectedControllers)
        }
    }
    @Published var controllerTypes: [Int: ControllerType] = [:] {
        didSet {
            saveControllerTypes()
        }
    }
    
    func saveControllerTypes() {
        if let data = try? JSONEncoder().encode(controllerTypes) {
            UserDefaults.standard.set(data, forKey: "ControllerTypesForID")
        }
    }

    func loadControllerTypes() {
        if let data = UserDefaults.standard.data(forKey: "ControllerTypesForID") {
            if let decoded = try? JSONDecoder().decode([Int: ControllerType].self, from: data) {
                controllerTypes = decoded
            }
        }
    }
    
    func initAll() {
        refreshControllersList()
        initControllerObservers()
    }
    
    private init() {
        loadControllerTypes()
        
        controllerQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._privAllControllers.append(self.virtualController)
            
            DispatchQueue.main.async {
                self.allControllers = self._privAllControllers
            }
        }
    }
    

    func refreshControllersList() {
        let connectedNativeControllers = Set(GCController.controllers())
        
        controllerQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var controllersToRemove: [BaseController] = []
            for controller in self._privAllControllers where !controller.virtual {
                if let native = controller.nativeController, !connectedNativeControllers.contains(native) {
                    controllersToRemove.append(controller)
                }
            }
            
            for controller in controllersToRemove {
                controller.cleanup()
                self._privAllControllers.removeAll { $0 === controller }
            }
            
            for (index, nativeController) in connectedNativeControllers.enumerated() {
                if !self._privAllControllers.contains(where: { $0.nativeController === nativeController }) {
                    let newController = NativeController(nativeController: nativeController)
                    self._privAllControllers.append(newController)
                }
            }
            
            let physicalControllers = self._privAllControllers.filter { !$0.virtual }.compactMap(\.id) as [String]
            
            DispatchQueue.main.async {
                self.allControllers = self._privAllControllers
                self.selectedControllers.removeAll()
                
                if physicalControllers.isEmpty && !UserDefaults.standard.bool(forKey: "virtualControllerOffDefault") {
                    self.selectedControllers.append(self.virtualController.id)
                } else {
                    self.selectedControllers.append(contentsOf: physicalControllers)
                }
                if Ryujinx.shared.isRunning {
                    Ryujinx.shared.reloadControllersWithInfo()
                }
            }
        }
    }
    
    func controllerAndIndexForString(_ id: String) -> (BaseController, Int)? {
        return controllerQueue.sync {
            guard let controller = _privAllControllers.first(where: { $0.id == id }),
                  let index = _privAllControllers.firstIndex(where: { $0.id == id }) else {
                return nil
            }
            return (controller, index)
        }
    }
    
    func controllerForString(_ id: String) -> BaseController? {
        return controllerQueue.sync {
            return _privAllControllers.first(where: { $0.id == id })
        }
    }

    func registerRemoteController(_ controller: RemoteController) {
        controllerQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            guard !self._privAllControllers.contains(where: { $0 === controller }) else { return }

            self._privAllControllers.append(controller)

            DispatchQueue.main.async {
                self.allControllers = self._privAllControllers
                if !self.selectedControllers.contains(controller.id) {
                    self.selectedControllers.append(controller.id)
                }
                if Ryujinx.shared.isRunning {
                    Ryujinx.shared.reloadControllersWithInfo()
                }
            }
        }
    }

    func unregisterRemoteController(_ controller: RemoteController) {
        controllerQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            controller.cleanup()
            self._privAllControllers.removeAll { $0 === controller }

            DispatchQueue.main.async {
                self.allControllers = self._privAllControllers
                self.selectedControllers.removeAll { $0 == controller.id }
                if Ryujinx.shared.isRunning {
                    Ryujinx.shared.reloadControllersWithInfo()
                }
            }
        }
    }
    
    func firstControllerForName(_ name: String) -> BaseController? {
        return controllerQueue.sync {
            return _privAllControllers.first(where: { $0.nativeController?.vendorName ?? UUID().uuidString == name })
        }
    }
    
    func hasVirtualController() -> Bool {
        return controllerQueue.sync {
            return selectedControllers.contains(_privAllControllers.first(where: { $0.virtual })?.id ?? "Failed to find virtual controller!")
        }
    }
    
    func initControllerObservers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                self.refreshControllersList()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                self.refreshControllersList()
            }
        }
    }
    
    func toggleController(_ baseController: BaseController) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.selectedControllers.firstIndex(where: { $0 == baseController.id }) {
                self.selectedControllers.remove(at: index)
            } else {
                self.selectedControllers.append(baseController.id)
            }
        }
    }
    
    func registerControllerTypeForMatchingControllers() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let selectedIds = self.selectedControllers
            
            for (index, id) in selectedIds.enumerated() {
                if let controller = self.controllerForString(id) {
                    controller.type = self.controllerTypes[index] ?? controller.type
                }
            }
        }
    }
}
