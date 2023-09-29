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
    private let urlSession: URLSession

    static let url = URL(string: "https://finance.yahoo.com/quote/CART/")!

    private init(calendar: Calendar, formatter: ISO8601DateFormatter, urlSession: URLSession) {
        self.calendar = calendar
        self.formatter = formatter
        self.urlSession = urlSession
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

        let urlSessionConfig = URLSessionConfiguration.default
        urlSessionConfig.urlCache = nil
        urlSessionConfig.urlCredentialStorage = nil
        urlSessionConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlSessionConfig.timeoutIntervalForRequest = 10.0

        let urlSession = URLSession(configuration: urlSessionConfig)

        self.init(calendar: easternStandard, formatter: formatter, urlSession: urlSession)
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

        self.timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] t in
            guard let self = self else {
                t.invalidate()
                return
            }

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

        let t = Timer(fire: wakeTime, interval: 0, repeats: false) { [weak self] t in
            guard let self = self else {
                t.invalidate() // not really necessary as a non-repeating timer, but better safe than sorry!
                return
            }

            self.pause()
            self.resume()
        }

        self.timer = t
        RunLoop.main.add(t, forMode: .default)
    }

    // MARK: Fetching and decoding

    private func runFetchTask() {
        let task = urlSession.dataTask(with: Ticker.url) { [weak self] data, response, error in
            guard let self = self else {
                fatalError("this is a global singleton wtf")
            }

            if let error = error {
                NSLog("Ticker error: \(error)")
                return
            }

            guard let response = response as? HTTPURLResponse else {
                NSLog("Ticker error: expected HTTPURLResponse but got \(response?.className ?? "nil")")
                return
            }

            guard (200...299).contains(response.statusCode) else {
                NSLog("Ticker error: server responded with \(response.statusCode)")
                return
            }

            guard let data = data else {
                NSLog("Ticker error: server responded with nil data")
                return
            }

            guard let text = String(data: data, encoding: .utf8) else {
                NSLog("Ticker error: response text is not utf-8 encoded")
                return
            }

            guard let update = self.parseTickerUpdate(text) else {
                NSLog("Ticker error: incomprehensible output")
                return
            }

            NotificationCenter.default.post(name: .onTickerUpdated, object: update)
        }

        task.resume()
    }

    private func parseTickerUpdate(_ text: String) -> TickerUpdate? {
        var update: TickerUpdate? = nil
        do {
            let doc = try SwiftSoup.parse(text)
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

            update = TickerUpdate(symbol: symbol, price: price ?? "??", delta: delta ?? "", quoteMarketNotice: quoteMarketNotice)
        } catch Exception.Error(let type, let message) {
            NSLog("Ticker error: parsing update failed with type=\(type) message=\(message)")
        } catch {
            NSLog("whoopsies")
        }
        return update
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
