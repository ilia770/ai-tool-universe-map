import Testing
@testable import MyAIMap

@Suite("Pluralize — count labels read naturally")
struct PluralizeTests {
    @Test func zeroUsesPlural() {
        #expect(Pluralize.count(0, "tool") == "0 tools")
        #expect(Pluralize.count(0, "satellite") == "0 satellites")
    }

    @Test func oneUsesSingular() {
        #expect(Pluralize.count(1, "tool") == "1 tool")
        #expect(Pluralize.count(1, "satellite") == "1 satellite")
    }

    @Test func manyUsesPlural() {
        #expect(Pluralize.count(2, "tool") == "2 tools")
        #expect(Pluralize.count(7, "satellite") == "7 satellites")
    }

    @Test func customPluralOverride() {
        #expect(Pluralize.count(1, "entry", "entries") == "1 entry")
        #expect(Pluralize.count(3, "entry", "entries") == "3 entries")
    }
}
