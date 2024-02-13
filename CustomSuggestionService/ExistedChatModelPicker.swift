import Foundation
import Shared
import SwiftUI

struct ExistedChatModelPicker: View {
    @AppStorage(\.chatModels) var chatModels: [ChatModel]
    @AppStorage(\.chatModelId) var chatModelId: String

    var body: some View {
        Picker(
            selection: $chatModelId,
            label: Text("Chat Model"),
            content: {
                Text("Custom Model").tag("")

                ForEach(
                    chatModels,
                    id: \.id
                ) { chatModel in
                    Text(chatModel.name).tag(chatModel.id)
                }
            }
        )
    }
}

