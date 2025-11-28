# Agent Guidelines

Universal guidelines for AI agents and developers. This file is used verbatim across multiple projects.

## Branches

- Work in feature branches, never directly on `main` or `master`
- Use descriptive names (e.g., `feature/add-login`, `fix/memory-leak`)

## Pull Requests

- Use `gh pr create --title "Your title" --body "Description"` to open PRs
- PR titles should follow the same Conventional Commits format as commit messages (see below)
- Link related issues when applicable

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`

**Examples:**
```
feat: add user authentication
fix(auth): resolve null pointer in login
docs: update installation guide
```
