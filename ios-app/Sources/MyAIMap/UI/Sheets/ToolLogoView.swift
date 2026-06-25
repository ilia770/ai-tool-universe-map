import SwiftUI
import UIKit

/// Pure logic for the tool logo fallback. Decides the monogram initials
/// from a tool's display name, mirroring the web app's `getToolInitials`
/// (`src/lib/tool-logos.ts`) so iOS and web stay at parity. Kept separate
/// from the view so the decision is unit-testable.
enum ToolMonogram {
    /// Up to three characters used as the logo placeholder.
    /// - A pure all-caps / numeric token (2–4 chars) wins whole, capped at 3
    ///   (e.g. "Founder OS" → "OS").
    /// - Otherwise the first letter of up to two words (e.g. "Claude Code" → "CC").
    /// - Empty / whitespace names fall back to "?".
    static func initials(for name: String) -> String {
        // `/[+/|]/` → space, then drop a `.` only at a word boundary.
        let normalised = name.unicodeScalars.map { scalar -> Character in
            (scalar == "+" || scalar == "/" || scalar == "|") ? " " : Character(scalar)
        }
        let cleaned = stripBoundaryDots(String(normalised))

        let parts = cleaned
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .map(String.init)
            .filter { !$0.isEmpty }

        if let allCaps = parts.first(where: isAllCapsToken) {
            return String(allCaps.prefix(3))
        }

        let initials = parts.prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        return initials.isEmpty ? "?" : initials
    }

    /// Removes a `.` that is followed by whitespace or the end of string,
    /// matching the web regex `/\.(?=\s|$)/g`. Mid-token dots are kept.
    private static func stripBoundaryDots(_ text: String) -> String {
        let chars = Array(text)
        var output = ""
        for (index, char) in chars.enumerated() {
            if char == "." {
                let next = index + 1 < chars.count ? chars[index + 1] : nil
                let atBoundary = next == nil || next == " " || next == "\t" || next == "\n"
                if atBoundary { continue }
            }
            output.append(char)
        }
        return output
    }

    /// `^[A-Z0-9]{2,4}$` — a pure upper-case / digit token of length 2…4.
    private static func isAllCapsToken(_ token: String) -> Bool {
        guard (2...4).contains(token.count) else { return false }
        return token.allSatisfy { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
    }
}

/// Pure logic for the bundled-logo lookup key. Resolves a tool's brand
/// domain the same way the web app does (`getToolLogoDomain`,
/// `src/lib/tool-logos.ts`): an explicit `logoDomain`, then a per-id
/// override, then the host of the tool's `url`. The app is fully local
/// (no logo.dev network fetch), so we only render a logo when the resolved
/// domain has a bundled asset; otherwise the monogram is the fallback.
enum ToolLogoDomain {
    /// Per-id domain overrides, mirroring `logoDomainOverrides` on the web
    /// so id-only tools (e.g. GitHub-hosted skills) resolve to a brand we
    /// bundle. Kept minimal: only ids whose `url` host doesn't already give
    /// the right brand and that we actually ship an asset for.
    static let overrides: [String: String] = [
        "agent-skills": "github.com",
        "api-mega-list": "github.com",
        "deer-flow": "github.com",
        "designer-skills": "github.com",
        "mattpocock-skills": "github.com",
        "openswarm": "github.com",
        "shannon": "github.com",
    ]

    /// Resolved brand domain (e.g. "github.com"), or nil if none applies.
    static func resolve(for tool: Tool) -> String? {
        if let explicit = tool.logoDomain { return explicit }
        if let override = overrides[tool.id] { return override }
        return host(of: tool.url)
    }

    /// Hostname with a leading `www.` stripped, matching the web's
    /// `getDomainFromUrl`.
    static func host(of url: URL?) -> String? {
        guard let host = url?.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Asset-catalog candidate keys, most specific first: the tool id, then
    /// the resolved domain with dots turned into dashes (asset names can't
    /// contain dots), then the raw domain.
    static func assetCandidates(for tool: Tool) -> [String] {
        var keys = [tool.id]
        if let domain = resolve(for: tool) {
            keys.append(domain.replacingOccurrences(of: ".", with: "-"))
            keys.append(domain)
        }
        return keys
    }
}

/// Tool logo for the detail card. Surfaces a bundled brand asset when the
/// tool resolves to a domain we ship (e.g. GitHub), otherwise renders a
/// category-tinted monogram placeholder — never a broken-image box. The app
/// is fully local (no logo.dev network fetch), so the monogram is the
/// graceful fallback the spec requires.
struct ToolLogoView: View {
    let tool: Tool
    let accent: Color
    var size: CGFloat = 56

    private var bundledLogo: UIImage? {
        for candidate in ToolLogoDomain.assetCandidates(for: tool) {
            if let image = UIImage(named: candidate) {
                return image
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.34), Color.black.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)

            if let bundledLogo {
                Image(uiImage: bundledLogo)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
            } else {
                Image(systemName: categorySymbol(for: tool.category))
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.22))
                    .offset(x: size * 0.22, y: size * 0.18)

                Text(ToolMonogram.initials(for: tool.name))
                    .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(tool.name) logo")
    }

    private func categorySymbol(for category: ToolCategoryId) -> String {
        // Custom branches have no bespoke glyph; the neutral "sparkles" mark is
        // the same fallback `.core` uses, so a user-created branch still renders
        // a sensible monogram backdrop.
        CategorySymbol.name(for: category)
    }
}

/// Shared SF Symbol mapping for branch ids, used by tool logos and detail rows.
/// Built-ins map to bespoke glyphs; any custom (user/AI-created) branch falls
/// back to a neutral mark so it never renders a blank icon.
enum CategorySymbol {
    static func name(for category: ToolCategoryId) -> String {
        symbolsByCategory[category] ?? "sparkles"
    }

    private static let symbolsByCategory: [ToolCategoryId: String] = [
        .coding: "chevron.left.forwardslash.chevron.right",
        .design: "paintpalette",
        .research: "doc.text.magnifyingglass",
        .analytics: "chart.xyaxis.line",
        .media: "sparkles.tv",
        .distribution: "paperplane",
        .infrastructure: "server.rack",
        .knowledge: "books.vertical",
        .core: "sparkles",
    ]
}

#Preview {
    HStack(spacing: 16) {
        ToolLogoView(tool: UniverseSeed.tools[1], accent: BrandColor.cyan)
        ToolLogoView(tool: UniverseSeed.tools[0], accent: BrandColor.lime)
    }
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
