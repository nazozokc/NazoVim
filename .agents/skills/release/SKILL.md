---
name: release
description: When creating releases, tagging, or managing version bumps for NazoVim
---

# Release Skill

## When to Use

- When creating a new release of NazoVim
- When bumping the version in flake.nix
- When updating CHANGELOG.md

## Release Procedure

### 1. Update CHANGELOG.md

Add a new section at the top (below the markdownlint comments):

```markdown
## [vX.Y.Z](https://github.com/nazozokc/NazoVim/releases/tag/vX.Y.Z) (YYYY-MM-DD)

### What's Changed

* description of change (#PR_NUMBER)

**Full Changelog**: https://github.com/nazozokc/NazoVim/compare/vPREV...vX.Y.Z
```

### 2. Commit and tag

```bash
git add CHANGELOG.md
git commit -m "chore: release vX.Y.Z"
git tag vX.Y.Z
git push && git push --tags
```

### 3. Automated (via release.yml)

The `release.yml` workflow triggers on tag push and automatically:

- Updates `flake.nix` version field
- Updates `flake.lock`
- Creates GitHub Release with notes from CHANGELOG.md

## Version Bump Rules

| Bump  | When                                         |
| ----- | -------------------------------------------- |
| Patch | Bug fixes, CI updates, dependency bumps      |
| Minor | New features, plugin additions, enhancements |
| Major | Breaking changes, major rewrites             |

## Notes

- Always update CHANGELOG.md before pushing the tag
- The workflow extracts notes from CHANGELOG.md automatically
- flake.nix version is updated by the workflow, not manually
