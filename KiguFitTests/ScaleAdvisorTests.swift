import Foundation
import Testing
@testable import KiguFit

struct ScaleAdvisorTests {
    private func sampleMeasurements() -> [MeasurementValue] {
        [
            MeasurementValue(key: .headWidth, valueMM: 181.6, source: .scan),
            MeasurementValue(key: .headHeight, valueMM: 240, source: .tape),
            MeasurementValue(key: .headDepth, valueMM: 232.5, source: .tape),
            MeasurementValue(key: .bizygomaticWidth, valueMM: 168.1, source: .scan),
            MeasurementValue(key: .eyeToChin, valueMM: 127.1, source: .scan)
        ]
    }

    @Test func satisfiedWithDefaultFoam() throws {
        let result = try #require(ScaleAdvisor.evaluate(
            shell: SampleShell.payload,
            measurements: sampleMeasurements(),
            config: ScaleAdvisor.Config()
        ))
        #expect(result.uniformScalePercent == 0)
        let band = try #require(result.requirements.first { $0.id == "band" })
        #expect(abs(band.needMM - 197.6) < 0.01)
        #expect(band.deltaMM < 0)
    }

    @Test func thickSideFoamNeedsUniformScale() throws {
        let result = try #require(ScaleAdvisor.evaluate(
            shell: SampleShell.payload,
            measurements: sampleMeasurements(),
            config: ScaleAdvisor.Config(sideFoamMM: 20, topFoamMM: 10, backFoamMM: 10)
        ))
        #expect(result.uniformScalePercent > 3.5 && result.uniformScalePercent < 4.5)
        #expect(result.directions.contains { $0.contains("两侧") })
    }

    @Test func eyeAlignmentNoteIncluded() throws {
        let result = try #require(ScaleAdvisor.evaluate(
            shell: SampleShell.payload,
            measurements: sampleMeasurements(),
            config: ScaleAdvisor.Config()
        ))
        #expect(result.notes.contains { $0.contains("眼位") })
    }
}
