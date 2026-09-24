import Foundation
import Testing
@testable import KiguFit

struct OBJParserTests {
    @Test func parsesVerticesAndTriangles() throws {
        let text = """
        # comment
        v 0 0 0
        v 10 0 0
        v 0 10 0
        v 0 0 10
        f 1 2 3
        f 1/1/1 3/3/3 4/4/4
        """
        let mesh = try OBJParser.parse(data: Data(text.utf8))
        #expect(mesh.vertexCount == 4)
        #expect(mesh.triangleCount == 2)
        #expect(mesh.vertex(1) == SIMD3<Float>(10, 0, 0))
    }

    @Test func triangulatesQuadsAndNegativeIndices() throws {
        let text = """
        v 0 0 0
        v 1 0 0
        v 1 1 0
        v 0 1 0
        f -4 -3 -2 -1
        """
        let mesh = try OBJParser.parse(data: Data(text.utf8))
        #expect(mesh.vertexCount == 4)
        #expect(mesh.triangleCount == 2)
    }
}

struct ShellProfilePayloadTests {
    @Test func bandWidthPrefersFraction() {
        let inner = ShellProfilePayload.InnerDimensions(
            height: 300,
            wallThickness: 3,
            widthProfile: [
                .init(z: -150, width: 100, fraction: 0),
                .init(z: 0, width: 200, fraction: 0.5),
                .init(z: 150, width: 80, fraction: 1)
            ],
            depthProfile: nil,
            faceBowlWidth: nil
        )
        #expect(inner.bandWidth() == 200)
    }

    @Test func bandWidthFallsBackToLegacyAbsoluteZ() {
        let inner = ShellProfilePayload.InnerDimensions(
            height: 300,
            wallThickness: 3,
            widthProfile: [
                .init(z: 0, width: 190),
                .init(z: 20, width: 213),
                .init(z: 40, width: 200)
            ],
            depthProfile: nil,
            faceBowlWidth: nil
        )
        #expect(inner.bandWidth() == 213)
    }

    @Test func decodesLegacyJSONWithoutFraction() throws {
        let json = """
        {"schema":"kigufit.shell/v1","name":"x","outer":{"width":1,"depth":1,"height":1},"inner":{"height":1,"widthProfile":[{"z":0,"width":10}]}}
        """
        let payload = try ShellProfilePayload.decode(from: Data(json.utf8))
        #expect(payload.inner.widthProfile.first?.width == 10)
        #expect(payload.inner.widthProfile.first?.fraction == nil)
    }
}
