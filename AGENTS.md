# KiguFit — AGENTS.md

面向 Kigurumi 头壳制作的 iOS 测量与适配 App。用前置 TrueDepth 3D 扫描面部 +
软尺手动测量，生成"三方通用"的适配报告（佩戴客户 / 头壳店家 / 建模打印方）。

## 技术栈与约束

- 纯 SwiftUI（不做 Flutter），最低 iOS 17，仅竖屏
- 前置 TrueDepth + ARKit `ARFaceTrackingConfiguration`（无预览 ARSession；多姿势引导采集：正视/左转/右转/抬头/低头，扫描前有准备清单：去眼镜/刘海/遮挡物）
- 后置 LiDAR 头模扫描（`ObjectCaptureSession` + 机内 `PhotogrammetrySession` 重建，输出 USDZ/OBJ；仅 Pro 机型）
- SwiftData 持久化；`UIGraphicsPDFRenderer` 生成 PDF
- 自签部署：免费 Apple ID（7 天有效期，AltStore/SideStore 续签），真机调试必需
- 权限：`NSCameraUsageDescription`（已配置）；无 TrueDepth 设备降级为纯手动模式
- 提交规范：Conventional Commits（gitmessage 模板：type(scope): subject，中文 subject）

## 路线图

- **P1（当前）**：扫描核心 + 软尺录入（头围/头高必填）+ 记录列表 + JSON/PDF 导出（三方通用，含 AI 段落预留位）+ LiDAR 头模扫描（USDZ/OBJ 导出）
- **P2**：剖面可视化、头壳档案管理/导入 UI、打磨
- **P3**：本地 OBJ 分析引擎 + BYOK LLM 流水线（几何摘要上云，原始 OBJ 不出本机）
- **P4**：多步对话 Agent（tool-calling、跨记录分析）

## 测量参数矩阵

| key | 名称 | 来源 | 备注 |
|---|---|---|---|
| headCircumference | 头围 | tape | **必填** |
| headHeight | 头高（下巴-头顶） | tape | **必填** |
| headWidth | 头宽（耳上最宽） | scan 估算 / tape 校准 | |
| headDepth | 头长（额-后脑直线） | tape 可选 | 缺失时估算并标低置信 |
| earToEarOverTop | 耳-耳过头顶弧 | tape 可选 | |
| foreheadToOcciputOverTop | 额-后脑过头顶弧 | tape 可选 | |
| neckCircumference | 脖围 | tape 可选 | |
| interpupillaryDistance | 瞳距 | scan | ARFaceAnchor 双眼 transform |
| templeWidth | 太阳穴宽 | scan | |
| bizygomaticWidth | 颧骨宽 | scan | |
| chinWidth | 下巴宽 | scan | |
| eyeToChin | 眼睛高度（瞳线→下巴底） | scan | |
| chinToMouth | 下巴高度（下巴底→嘴缝） | scan | |
| mouthWidth | 嘴宽 | scan | |
| noseDepth | 鼻深 | scan | |
| faceLength | 脸长（发际线→下巴） | scan | |

原则：每个值都带 `source(scan/tape/estimated)` + 置信度；报告必须标注来源。

## JSON Schema（通用交换格式）

### kigufit.shell/v1（头壳档案）

```json
{
  "schema": "kigufit.shell/v1",
  "name": "客户吐舌头定",
  "source": { "file": "客户吐舌头定.obj", "unit": "mm" },
  "outer": { "width": 232.4, "depth": 317.5, "height": 297.0 },
  "inner": {
    "height": 292.8,
    "wallThickness": 3.0,
    "widthProfile": [{ "z": -21, "width": 223.2 }, { "z": 20, "width": 213.0 }],
    "depthProfile": [{ "z": 20, "depth": 292.7 }],
    "faceBowlWidth": 180.5
  },
  "eyeHoles": { "width": 47, "height": 26, "centerSpacing": 100, "centerAboveInnerBottom": 104.7 },
  "fit": { "headCircumferenceRange": [520, 620], "notes": "大容积型，靠内衬海绵固定" }
}
```

### kigufit.scan/v1（测量记录导出）

