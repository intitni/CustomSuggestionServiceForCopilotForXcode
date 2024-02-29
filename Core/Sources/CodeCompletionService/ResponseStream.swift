import Foundation

struct ResponseStream<Chunk: Decodable>: AsyncSequence {
    func makeAsyncIterator() -> Stream.AsyncIterator {
        stream.makeAsyncIterator()
    }

    typealias Stream = AsyncThrowingStream<Chunk, Error>
    typealias AsyncIterator = Stream.AsyncIterator
    typealias Element = Chunk

    let stream: Stream

    init(result: URLSession.AsyncBytes) {
        stream = AsyncThrowingStream<Chunk, Error> { continuation in
            let task = Task {
                do {
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        let prefix = "data: "
                        guard line.hasPrefix(prefix),
                              let content = line.dropFirst(prefix.count).data(using: .utf8),
                              let chunk = try? JSONDecoder()
                              .decode(Chunk.self, from: content)
                        else { continue }
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

