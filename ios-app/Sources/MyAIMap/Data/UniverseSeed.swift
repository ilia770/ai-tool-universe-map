import Foundation

/// Phase 0 seed data: the eight non-core categories. Phase 1 ports the
/// real `categories` + `tools` arrays from `src/data/ai-tool-universe.ts`
/// (or the JSON migration if D1 lands first).
enum UniverseSeed {
    static let categories: [ToolCategory] = [
        ToolCategory(
            id: .coding,
            name: "Coding & Agentic Dev",
            shortName: "Coding",
            description: "Editors, coding agents, review systems, app builders, and agentic implementation loops.",
            color: "#6EE7FF", glow: "#9BE8FF",
            angle: -132
        ),
        ToolCategory(
            id: .design,
            name: "Design & Product UI",
            shortName: "Design",
            description: "Interface design, product mockups, design-to-code, prototyping, and visual product systems.",
            color: "#FF8BD2", glow: "#F592C7",
            angle: -82
        ),
        ToolCategory(
            id: .research,
            name: "Research & Data Intake",
            shortName: "Research",
            description: "Research capture, source extraction, web intake, APIs, datasets, and browsing bridges.",
            color: "#7FFFD4", glow: "#8BE7D8",
            angle: -30
        ),
        ToolCategory(
            id: .analytics,
            name: "Analytics & Growth Intelligence",
            shortName: "Analytics",
            description: "Product analytics, event capture, funnels, experimentation, session replay, and growth intelligence.",
            color: "#67E8F9", glow: "#A5F3FC",
            angle: -4
        ),
        ToolCategory(
            id: .media,
            name: "Media & Creative Production",
            shortName: "Media",
            description: "Video, generative media, motion, Remotion pipelines, and creative production systems.",
            color: "#FFD166", glow: "#FDBA74",
            angle: 22
        ),
        ToolCategory(
            id: .distribution,
            name: "Distribution & Social Ops",
            shortName: "Social",
            description: "Publishing, scheduling, social operations, channel packaging, and launch amplification.",
            color: "#9BFF8A", glow: "#D9F99D",
            angle: 74
        ),
        ToolCategory(
            id: .infrastructure,
            name: "Infrastructure & Runtime",
            shortName: "Runtime",
            description: "Deployment, containers, terminals, runtime shells, desktop wrappers, and production rails.",
            color: "#A78BFA", glow: "#C4B5FD",
            angle: 126
        ),
        ToolCategory(
            id: .knowledge,
            name: "Knowledge & Skills",
            shortName: "Skills",
            description: "Agent skill libraries, workflow packs, local knowledge systems, and repeatable capabilities.",
            color: "#F0ABFC", glow: "#F5D0FE",
            angle: 178
        ),
        ToolCategory(
            id: .core,
            name: "AI Operating Core",
            shortName: "Core",
            description: "The central orchestration node every other category orbits.",
            color: "#D8FAFF", glow: "#FFFFFF",
            angle: -178
        ),
    ]

