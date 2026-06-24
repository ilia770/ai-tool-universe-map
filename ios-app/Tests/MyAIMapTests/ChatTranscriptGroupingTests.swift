import Foundation
import Testing
@testable import MyAIMap

@Suite("ChatTranscriptGrouping — pure day-separator logic")
struct ChatTranscriptGroupingTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// A fixed "now" so the relative labels ("Today"/"Yesterday"/weekday) are
    /// deterministic. Wednesday, 2026-06-17 12:00 UTC.
    private var now: Date {
        DateComponents(
            calendar: calendar, timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 6, day: 17, hour: 12
        ).date!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        DateComponents(
            calendar: calendar, timeZone: TimeZone(identifier: "UTC"),
            year: year, month: month, day: day, hour: hour
        ).date!
    }

    // MARK: - daySeparatorLabel gating

    @Test func firstTurnAlwaysGetsSeparator() {
        let label = ChatTranscriptGrouping.daySeparatorLabel(
            for: now, previous: nil, now: now, calendar: calendar
        )
        #expect(label == "Today")
    }

    @Test func sameDayReturnsNil() {
        let morning = date(2026, 6, 17, hour: 8)
        let afternoon = date(2026, 6, 17, hour: 15)
        let label = ChatTranscriptGrouping.daySeparatorLabel(
            for: afternoon, previous: morning, now: now, calendar: calendar
        )
        #expect(label == nil)
    }

    @Test func differentDayReturnsLabel() {
        let yesterday = date(2026, 6, 16)
        let today = date(2026, 6, 17)
        let label = ChatTranscriptGrouping.daySeparatorLabel(
            for: today, previous: yesterday, now: now, calendar: calendar
        )
        #expect(label == "Today")
    }

    // MARK: - label formatting

    @Test func todayLabel() {
        #expect(ChatTranscriptGrouping.label(for: now, now: now, calendar: calendar) == "Today")
    }

    @Test func yesterdayLabel() {
        let yesterday = date(2026, 6, 16)
        #expect(ChatTranscriptGrouping.label(for: yesterday, now: now, calendar: calendar) == "Yesterday")
    }

    @Test func withinPastWeekUsesWeekday() {
        // 2026-06-13 is a Saturday, 4 days before the Wednesday "now".
        let saturday = date(2026, 6, 13)
        #expect(ChatTranscriptGrouping.label(for: saturday, now: now, calendar: calendar) == "Saturday")
    }

    @Test func olderThanAWeekUsesMediumDate() {
        // 2026-05-01 is well outside the past-week window → medium date style.
        let old = date(2026, 5, 1)
        let label = ChatTranscriptGrouping.label(for: old, now: now, calendar: calendar)
        #expect(label != "Today")
        #expect(label != "Yesterday")
        // Medium style is locale-dependent; assert it is a real, non-weekday string.
        #expect(!label.isEmpty)
        #expect(!["Friday", "Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday"].contains(label))
    }
}
