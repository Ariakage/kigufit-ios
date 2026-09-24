import Foundation

nonisolated struct OBJMesh {
    var positions: [Float] = []
    var indices: [Int32] = []
    var groups: [String] = []

    var vertexCount: Int { positions.count / 3 }
    var triangleCount: Int { indices.count / 3 }

    func vertex(_ index: Int) -> SIMD3<Float> {
        SIMD3(positions[index * 3], positions[index * 3 + 1], positions[index * 3 + 2])
    }
}

nonisolated enum OBJParser {
    enum ParseError: Error, LocalizedError {
        case unreadable
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable: return "无法读取 OBJ 文件（编码不支持）"
            case .empty: return "OBJ 文件中没有顶点数据"
            }
        }
    }

    static func parse(data: Data) throws -> OBJMesh {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ParseError.unreadable
        }

        var mesh = OBJMesh()

        func resolve(_ value: Int) -> Int32 {
            value < 0 ? Int32(mesh.vertexCount + value) : Int32(value - 1)
        }

        text.enumerateLines { line, _ in
            guard let first = line.first else { return }

            switch first {
            case "v":
                let second = line.index(after: line.startIndex)
                guard second < line.endIndex, line[second] == " " else { return }
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 4 else { return }
                mesh.positions.append(Float(parts[1]) ?? 0)
                mesh.positions.append(Float(parts[2]) ?? 0)
                mesh.positions.append(Float(parts[3]) ?? 0)

            case "f":
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 4 else { return }
                var face: [Int32] = []
                face.reserveCapacity(parts.count - 1)
                for token in parts.dropFirst() {
                    guard let slash = token.firstIndex(of: "/") else {
                        if let value = Int(token) {
                            face.append(resolve(value))
                        }
                        continue
                    }
                    if let value = Int(token[token.startIndex..<slash]) {
                        face.append(resolve(value))
                    }
                }
                guard face.count >= 3 else { return }
                for k in 1..<(face.count - 1) {
                    mesh.indices.append(face[0])
                    mesh.indices.append(face[k])
                    mesh.indices.append(face[k + 1])
                }

            case "g":
                let name = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    mesh.groups.append(name)
                }

            default:
                break
            }
        }

        guard !mesh.positions.isEmpty, !mesh.indices.isEmpty else {
            throw ParseError.empty
        }
        return mesh
    }
}
