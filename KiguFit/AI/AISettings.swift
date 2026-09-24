import Foundation
import Observation

@MainActor
@Observable
final class AISettings {
    enum Provider: String, CaseIterable, Identifiable {
        case deepseek
        case openai
        case custom

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .deepseek: return "DeepSeek"
            case .openai: return "OpenAI 兼容"
            case .custom: return "自定义"
            }
        }

        var defaultBaseURL: String {
            switch self {
            case .deepseek: return "https://api.deepseek.com/v1"
            case .openai: return "https://api.openai.com/v1"
            case .custom: return ""
            }
        }

        var defaultModel: String {
            switch self {
            case .deepseek: return "deepseek-chat"
            case .openai: return "gpt-4o-mini"
            case .custom: return ""
            }
        }
    }

    var provider: Provider {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider)
        }
    }

    var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: Keys.baseURL)
        }
    }

    var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: Keys.model)
        }
    }

    var apiKey: String {
        didSet {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainStore.delete(Keys.apiKey)
            } else {
                KeychainStore.save(trimmed, for: Keys.apiKey)
            }
        }
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        let defaults = UserDefaults.standard
        let provider = Provider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .deepseek
        self.provider = provider
        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? provider.defaultBaseURL
        self.model = defaults.string(forKey: Keys.model) ?? provider.defaultModel
        self.apiKey = KeychainStore.load(Keys.apiKey) ?? ""
    }

    func applyProviderDefaults() {
        baseURL = provider.defaultBaseURL
        model = provider.defaultModel
    }

    private enum Keys {
        static let provider = "ai.provider"
        static let baseURL = "ai.baseURL"
        static let model = "ai.model"
        static let apiKey = "ai.apiKey"
    }
}
