import SwiftUI
import UIKit

struct UniverseScreen: View {
    @State private var selectedCategory: ToolCategoryId = .core
    @State private var selectedToolId: String = "founder-os"

    private var selectedCategoryModel: ToolCategory {
        UniverseSeed.category(selectedCategory)
    }

    private var visibleTools: [Tool] {
        let tools = UniverseSeed.tools(in: selectedCategory)
        return tools.isEmpty ? UniverseSeed.tools.filter { $0.category == .core } : tools
    }

    private var selectedTool: Tool {
        UniverseSeed.tools.first { $0.id == selectedToolId }
            ?? visibleTools.first
            ?? UniverseSeed.tools[0]
    }

    var body: some View {
        ZStack {
            UniverseView(selectedCategory: selectedCategory, selectedToolId: selectedTool.id)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                categoryRail
                bottomSheet
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onChange(of: selectedCategory) { _, newValue in
            selectedToolId = UniverseSeed.tools(in: newValue).first?.id ?? "founder-os"
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(selectedCategoryModel.color.swiftUIColor.opacity(0.34), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("My AI Map")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Research -> Plan -> Build -> Review")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Text("\(UniverseSeed.tools.count) tools")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UniverseSeed.categories) { category in
                    Button {
                        Haptics.selection()
                        selectedCategory = category.id
                    } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(category.color.swiftUIColor)
                                .frame(width: 8, height: 8)
                            Text(category.shortName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(category.id == selectedCategory ? .white : .white.opacity(0.66))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(category.id == selectedCategory ? category.color.swiftUIColor.opacity(0.64) : .white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var bottomSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 44, height: 4)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedCategoryModel.name.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                    Text(selectedTool.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(selectedTool.summary)
                        .font(.subheadline)
                        .lineSpacing(3)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(stageLabel(selectedTool.stage))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(selectedCategoryModel.color.swiftUIColor, in: Capsule())
            }

            Divider()
                .overlay(.white.opacity(0.14))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleTools) { tool in
                        Button {
                            Haptics.lightTap()
                            selectedToolId = tool.id
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(tool.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(stageLabel(tool.stage))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .frame(width: 132, alignment: .leading)
                            .padding(10)
                            .background(
                                tool.id == selectedToolId
                                    ? selectedCategoryModel.color.swiftUIColor.opacity(0.20)
                                    : Color.white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(tool.id == selectedToolId ? selectedCategoryModel.color.swiftUIColor.opacity(0.52) : .white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 18)
    }

    private func stageLabel(_ stage: WorkflowStageId) -> String {
        switch stage {
        case .research:
            return "Research"
        case .planning:
            return "Plan"
        case .execution:
            return "Build"
        case .approval:
            return "Approve"
        case .review:
            return "Review"
        }
    }
}

#Preview {
    UniverseScreen()
}

private enum Haptics {
    @MainActor
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor
    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
