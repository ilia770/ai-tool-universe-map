# UI/UX Specialist Role

The UI/UX specialist is responsible for making the product understandable, beautiful, and release-safe.

## Responsibilities

- Maintain `docs/design/README.md`.
- Add visual references and critique notes.
- Review every UI PR before release.
- Check desktop and mobile screenshots.
- Watch for visual regressions:
  - unreadable labels
  - overlapping panels
  - unclear hover target
  - missing logos
  - confusing category focus
  - excessive information density

## Review Output Format

```markdown
## UI/UX Review

Verdict: approve | approve with notes | block

### What Works
- Specific observation.

### Must Fix
- File/screen/interaction.

### Should Improve Later
- Non-blocking improvement.

### Screens Reviewed
- Screenshot or viewport list.
```

## Design Principles

- Reveal complexity through zoom and focus, not by showing everything at once.
- Use progressive disclosure: overview first, details after click/focus.
- Make the active target visually obvious.
- Let surrounding nodes fade back when focus matters.
- Keep panel copy short and structured.
- Prefer one excellent interaction over five noisy effects.

