import SwiftUI

/// Lists tools the user has added at runtime and lets them delete or restore
/// recently removed ones. Opened from `SettingsSheet` via a `NavigationLink`.
///
/// Only `userAdded == true` tools appear in the main list; seed tools are
/// invisible here (they cannot be managed as user-added items).
/// The "Recently removed" section surfaces the last handful of soft-deleted
/// tools (any tool, not just user-added) so the user can undo mistakes.
struct ManageToolsScreen: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(AppSettings.self) private var settings

    @State private var pendingDeleteID: String? = nil

    private var language: AppLanguage { settings.language }
    private var tint: Color { model.selectedCategoryModel.color.swiftUIColor }

    /// Tools the user added; these are the primary list content.
    private var userAddedTools: [Tool] {
        model.tools.filter { $0.userAdded }
    }

    /// Tool ids that were recently removed and are still restorable.
    private var recentlyRemovedIDs: [String] {
        model.removedToolIDs.sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                userAddedSection
                if !recentlyRemovedIDs.isEmpty {
                    recentlyRemovedSection
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(L10n.manageTools(language))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            deleteTitle,
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let id = pendingDeleteID {
                Button(deleteLabel, role: .destructive) { confirmDelete(id) }
            }
        }
    }

    // MARK: - User-added section

    private var userAddedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(L10n.manageTools(language))
            if userAddedTools.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(userAddedTools) { tool in
                        toolRow(tool)
                    }
                }
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    tint: tint,
                    strokeStrength: 0.1
                )
            }
        }
    }

    private func toolRow(_ tool: Tool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(tool.summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }
            Spacer()
            if ToolDetailSection.canDelete(toolID: tool.id) {
                Button(role: .destructive) {
                    BrandHaptics.fire(.warning)
                    pendingDeleteID = tool.id
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Color.red.opacity(0.8))
                }
                .buttonStyle(PressableButtonStyle(haptic: nil, pressedOpacity: 0.8))
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "tray")
                .foregroundStyle(.white.opacity(0.3))
            Text(language == .ru ? "Нет добавленных инструментов" : "No added tools")
                .foregroundStyle(.white.opacity(0.46))
        }
        .font(.subheadline)
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            strokeStrength: 0.08
        )
    }

    // MARK: - Recently removed section

    private var recentlyRemovedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(language == .ru ? "Недавно удалено" : "Recently removed")
            VStack(spacing: 0) {
                ForEach(recentlyRemovedIDs, id: \.self) { id in
                    removedRow(id: id)
                }
            }
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                strokeStrength: 0.08
            )
        }
    }

    private func removedRow(id: String) -> some View {
        let name = UniverseSeed.tools.first { $0.id == id }?.name ?? id
        return HStack {
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button {
                BrandHaptics.fire(.light)
                withAnimation(BrandMotion.nudge) {
                    model.restoreTool(id)
                }
            } label: {
                Text(language == .ru ? "Вернуть" : "Restore")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.46))
    }

    private var deleteTitle: String {
        guard let id = pendingDeleteID,
              let name = model.tools.first(where: { $0.id == id })?.name
        else { return language == .ru ? "Удалить инструмент?" : "Delete tool?" }
        return language == .ru ? "Удалить «\(name)»?" : "Delete \"\(name)\"?"
    }

    private var deleteLabel: String {
        language == .ru ? "Удалить" : "Delete"
    }

    private func confirmDelete(_ id: String) {
        guard ToolDetailSection.canDelete(toolID: id) else { return }
        BrandHaptics.fire(.heavy)
        withAnimation(BrandMotion.flow) {
            model.deleteTool(id)
        }
        pendingDeleteID = nil
    }
}

#Preview {
    NavigationStack {
        ManageToolsScreen()
            .environment(UniverseViewModel())
            .environment(AppSettings())
    }
    .preferredColorScheme(.dark)
}
