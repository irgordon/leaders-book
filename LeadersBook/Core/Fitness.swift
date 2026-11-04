import Foundation

enum AFTEvent: String, CaseIterable, Codable, Sendable, Identifiable {
    case mdl, hrp, sdc, plk, run
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mdl: "Deadlift"
        case .hrp: "Hand-Release Push-Ups"
        case .sdc: "Sprint–Drag–Carry"
        case .plk: "Plank"
        case .run: "Two-Mile Run"
        }
    }
    var isTimed: Bool { self == .sdc || self == .plk || self == .run }
    var unit: String { isTimed ? "m:ss" : self == .mdl ? "lb · 3 repetitions" : "repetitions · 2 minutes" }
    var placeholder: String {
        switch self {
        case .mdl: "150"
        case .hrp: "15"
        case .sdc: "2:28"
        case .plk: "1:30"
        case .run: "19:57"
        }
    }
}

enum AFTStandard: String, CaseIterable, Codable, Sendable, Identifiable {
    case male, female, combat
    var id: String { rawValue }
    var title: String {
        switch self {
        case .male: "General · Male"
        case .female: "General · Female"
        case .combat: "Combat · M|C"
        }
    }
    var minimum: Int { self == .combat ? 350 : 300 }
}

enum FitnessTool: String, Codable, CaseIterable, Sendable {
    case aft = "AFT", ratio = "Waist / height", history = "History"
    var title: String { self == .ratio ? "HT/WT Calculator" : rawValue }
}

struct FitnessDraft: Codable, Equatable, Sendable {
    var standard: AFTStandard = .male
    var ageBand = 0
    var values: [String: String] = [:]
    var height = ""
    var waist = ""
    var metric = false
    var soldierID: UUID?
    var testDate = Date()
    var tool: FitnessTool = .aft

    func value(for event: AFTEvent) -> String { values[event.rawValue, default: ""] }
}

struct AgeBand: Equatable, Sendable {
    static let labels = ["17–21", "22–26", "27–31", "32–36", "37–41", "42–46", "47–51", "52–56", "57–61", "62+"]
    let index: Int
    init(_ index: Int) throws {
        guard (0..<10).contains(index) else { throw RecordError.invalidAgeBand }
        self.index = index
    }
}

enum FitnessInputError: UserPresentableError, Equatable, Sendable {
    case missing(AFTEvent), wholeNumber(AFTEvent), time(AFTEvent), measurement, missingMeasurements
    var userMessage: String {
        switch self {
        case .missing(let event): "Enter a result for \(event.title)."
        case .wholeNumber: "Enter a nonnegative whole number."
        case .time: "Use m:ss, with seconds from 00 to 59 and a positive duration."
        case .measurement: "Use positive, finite measurements in the same units."
        case .missingMeasurements: "Enter both measurements."
        }
    }
}

struct EventPerformance: Equatable, Sendable {
    let event: AFTEvent
    let value: Int
    init(event: AFTEvent, input: String) throws {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FitnessInputError.missing(event) }
        if !event.isTimed {
            guard text.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(text) else {
                throw FitnessInputError.wholeNumber(event)
            }
            self.value = value
        } else {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, (1...2).contains(parts[0].count), parts[1].count == 2,
                  parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
                  let minutes = Int(parts[0]), let seconds = Int(parts[1]), seconds < 60,
                  minutes * 60 + seconds > 0 else { throw FitnessInputError.time(event) }
            value = minutes * 60 + seconds
        }
        self.event = event
    }
}

struct EventPoints: Equatable, Sendable {
    static let minimum = 60
    var meetsMinimum: Bool { value >= Self.minimum }
    var shortfall: Int { max(0, Self.minimum - value) }

    let value: Int
    private init(constant: Int) { value = constant }
    static let zero = EventPoints(constant: 0)
    init(_ value: Int) throws {
        guard (0...100).contains(value) else { throw RecordError.invalidResult }
        self.value = value
    }
}

/// The five required events have distinct storage; no incomplete result can be constructed.
struct FiveEvents<Value: Sendable>: Sendable {
    let mdl: Value, hrp: Value, sdc: Value, plk: Value, run: Value
    init(_ construct: (AFTEvent) throws -> Value) rethrows {
        mdl = try construct(.mdl); hrp = try construct(.hrp); sdc = try construct(.sdc)
        plk = try construct(.plk); run = try construct(.run)
    }
    subscript(_ event: AFTEvent) -> Value {
        switch event { case .mdl: mdl; case .hrp: hrp; case .sdc: sdc; case .plk: plk; case .run: run }
    }
    var array: [Value] { [mdl, hrp, sdc, plk, run] }
}

extension FiveEvents: Equatable where Value: Equatable {}

