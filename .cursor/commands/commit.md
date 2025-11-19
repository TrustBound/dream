- add all files to the commit (i.e. `git add .`)
- create a proper conventional commit with the issue number as the scope (i.e. feat(SVC-123): descriptive name of change)
- push the branch to the remote repository
- add all files to the commit (i.e. `git add .`)
- create a conventional commit message for the changes
- if the branch has an issue number, use the issue number (i.e. SVC-123) as the scope

The format of the conventional commit message should be:

```
{scope}: {descriptive name of change}

## Why This Change Was Made
- a full explanation of why the change was made so that a future engineer can understand the reasoning behind the change

## What Was Changed
- a technical explanation of what was changed

## Note to Future Engineer
- explain anything that is not obvious from the changes that may be a gotcha for future engineers
- add some sarcastic humor about the change for the future engineer to enjoy
```