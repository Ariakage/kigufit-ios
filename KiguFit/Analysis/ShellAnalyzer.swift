import Foundation
import simd

nonisolated struct ShellAnalysis: Sendable {
    struct ProfilePoint {
        var z: Double
        var fraction: Double
        var value: Double
    }

    struct EyeHoles {
        var width: Double
        var height: Double
        var spacing: Double
        var aboveInnerBottom: Double
    }

    var name: String
    var sourceFile: String?
    var outerWidth: Double
    var outerDepth: Double
    var outerHeight: Double
    var innerHeight: Double
    var innerBottomZ: Double
    var wallThickness: Double?
    var widthProfile: [ProfilePoint]
    var depthProfile: [ProfilePoint]
    var faceBowlWidth: Double?
    var eyeHoles: EyeHoles?
    var componentSummaries: [String]
    var notes: [String]

    func width(atFraction fraction: Double) -> Double? {
        guard !widthProfile.isEmpty else { return nil }
        return widthProfile.min { abs($0.fraction - fraction) < abs($1.fraction - fraction) }?.value
    }

    func payload(sourceFile: String?) -> ShellProfilePayload {
        var noteLines = notes
        if !componentSummaries.isEmpty {
            noteLines.insert("部件：" + componentSummaries.joined(separator: "；"), at: 0)
        }
        return ShellProfilePayload(
            name: name,
            source: .init(file: sourceFile, unit: "mm"),
            outer: .init(width: outerWidth, depth: outerDepth, height: outerHeight),
            inner: .init(
                height: innerHeight,
                wallThickness: wallThickness,
                widthProfile: widthProfile.map { .init(z: $0.z, width: $0.value, fraction: $0.fraction) },
                depthProfile: depthProfile.map { .init(z: $0.z, depth: $0.value, fraction: $0.fraction) },
                faceBowlWidth: faceBowlWidth
            ),
            eyeHoles: eyeHoles.map {
                .init(width: $0.width, height: $0.height, centerSpacing: $0.spacing, centerAboveInnerBottom: $0.aboveInnerBottom)
            },
            fit: nil,
            notes: noteLines.joined(separator: "\n")
        )
    }
}