struct AFTResultDTO: Codable, Sendable {
    var id = UUID()
    var soldierID: UUID?
    var soldierName: String
    var date: Date
    var standard: AFTStandard
    var ageBand: Int
    var values: [String: String]
    var scores: [Int]
    var tableDate: String
    init(_ result: AFTResult) {
        id = result.id; soldierID = result.soldierID; soldierName = result.soldierName; date = result.date
        standard = result.standard; ageBand = result.ageBand; values = result.values
        scores = result.scores; tableDate = result.tableDate
    }
}

struct AFTResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let soldierID: UUID?
    let soldierName: String
    private let recorded: RecordedDate
    let standard: AFTStandard
    private let band: AgeBand
    private let points: FiveEvents<EventPoints>
    let values: [String: String]
    let tableDate: String
    var date: Date { recorded.value }
    var ageBand: Int { band.index }
    var scores: [Int] { points.array.map(\.value) }
    func points(for event: AFTEvent) -> EventPoints { points[event] }
    var total: Int { points.array.reduce(0) { $0 + $1.value } }
    var displayName: String { soldierID == nil ? "Personal Result" : soldierName }
    var failedEvents: [AFTEvent] { AFTEvent.allCases.filter { !points[$0].meetsMinimum } }
    var totalShortfall: Int { max(0, standard.minimum - total) }
    var meetsStandard: Bool { totalShortfall == 0 && failedEvents.isEmpty }
    fileprivate init(id: UUID, draft: FitnessDraft, name: NonemptyText, points: FiveEvents<EventPoints>, band: AgeBand, date: RecordedDate, tableDate: String) {
        self.id = id; soldierID = draft.soldierID; soldierName = name.value; recorded = date
        standard = draft.standard; self.band = band; self.points = points; values = draft.values; self.tableDate = tableDate
    }
    init(dto: AFTResultDTO, scorer: AFTScoring) throws {
        guard dto.tableDate == scorer.tables.effective else { throw RecordError.unsupportedVersion }
        var draft = FitnessDraft()
        draft.soldierID = dto.soldierID; draft.standard = dto.standard; draft.ageBand = dto.ageBand
        draft.values = dto.values; draft.testDate = dto.date
        let computed = try scorer.result(for: draft, soldierName: dto.soldierName, id: dto.id)
        guard dto.scores == computed.scores else { throw RecordError.invalidResult }
        self = computed
    }
}

struct FitnessProfile: Sendable {
    let age: AgeBand
    let date: RecordedDate
}

extension FitnessDraft {
    @discardableResult
    func validateStructure() throws -> FitnessProfile {
        guard values.keys.allSatisfy({ AFTEvent(rawValue: $0) != nil }) else { throw RecordError.invalidDraft }
        return FitnessProfile(age: try AgeBand(ageBand), date: try RecordedDate(testDate))
    }
}

enum EventFieldState: Sendable {
    case empty
    case invalid(FitnessInputError)
    case scored(EventPoints)
}

struct AFTDraftEvaluation: Sendable {
    private enum Phase: Sendable {
        case incomplete(FiveEvents<EventFieldState>)
        case complete(AFTResult)
    }
    private let phase: Phase
    fileprivate init(incomplete fields: FiveEvents<EventFieldState>) { phase = .incomplete(fields) }
    fileprivate init(complete result: AFTResult) { phase = .complete(result) }
    var fields: FiveEvents<EventFieldState> {
        switch phase {
        case .incomplete(let fields): fields
        case .complete(let result): FiveEvents { .scored(result.points(for: $0)) }
        }
    }
    var result: AFTResult? { if case .complete(let result) = phase { result } else { nil } }
}

struct RatioMeasurement: Sendable {
    let value: Double
    init(height: String, waist: String) throws {
        guard !height.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !waist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FitnessInputError.missingMeasurements }
        guard let h = Double(height.replacingOccurrences(of: ",", with: ".")),
              let w = Double(waist.replacingOccurrences(of: ",", with: ".")),
              h.isFinite, w.isFinite, h > 0, w > 0, (w / h).isFinite, w / h > 0 else { throw FitnessInputError.measurement }
        value = w / h
    }
}

enum RatioEvaluation {
    case empty
    case invalid(FitnessInputError)
    case value(Double)
    init(height: String, waist: String) {
        do { self = .value(try RatioMeasurement(height: height, waist: waist).value) }
        catch let error as FitnessInputError {
            if error == .missingMeasurements { self = .empty } else { self = .invalid(error) }
        } catch { preconditionFailure("Unexpected ratio parser error: \(error)") }
    }
}

struct PublishedTablesDTO: Decodable {
    let source: URL, effective: String, sha256: String, ageBands: [String], events: [String: [[Int?]]]
}

