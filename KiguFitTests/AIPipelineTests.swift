import Foundation
import Testing
@testable import KiguFit

struct AIPipelineTests {
    @Test func recordPromptIncludesMeasurementsAndVerdict() {
        let context = AIPipeline.ReportContext(
            clientName: "客户A",
            shellName: "测试壳",
            dateText: "2026/9/24",
            measurements: [.init(label: "头围", valueMM: 570, source: "软尺")],
            verdictLevel: "适配",
            verdictSummary: "各项余量正常",
            checks: [.init(title: "内腔宽度", detail: "余量 15.7mm", status: "正常")],
            suggestions: ["预计单侧内衬海绵约 15 mm"]
        )
        let messages = AIPipeline.recordMessages(context: context)
        #expect(messages.count == 2)
        #expect(messages[0].role == "system")
        #expect(messages[1].content.contains("570.0"))
        #expect(messages[1].content.contains("头围"))
        #expect(messages[1].content.contains("适配"))
        #expect(messages[1].content.contains("内腔宽度"))
    }

    @Test func shellPromptIncludesKeyDimensions() {
        let context = AIPipeline.ShellContext(
            name: "测试壳",
            outerWidth: 232,
            outerDepth: 317,
            outerHeight: 297,
            innerHeight: 293,
            wallThickness: 3,
            bandWidth: 213,
            bowlWidth: 180.5,
            eyeHoles: nil,
            fitRange: "520–620 mm",
            notes: nil
        )
        let messages = AIPipeline.shellMessages(context: context)
        #expect(messages.count == 2)
        #expect(messages[1].content.contains("213.0"))
        #expect(messages[1].content.contains("520–620"))
    }
}

struct LLMClientTests {
    @Test func parsesOpenAICompatibleReply() throws {
        let json = #"{"choices":[{"message":{"content":"你好，这是解读"}}]}"#
        let content = try LLMClient.parseContent(from: Data(json.utf8))
        #expect(content == "你好，这是解读")
    }

    @Test func rejectsEmptyChoices() {
        let json = #"{"choices":[]}"#
        do {
            _ = try LLMClient.parseContent(from: Data(json.utf8))
            Issue.record("应当抛出错误")
        } catch {
        }
    }
}
