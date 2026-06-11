# Git Cheat Sheet

## Goal

Move safely from change to branch to commit to review to rollback.

## Steps

1. Check location: `git status`
2. See history: `git log --oneline --decorate -5`
3. Create branch: `git switch -c feature/devman-practice`
4. Change one file, then inspect: `git diff`
5. Stage and commit: `git add . && git commit -m "Practice workflow"`
6. See remotes: `git remote -v`
7. Practice safe undo: `git revert <commit>`
8. Write the workflow in `workflow-notes.md`

## Done Looks Like

You can explain the difference between `revert`, `reset`, `fetch`, `pull`, and a
pull request.
