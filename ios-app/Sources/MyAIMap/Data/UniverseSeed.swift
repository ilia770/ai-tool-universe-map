import Foundation

/// Phase 0 seed data: the eight non-core categories. Phase 1 ports the
/// real `categories` + `tools` arrays from `src/data/ai-tool-universe.ts`
/// (or the JSON migration if D1 lands first).
enum UniverseSeed {
    static let categories: [ToolCategory] = [
        ToolCategory(
            id: .coding,
            name: "Coding",
            shortName: "Coding",
            description: "AI-assisted coding agents and IDE integrations.",
            color: "#5d59ff", glow: "#9b8aff",
            angle: 0
        ),
        ToolCategory(
            id: .design,
            name: "Design",
            shortName: "Design",
            description: "Generative + assistive tooling for visual work.",
            color: "#ec4899", glow: "#f592c7",
            angle: 45
        ),
        ToolCategory(
            id: .research,
            name: "Research",
            shortName: "Research",
            description: "Context gathering and source synthesis.",
            color: "#14b8a6", glow: "#8be7d8",
            angle: 90
        ),
        ToolCategory(
            id: .media,
            name: "Media",
            shortName: "Media",
            description: "Generative image, video, and audio work.",
            color: "#f97316", glow: "#fdba74",
            angle: 135
        ),
        ToolCategory(
            id: .distribution,
            name: "Distribution",
            shortName: "Social",
            description: "Publish, schedule, and amplify content.",
            color: "#22d3ee", glow: "#a5f3fc",
            angle: 180
        ),
        ToolCategory(
            id: .infrastructure,
            name: "Infrastructure",
            shortName: "Runtime",
            description: "Hosting, deploy targets, and runtime glue.",
            color: "#a3e635", glow: "#d9f99d",
            angle: 225
        ),
        ToolCategory(
            id: .knowledge,
            name: "Knowledge",
            shortName: "Skills",
            description: "Personal knowledge + skill stores.",
            color: "#facc15", glow: "#fde68a",
            angle: 270
        ),
        ToolCategory(
            id: .core,
            name: "Founder OS",
            shortName: "Core",
            description: "The central orchestration node every other category orbits.",
            color: "#ffffff", glow: "#ffffff",
            angle: 315
        ),
    ]
}
