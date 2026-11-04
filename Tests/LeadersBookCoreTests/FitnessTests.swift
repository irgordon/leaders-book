import Foundation
import Testing
@testable import LeadersBookCore

struct FitnessTests {
    @Test func eventStatusBoundaries() throws {
        for score in [0, 59, 60, 100] {
            let points = try EventPoints(score)
            #expect(points.meetsMinimum == (score >= 60))
            #expect(points.shortfall == max(0, 60 - score))
        }
        let scorer = try AFTScoring()
        var draft = FitnessDraft()
        draft.values = ["mdl": "0", "hrp": "58", "sdc": "1:00", "plk": "5:00", "run": "10:00"]
        let result = try scorer.result(for: draft, soldierName: "Test Soldier")
        #expect(result.total >= draft.standard.minimum)
        #expect(result.failedEvents == [.mdl])
        #expect(!result.meetsStandard)
        #expect(result.totalShortfall == 0)
        draft.standard = .combat
        for event in AFTEvent.allCases {
            let row = try #require(scorer.tables.rows(for: event).first { $0.points.value == 60 })
            let threshold = try #require(row.threshold(age: AgeBand(0), standard: .combat))
            draft.values[event.rawValue] = event.isTimed ? String(format: "%d:%02d", threshold / 60, threshold % 60) : String(threshold)
        }
        let combat = try scorer.result(for: draft, soldierName: "Test Soldier")
        #expect(combat.failedEvents.isEmpty)
        #expect(combat.total == 300)
        #expect(combat.totalShortfall == 50)
        #expect(!combat.meetsStandard)
    }

    @Test func parserRejectsMalformedAndNonfiniteInput() throws {
        for text in ["", "1.5", "-1", "abc", "9999999999999999999999", "١٢"] {
            #expect(throws: FitnessInputError.self) { try EventPerformance(event: .mdl, input: text) }
        }
        for text in ["20:60", "0:00", "1:2", "-1:30", "1:30:00", "NaN", "100:00"] {
            #expect(throws: FitnessInputError.self) { try EventPerformance(event: .run, input: text) }
        }
        #expect(try EventPerformance(event: .run, input: " 20:00 ").value == 1200)
        #expect(try EventPerformance(event: .hrp, input: "0").value == 0)
    }

    @Test func publishedBoundaryFixtures() throws {
        let scorer = try AFTScoring()
        // Official June 2025 score table, age 17–21 M|C and F columns.
        #expect(try scorer.score(.mdl, input: "340", ageBand: 0, standard: .male) == 100)
        // The 99-point M|C cell is blank; 330 lb earns the published 98 points.
        #expect(try scorer.score(.mdl, input: "330", ageBand: 0, standard: .male) == 98)
        #expect(try scorer.score(.mdl, input: "220", ageBand: 0, standard: .female) == 100)
        #expect(try scorer.score(.hrp, input: "58", ageBand: 0, standard: .male) == 100)
        #expect(try scorer.score(.mdl, input: "0", ageBand: 0, standard: .male) == 0)
        #expect(try scorer.score(.run, input: "99:59", ageBand: 0, standard: .male) == 0)
        #expect(throws: RecordError.invalidAgeBand) { try scorer.score(.mdl, input: "340", ageBand: -1, standard: .male) }
    }

    @Test func everyPublishedThresholdAndCombatColumn() throws {
        let scorer = try AFTScoring()
        for event in AFTEvent.allCases {
            let rows = scorer.tables.rows(for: event)
            #expect(rows.map { $0.points.value } == rows.map { $0.points.value }.sorted(by: >))
            for age in scorer.tables.ageBands.indices {
                for standard in [AFTStandard.male, .female, .combat] {
                    for row in rows {
                        guard let threshold = row.threshold(age: try AgeBand(age), standard: standard) else { continue }
                        let points = row.points.value
                        let input = event.isTimed ? String(format: "%d:%02d", threshold / 60, threshold % 60) : String(threshold)
                        let score = try scorer.score(event, input: input, ageBand: age, standard: standard)
                        #expect(score >= points)
                        if standard == .combat {
                            #expect(score == (try scorer.score(event, input: input, ageBand: age, standard: .male)))
                        }
                    }
                }
            }
        }
    }

    @Test func completeResultsRequireEveryEventAndEveryMinimum() throws {
        let scorer = try AFTScoring()
        var draft = FitnessDraft()
        #expect(throws: FitnessInputError.missing(.mdl)) { try scorer.result(for: draft, soldierName: "Test") }
        draft.values = ["mdl": "340", "hrp": "58", "sdc": "1:00", "plk": "5:00", "run": "10:00"]
        let result = try scorer.result(for: draft, soldierName: "Test")
        #expect(result.total == 500)
        #expect(result.meetsStandard)
        draft.values["mdl"] = "0"
        let failedEvent = try scorer.result(for: draft, soldierName: "Test")
        #expect(failedEvent.total == 400)
        #expect(!failedEvent.meetsStandard)
        draft.standard = .combat
        #expect(try scorer.result(for: draft, soldierName: "Test").standard.minimum == 350)
    }

    @Test func waistRatioUsesMatchingUnitsAndRejectsBadMeasurements() throws {
        #expect(try RatioMeasurement(height: "70", waist: "35").value == 0.5)
        #expect(try RatioMeasurement(height: "177.8", waist: "88.9").value == 0.5)
        #expect(try RatioMeasurement(height: "177,8", waist: "88,9").value == 0.5)
        for text in ["", "0", "-2", "NaN", "inf", "1e999"] {
            #expect(throws: FitnessInputError.self) { try RatioMeasurement(height: text, waist: "35") }
            #expect(throws: FitnessInputError.self) { try RatioMeasurement(height: "70", waist: text) }
        }
    }
}
