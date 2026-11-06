# Contributing to Gatekeeper's Ward

Thanks for wanting to help. This is a Kiroween 2026 hackathon project, so things move fast — here's the short version.

## Branching

- `main` — stable, always builds
- `dev` — active integration branch
- Feature branches: `feature/<short-name>` (e.g. `feature/hud-overlay`)
- Fix branches: `fix/<short-name>`

Open a PR into `dev`, not `main`.

## Commit Style

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add KERN_PROCARGS2 parser
fix: handle nil process args gracefully
docs: update architecture diagram
chore: update .gitignore
```

## Code Style

- Swift: follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- No force-unwrap (`!`) in production paths — use `guard` or `if let`
- Keep files under 300 lines; extract to new types when things grow
- Every public type/function gets a doc comment

## Testing

Run tests before opening a PR:

```
xcodebuild test -scheme GatekeepersWard -destination 'platform=macOS'
```

## License

By contributing, you agree your contributions are licensed under the [Apache License 2.0](LICENSE).

## Team

- iolaire
- Dharshaneshwaran