struct ScoringTables: Sendable {
    struct Row: Sendable {
        let points: EventPoints
        private let cutoffs: [Int?]
        init(_ raw: [Int?], event: AFTEvent) throws {
            guard raw.count == 21, let points = raw[0] else { throw RecordError.invalidResult }
            self.points = try EventPoints(points)
            let values = Array(raw.dropFirst())
            guard values.allSatisfy({ value in value.map { event.isTimed ? $0 > 0 : $0 >= 0 } ?? true }) else {
                throw RecordError.invalidResult
            }
            cutoffs = values
        }
        func threshold(age: AgeBand, standard: AFTStandard) -> Int? {
            cutoffs[age.index * 2 + (standard == .female ? 1 : 0)]
        }
    }
    let source: URL
    let effective: String
    let ageBands: [String]
    private let events: FiveEvents<[Row]>
    init(dto: PublishedTablesDTO) throws {
        let dateFormat = ISO8601DateFormatter()
        dateFormat.formatOptions = [.withFullDate]
        guard dto.source.scheme == "https", dto.source.host != nil,
              let effective = dateFormat.date(from: dto.effective), dateFormat.string(from: effective) == dto.effective,
              dto.sha256.count == 64, dto.sha256.allSatisfy({ $0.isASCII && $0.isHexDigit }),
              dto.ageBands == AgeBand.labels,
              Set(dto.events.keys) == Set(AFTEvent.allCases.map(\.rawValue)) else { throw RecordError.invalidResult }
        events = try FiveEvents { event in
            guard let raw = dto.events[event.rawValue], !raw.isEmpty else { throw RecordError.invalidResult }
            let rows = try raw.map { try Row($0, event: event) }
            let points = rows.map(\.points.value)
            guard points.first == 100, points.last == 0,
                  zip(points, points.dropFirst()).allSatisfy({ $0 > $1 }) else { throw RecordError.invalidResult }
            return rows
        }
        source = dto.source; self.effective = dto.effective; ageBands = dto.ageBands
    }
    func rows(for event: AFTEvent) -> [Row] { events[event] }
}

struct AFTScoring: Sendable {
    let tables: ScoringTables
    init() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "aft-scales", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        do { tables = try ScoringTables(dto: JSONDecoder().decode(PublishedTablesDTO.self, from: Data(contentsOf: url))) }
        catch { throw AppFailure("Load Scoring Tables", underlying: error) }
    }
    func score(_ performance: EventPerformance, age: AgeBand, standard: AFTStandard) -> EventPoints {
        for row in tables.rows(for: performance.event) {
            guard let cutoff = row.threshold(age: age, standard: standard) else { continue } // Published missing cell.
            let achieved = performance.event == .sdc || performance.event == .run ? performance.value <= cutoff : performance.value >= cutoff
            if achieved { return row.points }
        }
        // The validated table always has a zero row; below its threshold is still a valid zero score.
        return .zero
    }
    func score(_ event: AFTEvent, input: String, ageBand: Int, standard: AFTStandard) throws -> Int {
        score(try EventPerformance(event: event, input: input), age: try AgeBand(ageBand), standard: standard).value
    }
    func result(for draft: FitnessDraft, soldierName: String, id: UUID = UUID()) throws -> AFTResult {
        let profile = try draft.validateStructure()
        let age = profile.age
        let performances = try FiveEvents { try EventPerformance(event: $0, input: draft.value(for: $0)) }
        let points = FiveEvents { score(performances[$0], age: age, standard: draft.standard) }
        return AFTResult(id: id, draft: draft, name: try NonemptyText(soldierName, error: .invalidName),
                         points: points, band: age, date: profile.date, tableDate: tables.effective)
    }
    func evaluate(_ draft: FitnessDraft) throws -> AFTDraftEvaluation {
        let profile = try draft.validateStructure()
        let age = profile.age
        let fields = try FiveEvents { event -> EventFieldState in
            do { return .scored(score(try EventPerformance(event: event, input: draft.value(for: event)), age: age, standard: draft.standard)) }
            catch let error as FitnessInputError {
                if error == .missing(event) { return .empty }
                return .invalid(error)
            }
        }
        if fields.array.allSatisfy({ if case .scored = $0 { true } else { false } }) {
            let points = FiveEvents { event -> EventPoints in
                guard case .scored(let points) = fields[event] else { preconditionFailure("Complete field evaluation lost an event") }
                return points
            }
            return AFTDraftEvaluation(complete: AFTResult(id: UUID(), draft: draft, name: try NonemptyText("Personal Result", error: .invalidName),
                                              points: points, band: age, date: profile.date, tableDate: tables.effective))
        }
        return AFTDraftEvaluation(incomplete: fields)
    }
}
