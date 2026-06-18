import Foundation

struct ToolKnowledge: Equatable, Sendable {
    let useCase: String
    let killerFeatures: [String]
    let strengths: [String]
    let tradeoffs: [String]
    let pricing: String
    let typicalUsers: String

    var searchableText: String {
        ([useCase, pricing, typicalUsers] + killerFeatures + strengths + tradeoffs).joined(separator: " ")
    }
}

enum ToolKnowledgeBook {
    static func knowledge(for tool: Tool) -> ToolKnowledge {
        entries[tool.id] ?? ToolKnowledge(
            useCase: tool.summary,
            killerFeatures: ["Fast intake", "Clear category fit", "Clickable relations"],
            strengths: ["Easy to place in the universe", "Works with the local assistant"],
            tradeoffs: ["Needs a verified website before the app should claim pricing or deep capabilities"],
            pricing: "Unknown pricing model. Verify the live website before purchase.",
            typicalUsers: "Founders, product builders, and operators comparing tools."
        )
    }

    static let entries: [String: ToolKnowledge] = [
        "founder-os": ToolKnowledge(
            useCase: "Central workspace for turning research into plans, builds, approvals, and review loops.",
            killerFeatures: ["Single operating map", "Workflow stage memory", "Agent routing"],
            strengths: ["Keeps tools connected by job-to-be-done", "Good for deciding the next action fast"],
            tradeoffs: ["Only as strong as the tool knowledge and relation hygiene behind it"],
            pricing: "Internal layer. Cost depends on connected model, agent, and storage usage.",
            typicalUsers: "Solo founders, product teams, and AI-native operators."
        ),
        "codex": ToolKnowledge(
            useCase: "Repo-aware implementation, debugging, refactors, tests, and engineering handoff work.",
            killerFeatures: ["Workspace edits", "Test-running loop", "Code review mode"],
            strengths: ["Strong at concrete code changes", "Can verify work inside the local repo"],
            tradeoffs: ["Needs clear repo context and scoped tasks for best results"],
            pricing: "Model/API or subscription based, depending on the host product.",
            typicalUsers: "Engineers, technical founders, and product builders."
        ),
        "claude-code": ToolKnowledge(
            useCase: "Agentic coding, codebase exploration, planning, and multi-step implementation loops.",
            killerFeatures: ["Long-context repo reasoning", "Terminal workflows", "Plan-first agent work"],
            strengths: ["Good at reading large codebases", "Useful for structured engineering tasks"],
            tradeoffs: ["Quality depends on plan discipline and verification coverage"],
            pricing: "Subscription or usage based, depending on Claude plan and environment.",
            typicalUsers: "Engineers, AI app builders, and automation-heavy teams."
        ),
        "cursor": ToolKnowledge(
            useCase: "AI-first IDE for fast edits, navigation, chat with code, and pair-programming flow.",
            killerFeatures: ["Inline edit", "Repo chat", "Composer-style changes"],
            strengths: ["Very fast for local code iteration", "Comfortable for daily IDE use"],
            tradeoffs: ["Large changes still need review and test discipline"],
            pricing: "Freemium/subscription IDE model. Check current plan limits before committing.",
            typicalUsers: "Software engineers, startups, and students."
        ),
        "figma": ToolKnowledge(
            useCase: "Collaborative design canvas, product UI ideation, prototyping, and handoff.",
            killerFeatures: ["Multiplayer canvas", "Components", "Design-to-code workflows"],
            strengths: ["Industry-standard collaboration", "Strong ecosystem and plugins"],
            tradeoffs: ["Can become messy without design-system governance"],
            pricing: "Freemium/team subscription model. Enterprise features usually require paid tiers.",
            typicalUsers: "Designers, PMs, founders, and frontend teams."
        ),
        "dessn": ToolKnowledge(
            useCase: "UI inspiration and design intelligence for faster product direction.",
            killerFeatures: ["Pattern discovery", "Interface references", "Product mood direction"],
            strengths: ["Good for starting visual exploration", "Useful before Figma execution"],
            tradeoffs: ["Inspiration still needs product-specific judgment"],
            pricing: "Subscription-style design intelligence. Verify current access limits on the site.",
            typicalUsers: "Product designers, founders, and frontend builders."
        ),
        "supadata": ToolKnowledge(
            useCase: "Source extraction and data intake for turning public content into usable context.",
            killerFeatures: ["Structured extraction", "API intake", "Research pipeline fit"],
            strengths: ["Good for building knowledge bases", "Pairs well with assistant workflows"],
            tradeoffs: ["Coverage depends on source availability and API constraints"],
            pricing: "Usage/API oriented. Confirm current quotas and rate limits before scaling.",
            typicalUsers: "Researchers, growth teams, and AI app builders."
        ),
        "posthog": ToolKnowledge(
            useCase: "Product analytics, funnels, session replay, feature flags, experiments, and event pipelines.",
            killerFeatures: ["Events and funnels", "Session replay", "Feature flags"],
            strengths: ["Combines analytics and experimentation", "Good fit for product-led teams"],
            tradeoffs: ["Needs clean event taxonomy or insights get noisy"],
            pricing: "Freemium plus usage-based product analytics modules. Check current event/session pricing.",
            typicalUsers: "Product teams, growth teams, startups, and engineers."
        ),
        "supabase": ToolKnowledge(
            useCase: "Fast Postgres-backed backend with auth, storage, realtime APIs, and edge functions.",
            killerFeatures: ["Hosted Postgres", "Auth and storage", "Realtime APIs"],
            strengths: ["Quick database setup", "Open-source roots", "Works well with Vercel"],
            tradeoffs: ["Complex production apps still need schema, RLS, and migration discipline"],
            pricing: "Freemium plus project/resource subscription and usage-based limits.",
            typicalUsers: "Indie hackers, startups, full-stack engineers, and AI app builders."
        ),
        "remotion": ToolKnowledge(
            useCase: "Programmatic video generation with React components and render pipelines.",
            killerFeatures: ["React video composition", "Automation-friendly renders", "Data-driven media"],
            strengths: ["Excellent for repeatable product videos", "Fits engineering-led creative workflows"],
            tradeoffs: ["Video quality depends on motion/design craft, not just code"],
            pricing: "Open-source core with paid/cloud options depending on render workflow.",
            typicalUsers: "Creative engineers, growth teams, and product marketers."
        ),
        "buffer": ToolKnowledge(
            useCase: "Scheduling and publishing content across social channels.",
            killerFeatures: ["Queue scheduling", "Channel publishing", "Approval-friendly workflows"],
            strengths: ["Simple distribution operations", "Good for repeatable launch cadence"],
            tradeoffs: ["Not a product analytics or deep social listening system"],
            pricing: "Freemium/subscription by channel and team size. Verify current limits.",
            typicalUsers: "Creators, marketers, founders, and social teams."
        ),
        "vercel": ToolKnowledge(
            useCase: "Preview deployments, production hosting, and web app delivery infrastructure.",
            killerFeatures: ["Preview URLs", "Edge/runtime platform", "Framework-native deploys"],
            strengths: ["Very fast shipping loop", "Strong Next.js ecosystem fit"],
            tradeoffs: ["Costs can grow with traffic, build minutes, and platform usage"],
            pricing: "Freemium/team subscription plus usage-based infrastructure costs.",
            typicalUsers: "Frontend teams, full-stack startups, and agencies."
        ),
        "agent-skills": ToolKnowledge(
            useCase: "Reusable agent task packs and local operating procedures.",
            killerFeatures: ["Skill reuse", "Task-specific instructions", "Personal knowledge loops"],
            strengths: ["Turns repeated work into repeatable agent behavior", "Easy to version"],
            tradeoffs: ["Bad skills can encode bad habits, so review matters"],
            pricing: "Usually open-source or internal knowledge cost; model usage happens in the agent host.",
            typicalUsers: "Agent builders, operators, and engineering teams."
        ),
        "openswarm": ToolKnowledge(
            useCase: "Multi-agent coordination for routing work across specialized workers.",
            killerFeatures: ["Agent routing", "Task decomposition", "Parallel execution concepts"],
            strengths: ["Useful for complex work queues", "Fits research/build/review pipelines"],
            tradeoffs: ["Coordination overhead can exceed value on small tasks"],
            pricing: "Depends on implementation and connected model usage.",
            typicalUsers: "AI workflow builders and automation-heavy teams."
        ),
    ]
}
