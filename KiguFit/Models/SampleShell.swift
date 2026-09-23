import Foundation

nonisolated enum SampleShell {
    static let payload: ShellProfilePayload = ShellProfilePayload(
        name: "客户吐舌头定（示例）",
        source: .init(file: "客户吐舌头定.obj", unit: "mm"),
        outer: .init(width: 232.4, depth: 317.5, height: 297.0),
        inner: .init(
            height: 292.8,
            wallThickness: 3.0,
            widthProfile: [
                .init(z: -100, width: 105.6),
                .init(z: -80, width: 138.9),
                .init(z: -60, width: 180.5),
                .init(z: -40, width: 211.3),
                .init(z: -21, width: 223.2),
                .init(z: 0, width: 223.1),
                .init(z: 20, width: 213.0),
                .init(z: 40, width: 218.0),
                .init(z: 60, width: 217.5),
                .init(z: 80, width: 209.3),
                .init(z: 100, width: 199.1),
                .init(z: 120, width: 169.3),
                .init(z: 140, width: 109.1)
            ],
            depthProfile: [
                .init(z: -60, depth: 276.5),
                .init(z: -40, depth: 275.0),
                .init(z: -21, depth: 280.9),
                .init(z: 0, depth: 287.6),
                .init(z: 20, depth: 292.7),
                .init(z: 40, depth: 294.7),
                .init(z: 60, depth: 292.4),
                .init(z: 80, depth: 286.5),
                .init(z: 100, depth: 272.0),
                .init(z: 120, depth: 253.2),
                .init(z: 140, depth: 217.7)
            ],
            faceBowlWidth: 180.5
        ),
        eyeHoles: .init(width: 47, height: 26, centerSpacing: 100, centerAboveInnerBottom: 104.7),
        fit: .init(
            headCircumferenceRange: [520, 620],
            notes: "大容积型；前脸与后壳为分体结构，装配时整体深度可能缩小 20-40mm"
        ),
        notes: "数据来源：用户提供的 OBJ 模型网格解析（壁厚实测约 3mm）"
    )
}