```json
{
  "schema": "kigufit.scan/v1",
  "client": "客户代号",
  "date": "2026-09-23T22:00:00Z",
  "shell": { "name": "客户吐舌头定", "schemaRef": "kigufit.shell/v1" },
  "measurements": [
    { "key": "headCircumference", "value": 570, "unit": "mm", "source": "tape", "confidence": 1.0 }
  ],
  "verdict": { "level": "good", "summary": "…", "suggestions": [] },
  "aiNarrative": "（P3 预留，可选）"
}
```

## 适配规则引擎（P1）

- 内腔余量：`shell.inner.widthProfile 在头带高度(z≈20) - (headWidth + 期望海绵总厚)` 
- 眼位对位：`eyeToChin` vs `eyeHoles.centerAboveInnerBottom`，偏差 > ±15mm 提示
- 脸碗：脸宽（颧骨宽）vs `inner.faceBowlWidth`，需留余量
- 结论：`good / tight / loose / unfit` + 建议（海绵厚度 mm、整体缩放 %）
- **数值全部本地计算，LLM（P3）只做解读叙述**

## 报告（PDF，三方通用）

- 第 1 页（客户/店家）：结论徽章、一句话建议、海绵建议、关键对照表（红黄绿）、(P3) AI 解读段落（默认包含可关闭）
- 第 2 页（建模/打印方）：全量数据表（含来源）、俯视剖面叠加图、缩放建议（uniform %）、头壳 JSON 元信息
- 同时支持导出 `kigufit.scan/v1` JSON

## P3 LLM 设计（BYOK，流水线）

- 设置页配置 Provider（DeepSeek 默认，OpenAI 兼容，可换 Base URL/Model），API Key 存 Keychain
- 两条流水线：① OBJ → 本地分析 → shell JSON → AI 解读；② 记录 → AI 解读
- 上云内容为**几何摘要**（截面轮廓/剖面/统计）、测量值与规则结果；原始 OBJ 不出本机
- 无 Key/断网 → 降级回本地模板文案
- 本地 OBJ 分析算法（P3 移植自 Mac 侧分析脚本，已验证）：包围盒、分层截面、壁厚、法向内外分类、眼孔检测（占据栅格+洪泛）、连通分量、内腔剖面

## 目录结构（计划）

```
KiguFit/
  App/            KiguFitApp.swift
  Models/         Measurement.swift, ShellProfile.swift, ScanRecord.swift, SampleShell.swift, HeadModelScan.swift
  Scan/           FaceScanSession.swift, ScanPose.swift, PoseDetector.swift, FaceMeshCodec.swift
  HeadScan/       HeadModelCaptureModel.swift, HeadModelCaptureView.swift
  Measurement/    MeasurementEngine.swift, HeadEstimator.swift
  Fit/            FitEngine.swift, FitVerdict.swift
  Report/         ReportPDFRenderer.swift, ExportService.swift
  Views/          RootView.swift, RecordsView.swift, ShellsView.swift, SettingsView.swift,
                  ScanFlowView.swift, ScanGuidanceView.swift, ManualEntryView.swift, ScanSummaryView.swift,
                  ReportView.swift, HeadModelsView.swift
```

（工程使用 Xcode FileSystemSynchronizedRootGroup：新文件放入目录即自动加入构建，无需改 pbxproj）

## 开发命令

```bash
# 构建（模拟器，可无真机快速验证编译）
xcodebuild -project KiguFit.xcodeproj -scheme KiguFit -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build

# 真机运行：Xcode 连接 iPhone ⌘R（免费签名 7 天有效，AltStore 续签）
```

- 模拟器不支持 ARKit 人脸跟踪：扫描逻辑需真机验证，其余 UI 可模拟器预览
- 运行时代码需检查 `ARFaceTrackingConfiguration.isSupported`

## 关键决策记录

1. SwiftUI / iOS 17 / 竖屏 / 纯原生（无 Flutter）——ARKit 只有原生 API，且仅 iOS 可用
2. 报告三方通用：一页客户向，一页数据向；每个数值带来源标注
3. 原始人脸网格**保存**（平均网格 + 关键帧采样，SwiftData externalStorage）
4. 软尺项：头围 + 头高必填，其余可跳过（缺失按比例估算并标低置信）
5. P3 只做流水线，P4 才做多步对话；BYOK 不回传服务端
6. AI 解读文本默认包含在 PDF 中、可关闭
