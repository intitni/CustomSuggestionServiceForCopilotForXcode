import ComposableArchitecture
import Shared
import STTextView
import STTextViewUI
import SwiftUI

struct TestFieldView: View {
    @Perception.Bindable var store: StoreOf<TestField>

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("Source Code")

                    WithPerceptionTracking {
                        STTextViewUI.TextView(
                            text: $store.text,
                            options: [.wrapLines, .highlightSelectedLine],
                            plugins: [
                                LineNumberPlugin(),
                                StylingPlugin(),
                                ObservationPlugin(store: store),
                            ]
                        )
                        .textViewFont(.monospacedSystemFont(ofSize: 12, weight: .regular))
                    }
                    .frame(height: 300)
                    .padding(4)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.background)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: .init(lineWidth: 1))
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Relevant Code Snippets")

                    WithPerceptionTracking {
                        STTextViewUI.TextView(
                            text: $store.relevantCodeSnippets,
                            options: [.wrapLines, .highlightSelectedLine],
                            plugins: [LineNumberPlugin(), StylingPlugin()]
                        )
                        .textViewFont(.monospacedSystemFont(ofSize: 12, weight: .regular))
                        .frame(height: 300)
                        .padding(4)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.background)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: .init(lineWidth: 1))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            Text("Suggestion")

            TestFieldSuggestionView(store: store)
        }
        .padding(.vertical)
        .onAppear {
            store.send(.appear)
        }
    }
}

struct TestFieldSuggestionView: View {
    @Perception.Bindable var store: StoreOf<TestField>

    var body: some View {
        WithPerceptionTracking {
            HStack(alignment: .top) {
                STTextViewUI.TextView(
                    text: .constant(store.suggestion),
                    options: [.wrapLines, .highlightSelectedLine],
                    plugins: [
                        LineNumberPlugin(),
                        StylingPlugin(),
                        EditingDisabledPlugin(store: store),
                    ]
                )
                .textViewFont(.monospacedSystemFont(ofSize: 12, weight: .regular))

                .frame(height: 300)
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.background)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: .init(lineWidth: 1))
                        .foregroundStyle(.tertiary)
                }

                Form {
                    Section {
                        Button(action: {
                            store.send(.generateSuggestionButtonClicked)
                        }) {
                            Text("Generate Suggestion")
                        }
                    }

                    Section {
                        LabeledContent {
                            Text("\(store.suggestionIndex + 1) of \(store.suggestions.count)")
                        } label: {
                            Text("Suggestion Index")
                        }

                        LabeledContent {
                            Text("\(String(describing: store.suggestionRange))")
                        } label: {
                            Text("Range")
                        }

                        HStack {
                            Button(action: {
                                store.send(.previousSuggestionButtonClicked)
                            }) {
                                Text("Previous")
                            }
                            Button(action: {
                                store.send(.nextSuggestionButtonClicked)
                            }) {
                                Text("Next")
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(width: 250)
            }
        }
    }
}

private struct StylingPlugin: STPlugin {
    func setUp(context: any Context) {
        let textView = context.textView
        let paragraph = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraph.lineHeightMultiple = 1.1
        textView.typingAttributes[.paragraphStyle] = paragraph
    }
}

private struct LineNumberPlugin: STPlugin {
    func setUp(context: any Context) {
        let rulerView = STLineNumberRulerView(textView: context.textView)
        rulerView.highlightSelectedLine = true
        if let scrollView = context.textView.enclosingScrollView {
            scrollView.verticalRulerView = rulerView
            scrollView.rulersVisible = true
        }
    }
}

private class EditingDisabledPlugin: NSObject, STPlugin {
    let store: StoreOf<TestField>
    init(store: StoreOf<TestField>) {
        self.store = store
    }

    func setUp(context: any Context) {
        context.textView.isEditable = false

        observe { [weak textView = context.textView, weak self] in
            guard let textView, let self else { return }
            textView.setAttributedString(.init(self.store.suggestion))
            textView.isEditable = false
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        }
    }
}

private struct ObservationPlugin: STPlugin {
    let store: StoreOf<TestField>

    func setUp(context: any Context) {
        context.events.onDidChangeText { _, _ in
            let code = context.textView.string
            let lines = code.breakLines()
            let selectedRange = context.textView.selectedRange()
            let range = selectedRange.location...(selectedRange.location + selectedRange.length)
            let cursorRange = convertRangeToCursorRange(range, in: lines)
            store.send(.textChanged(context.textView.string, cursorRange.end))
        }
    }
}

#Preview {
    TestFieldView(store: .init(initialState: .init(), reducer: { TestField() }))
        .padding()
}

