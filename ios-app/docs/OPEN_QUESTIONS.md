# OPEN_QUESTIONS — Evidence gaps requiring a decision or runtime check

These questions do not block documentation. The stated safest assumption is
what future agents should preserve until evidence arrives.

| Question | Why it matters | Where ambiguity appears | Safest assumption now | Evidence needed |
| --- | --- | --- | --- | --- |
| Which renderer is the durable product direction: current 2D constellation or RealityKit Neural Universe? | Defines map architecture, docs, tests, release scope. | Current uncommitted `UniverseConstellation*` vs HEAD/history spatial direction. | Treat current 2D source as working-tree behavior and legacy 3D as dormant; do not delete/revive either. | Explicit product decision plus verified build/device comparison. |
| Is the current 2D cutover meant to ship? | Files/tests are untracked. | `git status`, map composition. | Do not call it release-ready/committed. | Commit/review/CI and simulator evidence. |
| Should the right rail be a product surface? | Existing specs describe it, but it is unmounted and inaccessible. | `UniverseOverlayView`, `RightUniverseRail`, `CategoryRail`. | Treat it as inactive. | Product decision, accessible interaction design, mounted UI test/device QA. |
| Should root Chat return reset map or restore exact context? | Current behavior can surprise users. | `RootShell.showUniverse(resetSelection: true)` versus older navigation promises. | Preserve reset-to-overview behavior. | Explicit UX decision and UI tests. |
| How should compact detail sheet dismissal resolve mode? | Local Boolean and global mode are synchronized. | `UniverseMapView` `onChange` wiring. | Preserve current mode restoration; do not refactor during unrelated work. | Interactive sheet QA on phone/iPad. |
| Is the source-permitted regular-width inspector plus in-map chat layout acceptable? | The inspector derives from selected tool without excluding `chatOpen`, so it is statically permitted and may create overlapping primary surfaces. | `UniverseMapView.inspectorPanel` versus map chat. | Preserve the current source-permitted coexistence; do not promise its visual quality. | iPad simulator/manual layout test. |
| Should chat/activity history persist? | Settings shows history but it is volatile. | model fields vs `UniverseStore`. | Treat both as session-only. | Product privacy/retention decision and storage design. |
| Should app language be functional/persisted? | UI model exposes it but no localization exists. | `AppLanguage`, disabled settings picker. | Do not advertise localization. | Localization scope and assets/strings. |
| Is debug DeepSeek/RelationAI intended to remain? | Network/privacy/release policy is unclear. | `DeepSeekClient`, `RelationAI`, debug gating. | Normal release behavior is local only; do not wire relation AI. | Product/privacy/security decision and integration plan. |
| What is expected on corrupt/migrated persisted data? | Current decode silently defaults. | `UniverseStore`. | Do not change keys/schema without migration. | Data retention/migration policy and fixtures. |
| Do current current-worktree tests/build pass? | Historical counts are not fresh evidence. | dirty renderer/tests and docs records. | Status is unverified for this snapshot. | fresh XcodeGen/xcodebuild/xcresult plus manual smoke. |
| What happens to Keychain data after reinstall? | Determines support/privacy language. | no code/test evidence. | Do not promise survival or deletion. | platform-specific test/explicit product policy. |
