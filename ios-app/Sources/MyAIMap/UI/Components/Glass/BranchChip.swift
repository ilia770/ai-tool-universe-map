import SwiftUI

/// Canonical category/branch chip — a colored category dot + the category's
/// short name on the shared neutral action-chip chrome. Mirrors how a branch is
/// surfaced today (the category dot + `shortName` pairing seen in `SearchDock`'s
/// result rows and the category rail): the category color accents the dot only,
/// the fill stays neutral. Composes `ActionChipBackground`; adds no styling of
/// its own.
struct BranchChip: View {
    let category: ToolCategory

    var body: some View {
        HStack(spacing: BrandSpacing.s.value) {
            Circle()
                .fill(category.color.swiftUIColor)
                .frame(width: BrandSpacing.s.value, height: BrandSpacing.s.value)
                .shadow(
                    color: category.color.swiftUIColor.opacity(0.10),
                    radius: BrandSpacing.hair.value
                )
            Text(category.shortName)
                .font(BrandTypography.chip)
                .foregroundStyle(BrandColor.textSecondary)
                .lineLimit(1)
        }
        .actionChipBackground()
    }
}
