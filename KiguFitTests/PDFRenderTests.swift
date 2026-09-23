import Foundation
import Testing
@testable import KiguFit

struct PDFRenderTests {
    @MainActor
    @Test func renderSampleReport() throws {
        let payload = SampleShell.payload
        let measurements: [MeasurementValue] = [
            MeasurementValue(key: .headCircumference, valueMM: 570, source: .tape),
            MeasurementValue(key: .headHeight, valueMM: 240, source: .tape),
            MeasurementValue(key: .headWidth, valueMM: 179.5, source: .estimated),
            MeasurementValue(key: .headDepth, valueMM: 224, source: .estimated),
            MeasurementValue(key: .interpupillaryDistance, valueMM: 70.5, source: .scan),
            MeasurementValue(key: .templeWidth, valueMM: 169.5, source: .scan),
            MeasurementValue(key: .bizygomaticWidth, valueMM: 168.1, source: .scan),
            MeasurementValue(key: .chinWidth, valueMM: 138, source: .scan),
            MeasurementValue(key: .eyeToChin, valueMM: 127.1, source: .scan),
            MeasurementValue(key: .chinToMouth, valueMM: 62.2, source: .scan),
            MeasurementValue(key: .mouthWidth, valueMM: 158.2, source: .scan),
            MeasurementValue(key: .noseDepth, valueMM: 22.5, source: .scan),
            MeasurementValue(key: .faceLength, valueMM: 190.3, source: .scan),
            MeasurementValue(key: .neckCircumference, valueMM: 370, source: .estimated),
            MeasurementValue(key: .earToEarOverTop, valueMM: 331.2, source: .estimated),
            MeasurementValue(key: .foreheadToOcciputOverTop, valueMM: 364.5, source: .estimated)
        ]
        let record = ScanRecord(
            clientName: "测试客户（很长很长的名字测试排版）",
            shellName: payload.name,
            shellPayloadData: try payload.encoded(),
            measurements: measurements
        )
        record.verdict = FitEngine.evaluate(shell: payload, measurements: measurements)

        let data = ReportPDFRenderer.renderPDF(record: record)
        #expect(data.count > 2000)

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("test-report.pdf")
        try data.write(to: url)
        print("PDF written to: \(url.path)")

        Attachment.record(data, named: "test-report.pdf")
    }
}
