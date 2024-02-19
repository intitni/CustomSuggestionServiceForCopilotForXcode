import Foundation

public enum CustomModelType: String, CaseIterable {
    case chatModel
    case completionModel
    
    public static var `default`: CustomModelType {
        .completionModel
    }
}
