# AGENTS.md — exocortical

## What This Is
Infrastructure tooling — rpush, deploy scripts, shared utilities.

## Rules
- Pull before touching code: `git pull --rebase origin exo`
- Read modified files after pull before editing them
- Don't stomp on siblings' active work — coordinate first
- Commit messages: describe what changed, not why you exist

## Validation
Check script syntax: `bash -n rpush.sh`

## Branch
Default: `exo`
