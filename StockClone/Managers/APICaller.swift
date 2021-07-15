//
//  APICaller.swift
//  StockClone
//
//  Created by Lawson Kelly on 7/1/21.
//

import Foundation

final class APICaller {
    static let shared = APICaller()

    private struct Constants {
        static let apiKey = "c3n2v4iad3ieepc43140"
        static let sandboxApiKey = "sandbox_c3n2v4iad3ieepc4314g"
        static let baseUrl = "https://finnhub.io/api/v1/"
    }

    private init() {}

    public func news
    (for type: NewsViewController.`Type`,
     completion: @escaping (Result<[NewsStory], Error>) -> Void
    ) {
        switch type {
        case .topStories:
            request(
                url: url(
                    for: .topStories,
                    queryParams: ["category":"general"]
                ),
                expecting: [NewsStory].self,
                completion: completion
            )
        case .company(let symbol):
            let today = Date()
            let oneWeekBack = today.addingTimeInterval(-(60 * 60 * 24 * 7))
            request(
                url: url(
                    for: .companyNews,
                    queryParams: [
                        "symbol": symbol,
                        "from": DateFormatter.newsDateFormatter.string(from: oneWeekBack),
                        "to": DateFormatter.newsDateFormatter.string(from: today)
                    ]
                ),
                expecting: [NewsStory].self,
                completion: completion
            )
        }
    }

    public func search
    (query: String,
     completion: @escaping (Result<SearchResponse, Error>) -> Void
    ) {
        guard let safeQuery = query.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
        )
        else {
            return
        }
        request(url: url(
            for: .search,
            queryParams: ["q":safeQuery]
        ),
        expecting: SearchResponse.self,
        completion: completion
        )
    }

    public func marketData(
        for symbol: String,
        numberOfDays: TimeInterval = 7,
        completion: @escaping (Result<MarketDataResponse, Error>) -> Void
    ) {
        let today = Date()
        let prior = today.addingTimeInterval(-(60 * 60 * 24 * numberOfDays))
        let url = url(
            for: .marketData,
            queryParams: [
                "symbol": symbol,
                "resolution": "1",
                "from": "\(Int(prior.timeIntervalSince1970))",
                "to": "\(Int(today.timeIntervalSince1970))"
            ]
        )
        request(
            url: url,
            expecting: MarketDataResponse.self,
            completion: completion
        )
    }

    private enum Endpoint: String {
        case search
        case topStories = "news"
        case companyNews = "company-news"
        case marketData = "stock/candle"
    }

    private enum APIError: Error {
        case noDataReturned
        case invalidURL
    }

    private func url(
        for endpoint: Endpoint,
        queryParams: [String: String] = [:]
    ) -> URL? {
        var urlString = Constants.baseUrl + endpoint.rawValue
        var queryItems = [URLQueryItem]()
        for (name, value) in queryParams {
            queryItems.append(.init(name: name, value: value))
        }
        queryItems.append(.init(name: "token", value: Constants.apiKey))

        urlString += "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")

        return URL(string: urlString)
    }

    private func request<T: Codable>(
        url: URL?,
        expecting: T.Type,
        completion: @escaping ((Result<T, Error>) -> Void)
    ) {
        guard let url = url else {
            completion(.failure(APIError.invalidURL))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in

            guard let data = data, error == nil else {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(APIError.noDataReturned))
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(expecting, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
