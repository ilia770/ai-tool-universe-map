# Evidence bundle — iOS release-readiness

## Existing evidence

| Check | Result | Scope / limitation |
| --- | --- | --- |
| `plutil -lint PrivacyInfo.xcprivacy` | passed again on 2026-07-27 | Syntax only. |
| XcodeGen resource inspection | Fresh generated project contained `PrivacyInfo.xcprivacy` in the file reference and Resources build phase | Generated project is disposable; not an archive. |
| Independent reviews | Spec and code-quality reviews found no Critical, Important, or Minor source finding in `c287268..b238c47` | Advisory only; neither review proves release delivery. |
| Fresh unsigned Release archive | Exit 65; `ibtool` / `actool` lost CoreSimulatorService and then reported no runtime / `iOS 26.5 Platform Not Installed` | A reproducible host blocker. No archive was produced or inspected. |
| Foundation simulator result | 71 passed, 0 failed | Renderer/detail route only; not release delivery or device QA. |
| Security scan at `c287268` | no reportable runtime security finding | Archive/privacy evidence was explicitly deferred; it cannot clear this gate. |

## Evidence still required

- Successful unsigned Release archive resource inspection after a deliberately
  recovered host, or an external Xcode/platform repair decision.
- Signing, TestFlight, App Store privacy-label, policy/support, device,
  accessibility, and performance evidence remain separate release gates.
- Documentation review and `git diff --check` after the evidence and catalog
  plan update.
