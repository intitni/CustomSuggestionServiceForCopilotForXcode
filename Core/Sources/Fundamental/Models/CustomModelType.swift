import Foundation

public enum CustomModelType: String, CaseIterable {
    case chatModel
    case completionModel
    case tabby
    case fimModel
    
    public static var `default`: CustomModelType {
        .completionModel
    }
}
