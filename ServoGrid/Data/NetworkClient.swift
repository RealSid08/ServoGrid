import Foundation

struct NetworkResponse: Sendable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
}

protocol NetworkClient: Sendable {
    func send(_ request: URLRequest) async throws -> NetworkResponse
}

struct URLSessionNetworkClient: NetworkClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SourceFailure.invalidResponse("The server did not return an HTTP response.")
        }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            result[String(describing: pair.key)] = String(describing: pair.value)
        }
        return NetworkResponse(data: data, statusCode: http.statusCode, headers: headers)
    }
}

