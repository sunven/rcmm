import Foundation
import RCMMShared

enum UpdateFeedClientError: LocalizedError {
    case badServerResponse(Int)

    var errorDescription: String? {
        switch self {
        case .badServerResponse(let statusCode):
            return "更新 feed 返回了异常状态码：\(statusCode)"
        }
    }
}

struct UpdateFeedClient: Sendable {
    func fetchLatestItem(feedURL: URL) async throws -> DevAppcastItem {
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw UpdateFeedClientError.badServerResponse(httpResponse.statusCode)
        }

        return try DevAppcastParser.latestItem(from: data)
    }
}
