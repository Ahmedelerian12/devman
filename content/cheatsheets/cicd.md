# CI/CD Cheat Sheet

## Goal

Turn build, test, scan, and release steps into an automated pipeline.

## Steps

1. Inspect workflow: `cat .github/workflows/devops-ci.yml`
2. Make scripts runnable locally first.
3. Commit the workflow on a branch.
4. Push and watch checks in GitHub Actions.
5. Fix failures from logs, not guesses.
6. Add a release note or artifact when the pipeline passes.

## Done Looks Like

You can point to the check that proves the change was built and tested.
