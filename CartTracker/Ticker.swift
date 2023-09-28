//
//  Ticker.swift
//  CartTracker
//
//  Created by Ben Bader on 9/25/23.
//

import Foundation

import SwiftSoup

extension Notification.Name {
    static let onTickerUpdated = Notification.Name("tickerUpdated")
}

struct TickerUpdate : Codable {
    let symbol: String
    let price: String
    let delta: String
    let quoteMarketNotice: String?

    init(symbol: String, price: String, delta: String, quoteMarketNotice: String?) {
        self.symbol = symbol
        self.price = price
        self.delta = delta
        self.quoteMarketNotice = quoteMarketNotice
    }
}

class Ticker {
    private var timer: Timer?
    private let calendar: Calendar
    private let formatter: ISO8601DateFormatter

    static let url = URL(string: "https://finance.yahoo.com/quote/CART/")!

    private init(calendar: Calendar, formatter: ISO8601DateFormatter) {
        self.calendar = calendar
        self.formatter = formatter
    }

    convenience init?() {
        guard let tz = TimeZone(identifier: "America/New_York") else {
            return nil
        }

        var easternStandard = Calendar(identifier: .gregorian)
        easternStandard.timeZone = tz

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = tz
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withSpaceBetweenDateAndTime, .withTime, .withColonSeparatorInTime]

        self.init(calendar: easternStandard, formatter: formatter)
    }

    // MARK: Timer management

    func pause() {
        NSLog("Ticker pausing.")
        self.timer?.invalidate()
        self.timer = nil
    }

    func resume() {
        NSLog("Ticker resuming!")

        let now = Date()
        if calendar.isDateDuringTradingHours(now) {
            resumeDuringTrading()
        } else {
            resumeAfterHours()
        }

        // Even if markets are closed, we should still try to fetch at least _something_
        // to show the user.
        self.runFetchTask()
    }

    private func resumeDuringTrading() {
        NSLog("Markets are open, let's do this")

        self.timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            let now = Date()
            if self.calendar.isDateDuringTradingHours(now) {
                self.runFetchTask()
            } else {
                self.pause()
                self.resume() // NOTE: We're relying on resume _still_ running a fetch task for that last after-hours update.
            }
        }
    }

    private func resumeAfterHours() {
        NSLog("Markets are closed, going to sleep until they re-open")

        let now = Date()
        let wakeTime = calendar.nextMarketOpenAfter(now)
        let wakeTimeText = formatter.string(from: wakeTime)

        NSLog("Wake time will be: \(wakeTimeText)")

        let t = Timer(fire: wakeTime, interval: 0, repeats: false) { _ in
            self.resume()
        }

        self.timer = t
        RunLoop.main.add(t, forMode: .default)
    }

    // MARK: Fetching and decoding

    private func runFetchTask() {
        Task {
            await self.fetchInBackground()
        }
    }

    private func fetchInBackground() async {
        let htmlText: String
        do {
            let (data, response) = try await URLSession.shared.data(from: Ticker.url)
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
            var quoteMarketNotice: String? = nil

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

            if let div = try? doc.getElementById("quote-market-notice") {
                quoteMarketNotice = try? div.text(trimAndNormaliseWhitespace: true)
            }

            let update = TickerUpdate(symbol: symbol, price: price ?? "??", delta: delta ?? "", quoteMarketNotice: quoteMarketNotice)
            NotificationCenter.default.post(name: .onTickerUpdated, object: update)
        } catch {
            NSLog("whoopsies")
        }
    }
}

// MARK: Calendar extensions

extension Calendar {
    /// Returns true if the given timestamp is earlier than 9:00 AM in the current calendar.
    func isDateInMorning(_ date: Date) -> Bool {
        let hour = self.component(.hour, from: date)
        return hour < 9
    }

    /// Returns true if the given timestamp is on or after 4:00 PM in the current calendar.
    func isDateInEvening(_ date: Date) -> Bool {
        let hour = self.component(.hour, from: date)
        return hour > 15
    }

    /// Returns true if the given timestamp falls between 9:00 AM and 4:00 PM
    /// on a weekday in the current calendar.
    func isDateDuringTradingHours(_ date: Date) -> Bool {
        let tooEarly = self.isDateInMorning(date)
        let tooLate = self.isDateInEvening(date)
        let isWeekend = self.isDateInWeekend(date)
        return !tooEarly && !tooLate && !isWeekend
    }

    func nextMarketOpenAfter(_ date: Date) -> Date {
        var oneDay = DateComponents()
        oneDay.day = 1

        var result = self.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        while result < date || self.isDateInWeekend(result) {
            result = self.date(byAdding: oneDay, to: result)!
        }

        return result
    }
}
