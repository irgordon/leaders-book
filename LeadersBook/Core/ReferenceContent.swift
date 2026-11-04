import Foundation

struct ArmyGuide: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let paragraphs: [String]
    let practice: String
}

struct TroopStep: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let summary: String
    let action: String
}

struct ArmyResource: Identifiable, Sendable {
    let id: String
    let subtitle: String
    let symbol: String
    let url: URL
}

enum ReferenceContent {
    static let publishingURL = URL(string: "https://armypubs.army.mil/")!
    static let bodyCompositionURL = URL(string: "https://www.armyresilience.army.mil/abcp/")!

    static let guides: [ArmyGuide] = [
        ArmyGuide(id: "ADP 6-22", title: "Army Leadership", paragraphs: [
            "Army leadership influences people through purpose, direction, and motivation. Explain why a task matters, set a clear standard, and check that soldiers understand what success looks like.",
            "Develop character, presence, and intellect alongside the competencies of leading, developing, and achieving. Build trust through consistent decisions, set the example in routine work, and give specific feedback with a practical next step."
        ], practice: "Before assigning a task, state its purpose, the standard, and the time available."),
        ArmyGuide(id: "TC 7-22.7", title: "The NCO Guide", paragraphs: [
            "NCOs connect individual development with unit readiness. Know your soldiers, communicate standards, and make time for counseling, training, and professional development.",
            "Make counseling a conversation. Discuss performance, agree on an achievable plan, and set a follow-up date. Protect personal information and use approved channels for medical, family, and administrative concerns."
        ], practice: "Agree on one development goal and a date to review progress."),
        ArmyGuide(id: "FM 7-22", title: "Holistic Health and Fitness", paragraphs: [
            "Holistic Health and Fitness addresses physical, nutritional, mental, spiritual, and sleep readiness. A test score is one indicator. Plan training around the mission, current ability, recovery, and available professional support.",
            "Use progressive training rather than repeated maximum-effort testing. Encourage sound sleep and fueling habits, watch for injury, and refer concerns to qualified personnel. Use current Army instructions for test execution and scoring."
        ], practice: "Review workload and recovery needs before adding another hard training session.")
    ]

    static let troopSteps: [TroopStep] = [
        TroopStep(id: 1, title: "Receive the Mission", summary: "Understand the task, purpose, higher commander’s intent, and time available. Identify what is known and what is missing.", action: "Build a backward timeline. Preserve preparation time for subordinate leaders."),
        TroopStep(id: 2, title: "Issue a Warning Order", summary: "Give soldiers early notice while planning continues. Share the situation, mission, timeline, and initial instructions.", action: "Update the warning order as information changes. Distinguish confirmed information from tentative details."),
        TroopStep(id: 3, title: "Make a Tentative Plan", summary: "Analyze the mission and develop a course of action. Consider enemy, terrain and weather, troops and support, time, and civil considerations.", action: "Assign responsibilities, identify coordination needs, and check assumptions and risks."),
        TroopStep(id: 4, title: "Initiate Movement", summary: "Begin necessary preparations or movement without waiting for every planning detail to be finished.", action: "Give clear instructions and supervision. Keep early movement consistent with higher guidance."),
        TroopStep(id: 5, title: "Conduct Reconnaissance", summary: "Gather information to confirm the tentative plan and reduce uncertainty, using observation, maps, reports, and coordination as appropriate.", action: "Compare findings against assumptions. Report changes and revise the plan when needed."),
        TroopStep(id: 6, title: "Complete the Plan", summary: "Refine the course of action using reconnaissance and updated information. Confirm tasks, resources, timing, communications, and contingencies.", action: "Resolve conflicts, close information gaps, and explain changes to subordinates."),
        TroopStep(id: 7, title: "Issue the Order", summary: "Communicate the plan clearly using situation, mission, execution, sustainment, and command and signal.", action: "Have subordinate leaders explain their tasks, timing, and coordination points back to you."),
        TroopStep(id: 8, title: "Supervise and Refine", summary: "Inspect preparations and conduct rehearsals. Supervision continues during planning and execution; new information can require revisiting an earlier step.", action: "Check understanding, equipment, and readiness. Use rehearsal feedback to improve the plan.")
    ]

    static let resources: [ArmyResource] = [
        ArmyResource(id: "IPPS-A", subtitle: "Personnel and pay", symbol: "person.text.rectangle", url: URL(string: "https://ipps-a.army.mil/")!),
        ArmyResource(id: "Army Publications", subtitle: "Official doctrine, regulations, and forms", symbol: "books.vertical", url: publishingURL),
        ArmyResource(id: "Army Fitness Test", subtitle: "Official event procedures and scoring resources", symbol: "figure.run", url: URL(string: "https://www.army.mil/aft/")!),
        ArmyResource(id: "Army Body Composition Program", subtitle: "Current body composition resources", symbol: "ruler", url: bodyCompositionURL),
        ArmyResource(id: "Teams", subtitle: "Department of Defense collaboration", symbol: "bubble.left.and.bubble.right", url: URL(string: "https://dod.teams.microsoft.us/")!),
        ArmyResource(id: "Army Email", subtitle: "Open your inbox", symbol: "envelope", url: URL(string: "https://webmail.apps.mil/")!)
    ]
}
