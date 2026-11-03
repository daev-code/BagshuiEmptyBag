# Contributing

Issues and pull requests are welcome. All changes go in this addon; the addon it extends is
never modified.

## Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short summary>
```

The usual types are `feat` (new behaviour), `fix` (bug fix), `docs` (README and other docs),
`refactor` (code changes that don't change behaviour) and `chore` (repo setup, tooling).

Pull requests are squash-merged and the PR title becomes the commit message, so please give
the PR a title in the same format, for example `fix: keep the window position after a reload`.

## Testing

There are no automated tests. Try your change in game (`/reload`, or a full relog if you
changed saved settings or the `.toc`) and say in the PR what you tested.
