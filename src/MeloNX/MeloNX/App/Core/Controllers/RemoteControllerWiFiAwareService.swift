//
//  RemoteControllerWiFiAwareService.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Foundation

#if canImport(WiFiAware)
import WiFiAware

@available(iOS 26.0, *)
extension WAPublishableService {
    static var melonxRemoteController: WAPublishableService {
        allServices["_melonx-ctrl._tcp"]!
    }
}

@available(iOS 26.0, *)
extension WASubscribableService {
    static var melonxRemoteController: WASubscribableService {
        allServices["_melonx-ctrl._tcp"]!
    }
}

enum RemoteControllerWiFiAwareAvailability {
    static var isSupported: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return WACapabilities.supportedFeatures.contains(.wifiAware)
    }
}
#else
enum RemoteControllerWiFiAwareAvailability {
    static var isSupported: Bool { false }
}
#endif
