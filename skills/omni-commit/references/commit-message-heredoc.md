# Passing a Commit Message on stdin

Use this form whenever a commit message has a body:

```sh
git commit -F - <<'MSG'
<type>(<scope>): <description>

- First change bullet
- Second change bullet

<footers if any>
MSG
```

## Why not `git commit -m "$(cat <<'EOF' ... EOF)"`

macOS ships bash 3.2, which mis-parses a heredoc nested inside command substitution: it ignores the quoted delimiter and re-parses the body, so any unpaired quote character aborts the command with ``unexpected EOF while looking for matching `'``. An apostrophe in a word like "don't" is the usual trigger.

Piping the heredoc straight to `-F -` has no command substitution, needs no temp file, and passes apostrophes, double quotes, backticks, and `$VAR` through literally.

## Choosing a delimiter

Pick one the body cannot contain. `EOF` is a poor choice for any message that discusses shell scripting: a literal `EOF` line inside the content terminates the heredoc early, so the command receives a silently truncated body and the remainder is parsed as shell. Use something like `MSG` or `PRBODY_9F2A` instead.

The same reasoning applies to any multi-line text passed to a command this way -- PR bodies via `gh pr create -F -`, issue bodies, review comments.
