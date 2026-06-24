# Git Collaboration Practices

## Working Directory vs Staging vs History

The working directory contains files currently being modified by the developer. The staging area contains changes selected for the next commit. The Git history stores committed snapshots of the repository and provides traceability for all modifications.

## Branching Rules

Feature development should occur in dedicated feature branches created from the develop branch. Direct commits to the main branch are discouraged to protect production stability. Branch names should clearly describe the work being performed.

## Pull Request Expectations

All changes should be submitted through pull requests. Pull requests must be reviewed by another engineer, pass automated CI checks, and include meaningful commit messages before merging.
Small, focused commits make code reviews easier and simplify troubleshooting when issues are discovered later.
