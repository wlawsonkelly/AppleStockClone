//
//  SearchRespone.swift
//  StockClone
//
//  Created by Lawson Kelly on 7/13/21.
//

import Foundation

struct SearchResponse: Codable {
    let count: Int
    let result: [SearchResult]
}

struct SearchResult: Codable {
    let description: String
    let displaySymbol: String
    let symbol: String
    let type: String
}