    static let tools: [Tool] = [
        Tool(id: "founder-os", name: "Founder OS", category: .core, summary: "The central operating layer: research, planning, execution, approval, and AI review.", stage: .planning, orbit: .core, angle: 0, url: nil, logoDomain: nil, relationIds: ["codex", "claude-code", "cursor", "figma"], classification: nil),
        Tool(id: "codex", name: "Codex", category: .coding, summary: "Implementation agent for repo work, refactors, testing, and end-to-end engineering tasks.", stage: .execution, orbit: .inner, angle: -142, url: nil, logoDomain: nil, relationIds: ["claude-code", "vercel"], classification: nil),
        Tool(id: "claude-code", name: "Claude Code", category: .coding, summary: "Agentic development partner for codebase investigation, implementation, and review loops.", stage: .execution, orbit: .inner, angle: -128, url: nil, logoDomain: nil, relationIds: ["agent-skills"], classification: nil),
        Tool(id: "cursor", name: "Cursor", category: .coding, summary: "AI-first IDE for fast code edits, project navigation, and pair-programming flow.", stage: .execution, orbit: .middle, angle: -118, url: URL(string: "https://cursor.com/"), logoDomain: "cursor.com", relationIds: ["vscode", "warp"], classification: nil),
        Tool(id: "figma", name: "Figma / Make", category: .design, summary: "Primary collaborative design canvas and product UI ideation space.", stage: .planning, orbit: .inner, angle: -82, url: nil, logoDomain: "figma.com", relationIds: ["paper-design", "framer"], classification: nil),
        Tool(id: "dessn", name: "Dessn.ai", category: .design, summary: "Design intelligence and product interface inspiration for sharper UI direction.", stage: .research, orbit: .middle, angle: -70, url: URL(string: "https://www.dessn.ai/"), logoDomain: "dessn.ai", relationIds: ["figma"], classification: nil),
        Tool(id: "supadata", name: "Supadata", category: .research, summary: "Data intake and extraction layer for turning external sources into usable context.", stage: .research, orbit: .inner, angle: -28, url: URL(string: "https://supadata.ai/"), logoDomain: "supadata.ai", relationIds: ["api-mega-list"], classification: nil),
        Tool(id: "posthog", name: "PostHog", category: .analytics, summary: "Product analytics, session replay, feature flags, experiments, and event pipelines for product teams.", stage: .review, orbit: .inner, angle: -8, url: URL(string: "https://posthog.com/"), logoDomain: "posthog.com", relationIds: ["vercel", "supabase"], classification: Tool.Classification(confidence: 0.92, matchedKeywords: ["analytics", "events", "feature flags", "session replay"], reason: "Product analytics and experimentation belong in Analytics, not social distribution.")),
        Tool(id: "supabase", name: "Supabase", category: .infrastructure, summary: "Open-source backend platform with Postgres database, auth, storage, edge functions, and realtime APIs.", stage: .execution, orbit: .middle, angle: 114, url: URL(string: "https://supabase.com/"), logoDomain: "supabase.com", relationIds: ["vercel", "posthog"], classification: Tool.Classification(confidence: 0.9, matchedKeywords: ["database", "postgres", "backend", "auth"], reason: "A backend/database runtime belongs with infrastructure rails.")),
        Tool(id: "remotion", name: "Remotion", category: .media, summary: "React-powered video generation for programmable launch and product media.", stage: .execution, orbit: .inner, angle: 20, url: URL(string: "https://www.remotion.dev/"), logoDomain: "remotion.dev", relationIds: ["genmedia"], classification: nil),
        Tool(id: "runway", name: "Runway", category: .media, summary: "Creative video generation and editing workspace for fast visual exploration.", stage: .research, orbit: .middle, angle: 9, url: URL(string: "https://runwayml.com/"), logoDomain: "runwayml.com", relationIds: ["remotion"], classification: nil),
        Tool(id: "heygen", name: "HeyGen", category: .media, summary: "Avatar and product video generation for launch assets and explainers.", stage: .planning, orbit: .middle, angle: 33, url: URL(string: "https://www.heygen.com/"), logoDomain: "heygen.com", relationIds: ["remotion"], classification: nil),
        Tool(id: "higgsfield", name: "Higgsfield", category: .media, summary: "Generative motion shots and short-form creative experiments for media production.", stage: .approval, orbit: .outer, angle: 48, url: URL(string: "https://higgsfield.ai/"), logoDomain: "higgsfield.ai", relationIds: ["remotion"], classification: nil),
        Tool(id: "buffer", name: "Buffer", category: .distribution, summary: "Distribution scheduler for shipping content across social channels.", stage: .approval, orbit: .inner, angle: 74, url: URL(string: "https://buffer.com/"), logoDomain: "buffer.com", relationIds: ["distribution-loop"], classification: nil),
        Tool(id: "vercel", name: "Vercel", category: .infrastructure, summary: "Deployment and preview infrastructure for shipping web apps quickly.", stage: .approval, orbit: .inner, angle: 126, url: nil, logoDomain: "vercel.com", relationIds: ["docker"], classification: nil),
        Tool(id: "agent-skills", name: "Agent Skills", category: .knowledge, summary: "Reusable task skills for agents, including public packs and personal knowledge systems.", stage: .planning, orbit: .inner, angle: 178, url: URL(string: "https://github.com/addyosmani/agent-skills"), logoDomain: "github.com", relationIds: ["claude-code"], classification: nil),
        Tool(id: "openswarm", name: "OpenSwarm", category: .core, summary: "Multi-agent coordination layer for routing work across specialized workers.", stage: .execution, orbit: .middle, angle: -190, url: nil, logoDomain: nil, relationIds: ["founder-os"], classification: nil),
    ]

    static func category(_ id: ToolCategoryId) -> ToolCategory {
        categories.first { $0.id == id } ?? categories[0]
    }

    static func tools(in category: ToolCategoryId) -> [Tool] {
        tools.filter { $0.category == category }
    }
}
