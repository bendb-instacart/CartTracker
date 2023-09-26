//
//  Ticker.swift
//  CartTracker
//
//  Created by Ben Bader on 9/25/23.
//

import Foundation
import CoreData

import SwiftSoup

extension Notification.Name {
    static let onTickerUpdated = Notification.Name("tickerUpdated")
}

struct TickerUpdate : Codable {
    let symbol: String
    let price: String
    let delta: String

    init(symbol: String, price: String, delta: String) {
        self.symbol = symbol
        self.price = price
        self.delta = delta
    }
}

class Ticker {
    private var timer: Timer!

    init() {
        self.timer = nil // make swift stop whining about capturing self before things are initialized
        self.timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { _ in
            Task {
                await self.fetchInBackground()
            }
        }
        self.timer!.fire()
    }

    private func fetchInBackground() async {
        guard let url = URL(string: "https://finance.yahoo.com/quote/CART/") else {
            fatalError("Failed to parse a constant URL, wtf")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let htmlText: String
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("Not an http response???")
                fatalError("lol wut")
            }

            if httpResponse.statusCode != 200 {
                NSLog("http error: \(httpResponse)")
                return
            }

            guard let text = String(data: data, encoding: .utf8) else {
                NSLog("data is not utf-8 encoded")
                return
            }

            htmlText = text
        } catch {
            NSLog("well that didn't work")
            return
        }

        do {
            let doc = try SwiftSoup.parse(htmlText)
            let elements = try doc.select("fin-streamer[data-symbol=CART]").array()

            let symbol = "CART"
            var price: String?
            var delta: String?

            for el in elements {
                guard let attr = try? el.attr("data-field") else {
                    continue
                }

                switch attr {
                case "regularMarketPrice":
                    price = try? el.text(trimAndNormaliseWhitespace: true)
                case "regularMarketChange":
                    delta = try? el.text(trimAndNormaliseWhitespace: true)
                default:
                    continue
                }
            }

            let update = TickerUpdate(symbol: symbol, price: price ?? "??", delta: delta ?? "")
            NotificationCenter.default.post(name: .onTickerUpdated, object: update)
        } catch {
            NSLog("whoopsies")
        }
    }
}
