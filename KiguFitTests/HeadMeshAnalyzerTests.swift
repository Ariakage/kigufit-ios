import Foundation
import Testing
@testable import KiguFit

struct HeadMeshAnalyzerTests {
    private func syntheticBust() -> OBJMesh {
        var positions: [Float] = []
        var indices: [Int32] = []

        let rings = 120
        let segments = 64
        let center = SIMD3<Float>(0, 230, 0)
        let radius: Float = 80
        var ringStarts: [Int] = []
        for r in 0...rings {
            let phi = Float.pi * Float(r) / Float(rings)
            ringStarts.append(positions.count / 3)
            for s in 0...segments {
                let theta = 2 * Float.pi * Float(s) / Float(segments)
                positions.append(center.x + radius * sin(phi) * cos(theta))
                positions.append(center.y + radius * cos(phi))
                positions.append(center.z + radius * sin(phi) * sin(theta))
            }
        }
        for r in 0..<rings {
            for s in 0..<segments {
                let a = Int32(ringStarts[r] + s)
                let b = Int32(ringStarts[r] + s + 1)
                let c = Int32(ringStarts[r + 1] + s)
                let d = Int32(ringStarts[r + 1] + s + 1)
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        for x in stride(from: Float(-200), through: 200, by: 20) {
            for y in stride(from: Float(0), through: 80, by: 2) {
                for z in stride(from: Float(-125), through: 125, by: 25) {
                    positions.append(x)
                    positions.append(y)
                    positions.append(z)
                }
            }
        }

        return OBJMesh(positions: positions, indices: indices, groups: [])
    }

    @Test func measuresSyntheticBust() throws {
        let analysis = try HeadMeshAnalyzer.analyze(mesh: syntheticBust(), name: "synthetic")
        #expect(abs(analysis.headWidth - 160) < 30)
        #expect(abs(analysis.headDepth - 160) < 30)
        #expect(abs(analysis.estimatedCircumference - 502) < 80)
        #expect(analysis.unitScaleApplied == 1)
        #expect(analysis.hadShoulders)
    }

    @Test func convertsMeterUnits() throws {
        var mesh = syntheticBust()
        for index in 0..<mesh.positions.count {
            mesh.positions[index] /= 1000
        }
        let analysis = try HeadMeshAnalyzer.analyze(mesh: mesh, name: "meters")
        #expect(analysis.unitScaleApplied == 1000)
        #expect(abs(analysis.headWidth - 160) < 30)
    }
}
