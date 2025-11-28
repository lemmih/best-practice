# Agent Guidelines

This document contains guidelines for AI agents and developers working on projects in this repository. These guidelines are applicable to all projects.

## Branch Strategy

- Always work in feature branches, never directly on `main` or `master`
- Create a new branch for each feature, bug fix, or improvement
- Use descriptive branch names that reflect the work being done (e.g., `feature/add-login`, `fix/resolve-memory-leak`)

## Pull Requests

- Use the `gh` CLI tool to create pull requests:
  ```bash
  gh pr create --title "Your PR title" --body "Description of changes"
  ```
- Provide clear and descriptive PR titles and descriptions
- Link related issues in the PR description when applicable
- Request reviews from appropriate team members

## Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages.

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code (white-space, formatting, etc.)
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files

### Examples

```
feat: add user authentication
fix: resolve null pointer exception in login handler
docs: update README with installation instructions
refactor(auth): simplify token validation logic
```

## General Best Practices

- Keep changes small and focused
- Write clear, self-documenting code
- Add tests for new functionality when test infrastructure exists
- Update documentation when making changes that affect usage
