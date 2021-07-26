//
//  PersistenceManager.swift
//  StockClone
//
//  Created by Lawson Kelly on 7/1/21.
//

import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let userDefaults: UserDefaults = .standard

    private struct Constants {
        static let onboardedKey = "hasOnboarded"
        static let watchlistKey = "watchlist"
    }

    private init () {

    }

    public var watchlist: [String] {
        if !hasOnboarded {
            userDefaults.set(true, forKey: Constants.onboardedKey)
            setUpDefaults()
        }
        return userDefaults.stringArray(forKey: Constants.watchlistKey) ?? []
    }

    public func watchListContains(symbol: String) -> Bool {
        return watchlist.contains(symbol)
    }

    public func addToWatchList(symbol: String, companyName: String) {
        var current = watchlist
        current.append(symbol)
        userDefaults.set(current, forKey: Constants.watchlistKey)
        userDefaults.set(companyName, forKey: symbol)

        NotificationCenter.default.post(name: .didAddToWatchList, object: nil)
    }

    public func removeFromWatchList(symbol: String) {
        var newList = [String]()
        userDefaults.set(nil, forKey: symbol)
        for item in watchlist where item != symbol {
            print("\n\(item)")
            newList.append(item)
        }
        userDefaults.set(newList, forKey: Constants.watchlistKey)
    }

    private var hasOnboarded: Bool {
        return userDefaults.bool(forKey: Constants.onboardedKey)
    }

    private func setUpDefaults() {
        let map: [String: String] = [
            "AAPL": "Apple Inc.",
            "SNAP": "Snap Inc.",
            "GOOG": "Alphabet",
            "WORK": "Slack Technologies",
            "AMZN": "Amazon.com Inc.",
            "MSFT": "Microsoft Coroporation",
            "NKE": "Nike",
            "PINS": "Pinterest Inc.",
            "NVDA": "Nvidia Inc.",
            "FB": "Facebook Inc."
        ]

        let symbols = map.keys.map{ $0 }

        userDefaults.set(symbols, forKey: Constants.watchlistKey)

        for (symbol, name) in map {
            userDefaults.set(name, forKey: symbol)
        }
    }
}
