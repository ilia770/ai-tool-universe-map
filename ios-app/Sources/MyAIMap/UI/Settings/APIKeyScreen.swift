import SwiftUI

/// Settings screen where the user pastes their own Anthropic API key.
/// The key is written to the Keychain via `APIKeyStore` and never
/// shown in full — only a masked `sk-ant-…••••` summary.
struct APIKeyScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private var language: AppLanguage { settings.language }

    private let store = APIKeyStore()

    @State private var draft = ""
    @State private var isSet = false
    @State private var showClearConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                keySection
                helpText
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.purple.opacity(0.06)
            }
        }
        .confirmationDialog(
            L10n.delete(language),
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.delete(language), role: .destructive) {
                store.delete()
                draft = ""
                isSet = false
            }
        }
        .onAppear { isSet = store.hasKey }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L10n.apiKey(language))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                BrandHaptics.fire(.light)
                dismiss()
            } label: {
                Text(L10n.done(language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.purple)
            }
            .buttonStyle(PressableButtonStyle(haptic: nil))
        }
    }

    // MARK: - Key section

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status row
            if isSet {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("sk-ant-\u{2026}\u{2022}\u{2022}\u{2022}\u{2022}")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.white.opacity(0.74))
                    Spacer()
                    Button {
                        BrandHaptics.fire(.warning)
                        showClearConfirm = true
                    } label: {
                        Text(L10n.delete(language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(PressableButtonStyle(haptic: nil))
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    strokeStrength: 0.1
                )
            } else {
                // Input row
                VStack(spacing: 0) {
                    SecureField(L10n.apiKey(language), text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.white)
                        .tint(.purple)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)

                    Divider().overlay(.white.opacity(0.1))

                    Button {
                        let trimmed = draft.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        BrandHaptics.fire(.medium)
                        try? store.save(trimmed)
                        draft = ""
                        isSet = true
                    } label: {
                        Text(L10n.save(language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(!draft.trimmingCharacters(in: .whitespaces).isEmpty ? .white : .white.opacity(0.32))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(PressableButtonStyle(haptic: nil, pressedOpacity: 0.9))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    strokeStrength: 0.1
                )
            }
        }
    }

    // MARK: - Help text

    private var helpText: some View {
        Text(L10n.apiKeyHelp(language))
            .font(.caption)
            .foregroundStyle(.white.opacity(0.46))
    }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            APIKeyScreen()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environment(AppSettings())
        }
        .preferredColorScheme(.dark)
}
