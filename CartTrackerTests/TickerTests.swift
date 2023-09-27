//
//  TickerTests.swift
//  CartTrackerTests
//
//  Created by Ben Bader on 9/26/23.
//

import XCTest
@testable import CartTracker

final class TickerTests : XCTestCase {
    private var tz: TimeZone!
    private var calendar: Calendar!

    override func setUp() {
        tz = TimeZone(identifier: "America/New_York")!
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
    }

    func testNextBusinessDayOnFridayNight() {
        var fridayNightComponents = DateComponents()
        fridayNightComponents.year = 2023
        fridayNightComponents.month = 9
        fridayNightComponents.day = 29
        fridayNightComponents.hour = 20

        var mondayMorningComponents = DateComponents()
        mondayMorningComponents.year = 2023
        mondayMorningComponents.month = 10
        mondayMorningComponents.day = 2
        mondayMorningComponents.hour = 9

        let fridayNight = calendar.date(from: fridayNightComponents)!
        let mondayMorning = calendar.date(from: mondayMorningComponents)!
        let marketOpen = calendar.nextMarketOpenAfter(fridayNight)

        assert(marketOpen == mondayMorning)
    }

    func testNextBusinessDayEarlyMondayMorning() {
        var earlyMorningComponents = DateComponents()
        earlyMorningComponents.year = 2023
        earlyMorningComponents.month = 10
        earlyMorningComponents.day = 2
        earlyMorningComponents.hour = 2

        var mondayMorningComponents = DateComponents()
        mondayMorningComponents.year = 2023
        mondayMorningComponents.month = 10
        mondayMorningComponents.day = 2
        mondayMorningComponents.hour = 9

        let earlyMorning = calendar.date(from: earlyMorningComponents)!
        let mondayMorning = calendar.date(from: mondayMorningComponents)!
        let marketOpen = calendar.nextMarketOpenAfter(earlyMorning)

        assert(marketOpen == mondayMorning)
    }

    func testNextBusinessDayMondayNight() {
        var mondayNightComponents = DateComponents()
        mondayNightComponents.year = 2023
        mondayNightComponents.month = 10
        mondayNightComponents.day = 2
        mondayNightComponents.hour = 20

        var tuesdayMorningComponents = DateComponents()
        tuesdayMorningComponents.year = 2023
        tuesdayMorningComponents.month = 10
        tuesdayMorningComponents.day = 3
        tuesdayMorningComponents.hour = 9

        let mondayNight = calendar.date(from: mondayNightComponents)!
        let tuesdayMorning = calendar.date(from: tuesdayMorningComponents)!
        let marketOpen = calendar.nextMarketOpenAfter(mondayNight)

        assert(marketOpen == tuesdayMorning)
    }
}