nonisolated enum ShellAnalyzer {
    enum AnalysisError: Error, LocalizedError {
        case tooFewVertices
        case noComponents

        var errorDescription: String? {
            switch self {
            case .tooFewVertices: return "网格数据太少，无法分析"
            case .noComponents: return "无法识别网格部件"
            }
        }
    }

    private struct DetectedEyes {
        var centerX: Double
        var centerZ: Double
        var centerDepth: Double
        var width: Double
        var height: Double
        var spacing: Double
    }

    static func analyze(mesh: OBJMesh, name: String, sourceFile: String?) throws -> ShellAnalysis {
        let n = mesh.vertexCount
        guard n > 500, mesh.triangleCount > 200 else { throw AnalysisError.tooFewVertices }

        var positions = [SIMD3<Float>](repeating: .zero, count: n)
        for i in 0..<n { positions[i] = mesh.vertex(i) }

        var mn = positions[0]
        var mx = positions[0]
        for p in positions {
            mn = simd_min(mn, p)
            mx = simd_max(mx, p)
        }
        let sizes = SIMD3<Float>(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        let sortedAxes = [0, 1, 2].sorted { sizes[$0] < sizes[$1] }
        let widthAxis = sortedAxes[0]
        let heightAxis = sortedAxes[1]
        let depthAxis = sortedAxes[2]

        var parent = [Int32](repeating: 0, count: n)
        for i in 0..<n { parent[i] = Int32(i) }

        func find(_ value: Int32) -> Int32 {
            var root = value
            while parent[Int(root)] != root { root = parent[Int(root)] }
            var current = value
            while parent[Int(current)] != root {
                let next = parent[Int(current)]
                parent[Int(current)] = root
                current = next
            }
            return root
        }

        func union(_ a: Int32, _ b: Int32) {
            let ra = find(a)
            let rb = find(b)
            if ra != rb { parent[Int(ra)] = rb }
        }

        var vertexNormals = [SIMD3<Float>](repeating: .zero, count: n)
        var edgeCounts = [UInt64: Int]()
        edgeCounts.reserveCapacity(mesh.indices.count)

        var t = 0
        while t + 2 < mesh.indices.count {
            let i0 = mesh.indices[t]
            let i1 = mesh.indices[t + 1]
            let i2 = mesh.indices[t + 2]
            union(i0, i1)
            union(i1, i2)

            let p0 = positions[Int(i0)]
            let p1 = positions[Int(i1)]
            let p2 = positions[Int(i2)]
            let normal = simd_cross(p1 - p0, p2 - p0)
            vertexNormals[Int(i0)] += normal
            vertexNormals[Int(i1)] += normal
            vertexNormals[Int(i2)] += normal

            let a = UInt32(bitPattern: i0)
            let b = UInt32(bitPattern: i1)
            let c = UInt32(bitPattern: i2)
            for (u, v) in [(a, b), (b, c), (c, a)] {
                let key = u < v ? (UInt64(u) << 32 | UInt64(v)) : (UInt64(v) << 32 | UInt64(u))
                edgeCounts[key, default: 0] += 1
            }
            t += 3
        }

        for i in 0..<n {
            let length = simd_length(vertexNormals[i])
            vertexNormals[i] = length > 0.0001 ? vertexNormals[i] / length : SIMD3<Float>(0, 0, 1)
        }

        var roots = [Int32](repeating: 0, count: n)
        var componentSizes = [Int32: Int]()
        for i in 0..<n {
            let root = find(Int32(i))
            roots[i] = root
            componentSizes[root, default: 0] += 1
        }
        let ranked = componentSizes.sorted { $0.value > $1.value }
        guard let firstComponent = ranked.first else { throw AnalysisError.noComponents }
        let secondComponent = ranked.dropFirst().first

        var isBoundary = [Bool](repeating: false, count: n)
        for (key, count) in edgeCounts where count == 1 {
            isBoundary[Int(key >> 32)] = true
            isBoundary[Int(key & 0xFFFF_FFFF)] = true
        }

        let hMin = Double(mn[heightAxis])
        let hMax = Double(mx[heightAxis])
        let dMin = Double(mn[depthAxis])
        let dMax = Double(mx[depthAxis])

        let rawEyes = detectEyeHoles(
            points: (0..<n).filter { roots[$0] == firstComponent.key }.map { positions[$0] },
            widthAxis: widthAxis,
            heightAxis: heightAxis,
            depthAxis: depthAxis,
            meshMin: mn
        )

        var upPositive: Bool
        if let rawEyes {
            upPositive = (rawEyes.centerZ - hMin) < (hMax - rawEyes.centerZ)
        } else {
            let slab = (hMax - hMin) * 0.12
            var lowBoundary = 0
            var highBoundary = 0
            for i in 0..<n where isBoundary[i] {
                let h = Double(positions[i][heightAxis])
                if h < hMin + slab {
                    lowBoundary += 1
                } else if h > hMax - slab {
                    highBoundary += 1
                }
            }
            upPositive = lowBoundary >= highBoundary
        }

        var frontPositive: Bool
        if let rawEyes {
            frontPositive = rawEyes.centerDepth > (dMin + dMax) / 2
        } else {
            var nearLow = 0
            var nearHigh = 0
            for i in 0..<n {
                let h = Double(positions[i][heightAxis])
                let fraction = (h - hMin) / max(hMax - hMin, 1)
                guard fraction > 0.38, fraction < 0.62 else { continue }
                let d = Double(positions[i][depthAxis])
                if d < dMin + 8 { nearLow += 1 }
                if d > dMax - 8 { nearHigh += 1 }
            }
            frontPositive = nearHigh < nearLow
        }

        var canvas: [SIMD3<Float>] = [SIMD3<Float>](repeating: .zero, count: n)
        for i in 0..<n {
            let w = positions[i][widthAxis]
            let d = positions[i][depthAxis] * (frontPositive ? -1 : 1)
            let h = positions[i][heightAxis] * (upPositive ? 1 : -1)
            canvas[i] = SIMD3<Float>(w, d, h)
        }

        var componentMin = [Int32: SIMD3<Float>]()
        var componentMax = [Int32: SIMD3<Float>]()
        for i in 0..<n {
            let root = roots[i]
            if let currentMin = componentMin[root] {
                componentMin[root] = simd_min(currentMin, positions[i])
            } else {
                componentMin[root] = positions[i]
            }
            if let currentMax = componentMax[root] {
                componentMax[root] = simd_max(currentMax, positions[i])
            } else {
                componentMax[root] = positions[i]
            }
        }

        var isInner = [Bool](repeating: false, count: n)
        for i in 0..<n {
            let root = roots[i]
            let center = ((componentMin[root] ?? positions[i]) + (componentMax[root] ?? positions[i])) / 2
            isInner[i] = simd_dot(vertexNormals[i], positions[i] - center) < 0
        }

        var firstRoot = firstComponent.key
        var secondRoot: Int32?
        if let secondComponent {
            var firstMean = SIMD3<Float>(repeating: 0)
            var firstCount = 0
            var secondMean = SIMD3<Float>(repeating: 0)
            var secondCount = 0
            for i in 0..<n {
                if roots[i] == firstComponent.key {
                    firstMean += canvas[i]
                    firstCount += 1
                } else if roots[i] == secondComponent.key {
                    secondMean += canvas[i]
                    secondCount += 1
                }
            }
            if firstCount > 0 { firstMean /= Float(firstCount) }
            if secondCount > 0 { secondMean /= Float(secondCount) }
            if secondMean.y < firstMean.y {
                firstRoot = secondComponent.key
                secondRoot = firstComponent.key
            } else {
                secondRoot = secondComponent.key
            }
        }

        var frontInner: [SIMD3<Float>] = []
        var backInner: [SIMD3<Float>] = []
        for i in 0..<n where isInner[i] {
            if roots[i] == firstRoot {
                frontInner.append(canvas[i])
            } else if let secondRoot, roots[i] == secondRoot {
                backInner.append(canvas[i])
            }
        }

        var allInner = frontInner
        allInner.append(contentsOf: backInner)
        guard !allInner.isEmpty else { throw AnalysisError.noComponents }

        var innerBottomZ = Double.greatestFiniteMagnitude
        var innerTopZ = -Double.greatestFiniteMagnitude
        for p in allInner {
            innerBottomZ = min(innerBottomZ, Double(p.z))
            innerTopZ = max(innerTopZ, Double(p.z))
        }
        let innerHeight = max(innerTopZ - innerBottomZ, 1)
        let zTolerance = max(1.5, innerHeight * 0.007)

        var widthProfile: [ShellAnalysis.ProfilePoint] = []
        var depthProfile: [ShellAnalysis.ProfilePoint] = []

        func widthAt(_ z: Double) -> Double? {
            var minimum = Double.greatestFiniteMagnitude
            var maximum = -Double.greatestFiniteMagnitude
            var count = 0
            for p in frontInner where abs(Double(p.z) - z) < zTolerance {
                minimum = min(minimum, Double(p.x))
                maximum = max(maximum, Double(p.x))
                count += 1
            }
            return count > 4 ? maximum - minimum : nil
        }

        func depthAt(_ z: Double) -> Double? {
            var front = Double.greatestFiniteMagnitude
            var frontCount = 0
            for p in frontInner where abs(Double(p.z) - z) < zTolerance {
                front = min(front, Double(p.y))
                frontCount += 1
            }
            var back = -Double.greatestFiniteMagnitude
            var backCount = 0
            for p in backInner where abs(Double(p.z) - z) < zTolerance {
                back = max(back, Double(p.y))
                backCount += 1
            }
            guard frontCount > 4, backCount > 4 else { return nil }
            return back - front
        }

        for step in 0...20 {
            let fraction = Double(step) / 20.0
            let z = innerBottomZ + innerHeight * fraction
            if let width = widthAt(z) {
                widthProfile.append(.init(z: z, fraction: fraction, value: width))
            }
            if let depth = depthAt(z) {
                depthProfile.append(.init(z: z, fraction: fraction, value: depth))
            }
        }

        let bowl = widthAt(innerBottomZ + innerHeight * 0.225)

        let eyeHoles: ShellAnalysis.EyeHoles? = rawEyes.map { eyes in
            let canonicalCenterZ = eyes.centerZ * (upPositive ? 1 : -1)
            return ShellAnalysis.EyeHoles(
                width: eyes.width,
                height: eyes.height,
                spacing: eyes.spacing,
                aboveInnerBottom: canonicalCenterZ - innerBottomZ
            )
        }

        var outerPoints: [SIMD3<Float>] = []
        for i in 0..<n where !isInner[i] && (roots[i] == firstRoot || roots[i] == secondRoot) {
            outerPoints.append(canvas[i])
        }
        var innerSamples: [SIMD3<Float>] = []
        let stride = max(1, allInner.count / 3000)
        var sampleIndex = 0
        while sampleIndex < allInner.count {
            innerSamples.append(allInner[sampleIndex])
            sampleIndex += stride
        }
        let wall = estimateWallThickness(innerSamples: innerSamples, outerPoints: outerPoints)

        var summaries: [String] = []
        for (index, entry) in ranked.prefix(4).enumerated() where entry.value > 100 {
            let label: String
            if entry.key == firstRoot {
                label = "前脸"
            } else if entry.key == secondRoot {
                label = "后壳"
            } else {
                label = "零件\(index + 1)"
            }
            summaries.append("\(label) \(entry.value) 顶点")
        }

        var notes: [String] = []
        notes.append("由 App 内分析引擎从 OBJ 网格生成")
        if let wall {
            notes.append(String(format: "壁厚实测约 %.1f mm", wall))
        }
        if eyeHoles == nil {
            notes.append("未能识别眼孔，请核对模型朝向")
        }

        return ShellAnalysis(
            name: name,
            sourceFile: sourceFile,
            outerWidth: Double(mx[widthAxis] - mn[widthAxis]),
            outerDepth: Double(mx[depthAxis] - mn[depthAxis]),
            outerHeight: Double(mx[heightAxis] - mn[heightAxis]),
            innerHeight: innerHeight,
            innerBottomZ: innerBottomZ,
            wallThickness: wall,
            widthProfile: widthProfile,
            depthProfile: depthProfile,
            faceBowlWidth: bowl,
            eyeHoles: eyeHoles,
            componentSummaries: summaries,
            notes: notes
        )
    }

    private static func detectEyeHoles(
        points: [SIMD3<Float>],
        widthAxis: Int,
        heightAxis: Int,
        depthAxis: Int,
        meshMin: SIMD3<Float>
    ) -> DetectedEyes? {
        guard !points.isEmpty else { return nil }
        var minX = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var minZ = Double.greatestFiniteMagnitude
        var maxZ = -Double.greatestFiniteMagnitude
        for p in points {
            let x = Double(p[widthAxis])
            let z = Double(p[heightAxis])
            minX = min(minX, x)
            maxX = max(maxX, x)
            minZ = min(minZ, z)
            maxZ = max(maxZ, z)
        }
        guard maxX > minX, maxZ > minZ else { return nil }
        guard (maxX - minX) < 2000, (maxZ - minZ) < 2000 else { return nil }

        let gridWidth = Int((maxX - minX).rounded(.up)) + 3
        let gridHeight = Int((maxZ - minZ).rounded(.up)) + 3
        guard gridWidth > 4, gridHeight > 4, gridWidth * gridHeight < 4_000_000 else { return nil }

        var occupancy = [Bool](repeating: false, count: gridWidth * gridHeight)
        for p in points {
            let x = Int(Double(p[widthAxis]) - minX) + 1
            let z = Int(Double(p[heightAxis]) - minZ) + 1
            guard x >= 0, x < gridWidth, z >= 0, z < gridHeight else { continue }
            occupancy[z * gridWidth + x] = true
        }

        var visited = [Bool](repeating: false, count: gridWidth * gridHeight)
        var holes: [(cells: Int, minX: Int, maxX: Int, minZ: Int, maxZ: Int, centerX: Double, centerZ: Double)] = []

        for startZ in 0..<gridHeight {
            for startX in 0..<gridWidth {
                let start = startZ * gridWidth + startX
                if occupancy[start] || visited[start] { continue }
                var queue = [Int]()
                queue.reserveCapacity(256)
                queue.append(start)
                visited[start] = true
                var head = 0
                var cells = 0
                var minCellX = startX
                var maxCellX = startX
                var minCellZ = startZ
                var maxCellZ = startZ
                var sumX = 0
                var sumZ = 0
                var touchesBorder = false

                while head < queue.count {
                    let cell = queue[head]
                    head += 1
                    let cx = cell % gridWidth
                    let cz = cell / gridWidth
                    cells += 1
                    sumX += cx
                    sumZ += cz
                    minCellX = min(minCellX, cx)
                    maxCellX = max(maxCellX, cx)
                    minCellZ = min(minCellZ, cz)
                    maxCellZ = max(maxCellZ, cz)
                    if cx == 0 || cx == gridWidth - 1 || cz == 0 || cz == gridHeight - 1 {
                        touchesBorder = true
                    }
                    for (dx, dz) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                        let nx = cx + dx
                        let nz = cz + dz
                        guard nx >= 0, nx < gridWidth, nz >= 0, nz < gridHeight else { continue }
                        let next = nz * gridWidth + nx
                        if !occupancy[next], !visited[next] {
                            visited[next] = true
                            queue.append(next)
                        }
                    }
                }

                if !touchesBorder, cells >= 80, cells <= 6000 {
                    holes.append((
                        cells: cells,
                        minX: minCellX,
                        maxX: maxCellX,
                        minZ: minCellZ,
                        maxZ: maxCellZ,
                        centerX: Double(sumX) / Double(cells),
                        centerZ: Double(sumZ) / Double(cells)
                    ))
                }
            }
        }

        guard holes.count >= 2 else { return nil }
        let rankedHoles = holes.sorted { $0.cells > $1.cells }
        let midGridX = Double(gridWidth) / 2
        let first = rankedHoles[0]

        var bestPair: (first: (cells: Int, minX: Int, maxX: Int, minZ: Int, maxZ: Int, centerX: Double, centerZ: Double), second: (cells: Int, minX: Int, maxX: Int, minZ: Int, maxZ: Int, centerX: Double, centerZ: Double))?
        for candidate in rankedHoles.dropFirst() {
            let mirroredX = abs((candidate.centerX - midGridX) + (first.centerX - midGridX))
            let alignedZ = abs(candidate.centerZ - first.centerZ)
            if mirroredX < 18, alignedZ < 18 {
                bestPair = (first, candidate)
                break
            }
        }
        guard let pair = bestPair else { return nil }

        let centerX = (pair.first.centerX + pair.second.centerX) / 2 + minX - 1
        let centerZ = (pair.first.centerZ + pair.second.centerZ) / 2 + minZ - 1
        let spacing = abs(pair.first.centerX - pair.second.centerX)
        let holeWidth = (Double(pair.first.maxX - pair.first.minX) + Double(pair.second.maxX - pair.second.minX)) / 2
        let holeHeight = (Double(pair.first.maxZ - pair.first.minZ) + Double(pair.second.maxZ - pair.second.minZ)) / 2

        var depthSum = 0.0
        var depthCount = 0
        for p in points {
            let x = Int(Double(p[widthAxis]) - minX) + 1
            let z = Int(Double(p[heightAxis]) - minZ) + 1
            guard x >= 0, x < gridWidth, z >= 0, z < gridHeight else { continue }
            let cellX = Double(x)
            let cellZ = Double(z)
            if abs(cellX - pair.first.centerX) < 15, abs(cellZ - pair.first.centerZ) < 15 {
                depthSum += Double(p[depthAxis])
                depthCount += 1
            }
        }
        let centerDepth = depthCount > 0 ? depthSum / Double(depthCount) : Double(meshMin[depthAxis])

        return DetectedEyes(
            centerX: centerX,
            centerZ: centerZ,
            centerDepth: centerDepth,
            width: holeWidth,
            height: holeHeight,
            spacing: spacing
        )
    }

    private static func estimateWallThickness(innerSamples: [SIMD3<Float>], outerPoints: [SIMD3<Float>]) -> Double? {
        guard !innerSamples.isEmpty, !outerPoints.isEmpty else { return nil }
        let cellSize = 6.0
        var grid = [Int64: [Int]]()

        func cellIndex(_ value: Float) -> Int {
            Int(floor(Double(value) / cellSize)) + 100_000
        }

        func key(_ x: Int, _ y: Int, _ z: Int) -> Int64 {
            Int64(x) | Int64(y) << 20 | Int64(z) << 40
        }

        for (index, point) in outerPoints.enumerated() {
            let cell = key(cellIndex(point.x), cellIndex(point.y), cellIndex(point.z))
            grid[cell, default: []].append(index)
        }

        var distances: [Double] = []
        distances.reserveCapacity(innerSamples.count)

        for sample in innerSamples {
            let cx = cellIndex(sample.x)
            let cy = cellIndex(sample.y)
            let cz = cellIndex(sample.z)
            var best = Double.greatestFiniteMagnitude
            for dx in -2...2 {
                for dy in -2...2 {
                    for dz in -2...2 {
                        guard let bucket = grid[key(cx + dx, cy + dy, cz + dz)] else { continue }
                        for index in bucket {
                            let distance = Double(simd_distance(sample, outerPoints[index]))
                            if distance < best { best = distance }
                        }
                    }
                }
            }
            if best < 12 {
                distances.append(best)
            }
        }

        guard distances.count > 50 else { return nil }
        distances.sort()
        return distances[Int(Double(distances.count) * 0.7)]
    }
}
