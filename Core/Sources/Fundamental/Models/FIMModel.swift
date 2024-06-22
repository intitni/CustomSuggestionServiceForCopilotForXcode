import CodableWrappers
import Foundation

/// A completion model.
public struct FIMModel: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    @FallbackDecoding<EmptyFIMModelFormat>
    public var format: Format
    @FallbackDecoding<EmptyFIMModelInfo>
    public var info: Info

    public init(id: String, name: String, format: Format, info: Info) {
        self.id = id
        self.name = name
        self.format = format
        self.info = info
    }

    public enum Format: String, Codable, Equatable, CaseIterable {
        case mistral
        
        case unknown
    }

    public struct Info: Codable, Equatable {
        @FallbackDecoding<EmptyString>
        public var apiKeyName: String
        @FallbackDecoding<EmptyString>
        public var baseURL: String
        @FallbackDecoding<EmptyBool>
        public var isFullURL: Bool
        @FallbackDecoding<EmptyInt>
        public var maxTokens: Int
        @FallbackDecoding<EmptyString>
        public var modelName: String

        public init(
            apiKeyName: String = "",
            baseURL: String = "",
            isFullURL: Bool = false,
            maxTokens: Int = 4000,
            modelName: String = ""
        ) {
            self.apiKeyName = apiKeyName
            self.baseURL = baseURL
            self.isFullURL = isFullURL
            self.maxTokens = maxTokens
            self.modelName = modelName
        }
    }

    public var endpoint: String {
        switch format {
        case .mistral:
            let baseURL = info.baseURL
            if baseURL.isEmpty { return "https://api.mistral.ai/v1/fim/completions" }
            return "\(baseURL)/v1/fim/completions"
        case .unknown:
            return ""
        }
    }
}

public struct EmptyFIMModelInfo: FallbackValueProvider {
    public static var defaultValue: FIMModel.Info { .init() }
}

public struct EmptyFIMModelFormat: FallbackValueProvider {
    public static var defaultValue: FIMModel.Format { .unknown }
}

