//
//  RemoteControllerPacket.swift
//  MeloNX
//
//  Created by Codex on 02/06/2026.
//

import Foundation

struct RemoteControllerState {
    static let packetVersion: UInt8 = 1

    var sequence: UInt32
    var timestampNanoseconds: UInt64
    var buttons: UInt64
    var leftStick: SIMD2<Float>
    var rightStick: SIMD2<Float>
    var accel: SIMD3<Float>?
    var gyro: SIMD3<Float>?

    init(
        sequence: UInt32 = 0,
        timestampNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds,
        buttons: UInt64 = 0,
        leftStick: SIMD2<Float> = .zero,
        rightStick: SIMD2<Float> = .zero,
        accel: SIMD3<Float>? = nil,
        gyro: SIMD3<Float>? = nil
    ) {
        self.sequence = sequence
        self.timestampNanoseconds = timestampNanoseconds
        self.buttons = buttons
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.accel = accel
        self.gyro = gyro
    }

    func isPressed(_ button: VirtualControllerButton) -> Bool {
        guard button.rawValue < UInt64.bitWidth else { return false }
        return (buttons & (UInt64(1) << UInt64(button.rawValue))) != 0
    }

    mutating func setButton(_ button: VirtualControllerButton, pressed: Bool) {
        guard button.rawValue < UInt64.bitWidth else { return }
        let mask = UInt64(1) << UInt64(button.rawValue)
        if pressed {
            buttons |= mask
        } else {
            buttons &= ~mask
        }
    }
}

enum RemoteControllerPacket {
    private static let hasMotionFlag: UInt8 = 1 << 0

    static let byteCount = 1 + 1 + 2 + 4 + 8 + 8 + 8 + 12 + 12

    static func encode(_ state: RemoteControllerState) -> Data {
        var data = Data()
        data.reserveCapacity(byteCount)
        data.append(RemoteControllerState.packetVersion)
        data.append((state.accel != nil && state.gyro != nil) ? hasMotionFlag : 0)
        data.appendLittleEndian(UInt16(0))
        data.appendLittleEndian(state.sequence)
        data.appendLittleEndian(state.timestampNanoseconds)
        data.appendLittleEndian(state.buttons)
        data.appendFloat32(state.leftStick.x)
        data.appendFloat32(state.leftStick.y)
        data.appendFloat32(state.rightStick.x)
        data.appendFloat32(state.rightStick.y)

        let accel = state.accel ?? .zero
        let gyro = state.gyro ?? .zero
        data.appendFloat32(accel.x)
        data.appendFloat32(accel.y)
        data.appendFloat32(accel.z)
        data.appendFloat32(gyro.x)
        data.appendFloat32(gyro.y)
        data.appendFloat32(gyro.z)
        return data
    }

    static func decode(_ data: Data) -> RemoteControllerState? {
        guard data.count == byteCount else { return nil }

        var reader = RemoteControllerPacketReader(data: data)
        guard reader.readUInt8() == RemoteControllerState.packetVersion else { return nil }
        guard let flags = reader.readUInt8() else { return nil }
        _ = reader.readUInt16()
        guard
            let sequence = reader.readUInt32(),
            let timestamp = reader.readUInt64(),
            let buttons = reader.readUInt64(),
            let leftX = reader.readFloat32(),
            let leftY = reader.readFloat32(),
            let rightX = reader.readFloat32(),
            let rightY = reader.readFloat32(),
            let accelX = reader.readFloat32(),
            let accelY = reader.readFloat32(),
            let accelZ = reader.readFloat32(),
            let gyroX = reader.readFloat32(),
            let gyroY = reader.readFloat32(),
            let gyroZ = reader.readFloat32()
        else {
            return nil
        }

        let hasMotion = (flags & hasMotionFlag) != 0
        return RemoteControllerState(
            sequence: sequence,
            timestampNanoseconds: timestamp,
            buttons: buttons,
            leftStick: SIMD2<Float>(leftX, leftY),
            rightStick: SIMD2<Float>(rightX, rightY),
            accel: hasMotion ? SIMD3<Float>(accelX, accelY, accelZ) : nil,
            gyro: hasMotion ? SIMD3<Float>(gyroX, gyroY, gyroZ) : nil
        )
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendFloat32(_ value: Float) {
        appendLittleEndian(value.bitPattern)
    }
}

private struct RemoteControllerPacketReader {
    let data: Data
    var offset = 0

    mutating func readUInt8() -> UInt8? {
        guard offset < data.count else { return nil }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func readUInt16() -> UInt16? {
        readInteger()
    }

    mutating func readUInt32() -> UInt32? {
        readInteger()
    }

    mutating func readUInt64() -> UInt64? {
        readInteger()
    }

    mutating func readFloat32() -> Float? {
        guard let bitPattern: UInt32 = readInteger() else { return nil }
        return Float(bitPattern: bitPattern)
    }

    private mutating func readInteger<T: FixedWidthInteger>() -> T? {
        let end = offset + MemoryLayout<T>.size
        guard end <= data.count else { return nil }
        let value = data[offset..<end].reduce(T(0)) { partial, byte in
            (partial << 8) | T(byte)
        }
        offset = end
        return T(littleEndian: value.byteSwapped)
    }
}
