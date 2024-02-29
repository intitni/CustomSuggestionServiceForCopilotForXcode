import Foundation

struct ResponseStream<Chunk: Decodable>: AsyncSequence {
    func makeAsyncIterator() -> Stream.AsyncIterator {
        stream.makeAsyncIterator()
    }

    typealias Stream = AsyncThrowingStream<Chunk, Error>
    typealias AsyncIterator = Stream.AsyncIterator
    typealias Element = Chunk

    let stream: Stream

    init(result: URLSession.AsyncBytes, lineExtractor: @escaping (String) -> String? = { $0 }) {
        stream = AsyncThrowingStream<Chunk, Error> { continuation in
            let task = Task {
                do {
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        guard let content = lineExtractor(line)?.data(using: .utf8)
                        else { continue }
                        let chunk = try JSONDecoder().decode(Chunk.self, from: content)
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                    result.task.cancel()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                result.task.cancel()
            }
        }
    }
}

