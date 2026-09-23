import Foundation
import simd

struct FaceFrame: Sendable {
    var vertices: [SIMD3<Float>]
    var leftEye: SIMD3<Float>
    var rightEye: SIMD3<Float>
    var faceTransform: [Float]
    var timestamp: Double
}

struct ScanCaptureResult: Sendable {
    var averagedVertices: [SIMD3<Float>]
    var leftEye: SIMD3<Float>
    var rightEye: SIMD3<Float>
    var faceTransform: [Float]
    var frames: [FaceFrame]
    var quality: Double
    var capturedAt: Date

    static let empty = ScanCaptureResult(
        averagedVertices: [],
        leftEye: .zero,
        rightEye: .zero,
        faceTransform: [],
        frames: [],
        quality: 0,
        capturedAt: Date()
    )
}

enum FaceMeshCodec {
    static let magic: UInt32 = 0x4B47_5531
    static let version: UInt32 = 1

    static func encode(_ result: ScanCaptureResult) -> Data {
        var data = Data()
        data.append(uint32: magic)
        data.append(uint32: version)
        data.append(uint32: UInt32(result.frames.count))
        data.append(uint32: UInt32(result.averagedVertices.count))
        data.append(float: Float(result.quality))
        data.append(double: result.capturedAt.timeIntervalSince1970)
        data.append(vertices: result.averagedVertices)
        data.append(vector: result.leftEye)
        data.append(vector: result.rightEye)
        data.append(floats: result.faceTransform)
        for frame in result.frames {
            data.append(double: frame.timestamp)
            data.append(vector: frame.leftEye)
            data.append(vector: frame.rightEye)
            data.append(floats: frame.faceTransform)
            data.append(vertices: frame.vertices)
        }
        return data
    }

    static func decode(_ data: Data) -> ScanCaptureResult? {
        var reader = BinaryReader(data: data)
        guard let magic = reader.readUInt32(), magic == FaceMeshCodec.magic,
              let _ = reader.readUInt32(),
              let frameCount = reader.readUInt32(),
              let _ = reader.readUInt32(),
              let quality = reader.readFloat(),
              let timestamp = reader.readDouble(),
              let averaged = reader.readVertices(),
              let leftEye = reader.readVector(),
              let rightEye = reader.readVector(),
              let transformCount = reader.readFloatsCount(),
              let faceTransform = reader.readFloats(count: transformCount) else {
            return nil
        }
        var frames: [FaceFrame] = []
        frames.reserveCapacity(Int(frameCount))
        for _ in 0..<frameCount {
            guard let ts = reader.readDouble(),
                  let le = reader.readVector(),
                  let re = reader.readVector(),
                  let count = reader.readFloatsCount(),
                  let transform = reader.readFloats(count: count),
                  let verts = reader.readVertices() else {
                return nil
            }
            frames.append(FaceFrame(vertices: verts, leftEye: le, rightEye: re, faceTransform: transform, timestamp: ts))
        }
        return ScanCaptureResult(
            averagedVertices: averaged,
            leftEye: leftEye,
            rightEye: rightEye,
            faceTransform: faceTransform,
            frames: frames,
            quality: Double(quality),
            capturedAt: Date(timeIntervalSince1970: timestamp)
        )
    }
}

private struct BinaryReader {
    let data: Data
    var offset: Int = 0

    mutating func readUInt32() -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let value = data[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        offset += 4
        return value
    }

    mutating func readFloat() -> Float? {
        guard offset + 4 <= data.count else { return nil }
        let value = data[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
        offset += 4
        return value
    }

    mutating func readDouble() -> Double? {
        guard offset + 8 <= data.count else { return nil }
        let value = data[offset..<offset + 8].withUnsafeBytes { $0.loadUnaligned(as: Double.self) }
        offset += 8
        return value
    }

    mutating func readFloatsCount() -> Int? {
        guard let count = readUInt32() else { return nil }
        return Int(count)
    }

    mutating func readFloats(count: Int) -> [Float]? {
        let byteCount = count * 4
        guard offset + byteCount <= data.count else { return nil }
        var values = [Float](repeating: 0, count: count)
        _ = values.withUnsafeMutableBytes { destination in
            data.copyBytes(to: destination, from: offset..<offset + byteCount)
        }
        offset += byteCount
        return values
    }

    mutating func readVector() -> SIMD3<Float>? {
        guard let values = readFloats(count: 3) else { return nil }
        return SIMD3<Float>(values[0], values[1], values[2])
    }

    mutating func readVertices() -> [SIMD3<Float>]? {
        guard let count = readUInt32() else { return nil }
        guard let values = readFloats(count: Int(count) * 3) else { return nil }
        var result = [SIMD3<Float>]()
        result.reserveCapacity(Int(count))
        for index in stride(from: 0, to: Int(count) * 3, by: 3) {
            result.append(SIMD3<Float>(values[index], values[index + 1], values[index + 2]))
        }
        return result
    }
}

private extension Data {
    mutating func append(uint32 value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(float value: Float) {
        Swift.withUnsafeBytes(of: value.bitPattern.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(double value: Double) {
        Swift.withUnsafeBytes(of: value.bitPattern.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(vector: SIMD3<Float>) {
        append(floats: [vector.x, vector.y, vector.z])
    }

    mutating func append(floats: [Float]) {
        append(uint32: UInt32(floats.count))
        for value in floats {
            append(float: value)
        }
    }

    mutating func append(vertices: [SIMD3<Float>]) {
        append(uint32: UInt32(vertices.count))
        for vertex in vertices {
            append(float: vertex.x)
            append(float: vertex.y)
            append(float: vertex.z)
        }
    }
}
