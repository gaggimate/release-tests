# GaggiMate release tests

This repository tracks manual release test runs for the GaggiMate firmware. It holds no code or scenarios. The
Gherkin scenarios live in [`docs/release-testing`](https://github.com/jniebuhr/gaggimate/tree/master/docs/release-testing)
in the firmware repository, and the README there explains the minimum release pass.

## How a run is organised

| Issue | Label | Content |
| --- | --- | --- |
| `Release test: vX.Y.Z-rcN` | `run` | Tracking issue: instructions, hardware under test, one sub-issue per feature file |
| `[vX.Y.Z-rcN] 04_brew: Brewing` | `checklist`, `area:brew` | One checkbox per scenario and per example row |
| `Failure: …` | `failure` | One issue per failed check, from the **Release test failure** form |

Every issue of a run also carries `release:vX.Y.Z-rcN`, and anything touching `@critical` scenarios carries `critical`.
The org's **Release Tests** project board shows all of them with the fields `Release`, `Area` and `Kind`.

## Starting a run

From a checkout of the firmware repository, with the release commit checked out and pushed:

```bash
python3 scripts/release_test_issues.py v1.9.0-rc1
```

Useful options: `--dry-run` prints the issues instead of creating them; `--tags @smoke,@critical` creates a reduced run;
`--ref <sha>` takes the scenarios from another commit. The Projects board needs `gh auth refresh -s project` once.

## During a run

1. Fill in the "Hardware under test" table in the run issue.
2. Tick boxes as they pass. Write `skipped: <reason>` after rows you have no hardware for.
3. For a failure, open a **Release test failure** issue here, then append ` → #N` to the checkbox line.
4. If the failure is a product bug, file it on [jniebuhr/gaggimate](https://github.com/jniebuhr/gaggimate/issues) with
   the `release-test` label and link both issues. GitHub cannot transfer issues between different owners.
5. Close each checklist when it is done. The release is ready when every `@critical` box is ticked and the product
   bugs found are fixed or accepted.
