# GaggiMate release tests

Manual acceptance tests for GaggiMate firmware releases, and the issues that track each test run. Scenarios are
Cucumber/Gherkin in [`features/`](features). They have no step definitions: a tester reads each scenario, performs it
on real hardware and ticks it off in the run's checklist.

Everything here happens **before** a version is published. Publishing a version ships it to every user, and this
workflow never publishes or tags anything. You tell it the version you plan to release (for example `v1.9.0`) and the
firmware commit to test.

## Starting a run

With [`gh`](https://cli.github.com/) logged in and Python 3.9+:

```bash
python3 scripts/create_run.py v1.9.0
```

- `v1.9.0` is the planned version. The script stops if that version is already released on
  [jniebuhr/gaggimate](https://github.com/jniebuhr/gaggimate); it only reads that repository.
- The commit under test defaults to the current `master` of the firmware repository and is pinned by SHA. Use
  `--firmware <branch|sha>` for another one.
- `--dry-run` prints the issues instead of creating them. `--tags @smoke,@critical` creates a reduced run.
- A fix during testing means a new commit: run the script again for the same version to start a new round. It links
  the previous round, and refuses to open a second run for the same commit.

The run issue lists the two builds of the commit under test:

| Build    | Used for                                    | Where it comes from                                                                                                                                                         |
| -------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PR build | USB flashing, functional and hardware tests | `pr-flash.yml` on an open PR whose head is the commit (e.g. `release/v1.9.0` → master); flash it with the PR preview in the web installer. Same build flags as the release. |
| Nightly  | OTA and upgrade tests                       | `build-nightly.yml` on master. Same code plus `NIGHTLY_BUILD`. Devices from v1.4.0 on can switch to the nightly channel and are offered it.                                 |

The script warns if there is no such PR or the nightly is on a different commit. Hold merges to master until the run
is closed, so the nightly stays on the commit under test. `display-headless` is only in the nightly build.

## How a run is organised

| Issue                                     | Labels                                     | Content                                                                                         |
| ----------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `Release test: v1.9.0 · firmware abc1234` | `run`, `release:v1.9.0`                    | Builds, instructions, hardware under test, after-release checks; one sub-issue per feature file |
| `[v1.9.0] 04_brew: Brewing`               | `checklist`, `release:v1.9.0`, `area:brew` | One checkbox per scenario and per example row, with tags and a source link                      |
| `Failure: …`                              | `failure`                                  | One per failed check, from the **Release test failure** issue form                              |

Issues touching `@critical` scenarios also get `critical`. The org's **Release Tests** project board shows them all,
with the fields `Release`, `Area` and `Kind`. Set it up once:

```bash
gh auth refresh -h github.com -s project
python3 scripts/create_run.py --setup-project
```

Then add the views by hand, since GitHub has no API for them: a table grouped by `Release`, a board by `Status`
filtered to `Kind:Checklist`, and a view filtered to `Kind:Failure`. The free plan allows one auto-add workflow; set
it to `label:failure` so failure issues land on the board.

## During a run

1. Fill in the "Hardware under test" table in the run issue.
2. Tick boxes as they pass. Write `skipped: <reason>` after rows you have no hardware for.
3. For a failure, open a **Release test failure** issue here, then append ` → #N` to the checkbox line.
4. If the failure is a product bug, file it on [jniebuhr/gaggimate](https://github.com/jniebuhr/gaggimate/issues) with
   the `release-test` label (plus `critical` for `@critical` scenarios) and link both issues. The repositories have
   different owners, so GitHub cannot transfer issues between them.
5. Close each checklist when it is done. The commit is cleared for release when every `@critical` box is ticked and
   the product bugs found are fixed or accepted.
6. After the version is published, run the "After release" checks in the run issue and close it.

## Minimum release pass

1. Run `pio test -e native` and `scripts/ota_testbench.sh` in the firmware repository on the commit under test. Both
   must be green.
2. On the reference rig (LilyGo T-RGB 2.1" + Pro Rev 1.1 + one scale with an SD card), run every `@smoke` and
   `@critical` scenario.
3. Run `02_upgrade_paths.feature` from **v1.8.1** (display-first and controller-first) and from the **previous
   nightly**.
4. Run the `@matrix` rows for each display panel and controller board that is available, at least one scale per
   panel, and one headless unit.
5. Start the `16_soak.feature` run and leave it going while the rest is tested.

## Features

| File                           | Area                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `00_hardware_matrix.feature`   | Controller PCB detection, display panel detection, headless builds, addons      |
| `01_first_boot.feature`        | Fresh USB install, AP setup, Wi-Fi, Improv, BLE pairing/bonding                 |
| `02_upgrade_paths.feature`     | OTA upgrades from older versions, update order, interrupted updates, downgrades |
| `03_ble_link.feature`          | Display ↔ controller link, protocol mismatch, reconnects, watchdog              |
| `04_brew.feature`              | Brew process, targets, phases, predictive stop, confirmations                   |
| `05_profiles.feature`          | Profile CRUD, import/export, favourites, startup profile, on-device edits       |
| `06_steam_water_flush.feature` | Steam, hot water, flush (timed and hold)                                        |
| `07_grind.feature`             | Grind mode, alt relay, Smart Grind (Tasmota)                                    |
| `08_scales.feature`            | BLE scale drivers × display panels, tare, battery, reconnects                   |
| `09_buttons.feature`           | Physical brew/steam switches, latching vs momentary, combo, custom actions      |
| `10_safety_warnings.feature`   | Thermal runaway, sensor faults, safety caps, warning levels                     |
| `11_integrations.feature`      | HomeKit, mDNS, MQTT, Boiler Fill, Auto-wakeup, LEDs and ToF water level         |
| `12_web_ui.feature`            | Dashboard, profiles editor, history, analyzer, statistics, settings             |
| `13_storage.feature`           | SD vs LittleFS, history pruning, index rebuild, settings export/import          |
| `14_calibration.feature`       | PID autotune, pump flow calibration, pressure calibration, gear pump            |
| `15_network.feature`           | Wi-Fi loss, watchdogs, AP fallback, OTA download resilience                     |
| `16_soak.feature`              | Long-running stability, memory, task health                                     |

Edit scenarios here and commit them before starting a run; checklist source links point at the pushed commit.

## Tags

- `@smoke`: must pass on every run on the reference rig. About 45 minutes.
- `@critical`: safety or data loss. A failure blocks the release.
- `@upgrade`: run once per baseline version (see `02_upgrade_paths.feature`).
- `@matrix`: Scenario Outlines over hardware. Run the rows you have hardware for and mark the others skipped.
- `@pro`: needs a Pro controller (dimming + pressure). `@standard`: needs a Standard controller.
- `@sd`: needs an SD card in the display. `@tof`: needs the Sunrise/Alba LED + ToF board.
- `@nightly`: behaviour only present in `NIGHTLY_BUILD` firmware; left out of release runs.
- `@post-release`: needs the published version; listed under "After release" in the run issue.
- `@known-issue-<id>`: expected to fail today; the tag names the tracking issue. Re-check on every run.

## Glossary

- **RC / commit under test**: the firmware commit planned for release, tested through its PR and nightly builds.
- **Display**: the touchscreen (or headless) ESP32-S3; BLE client; web UI host.
- **Controller**: the PCB driving heater/pump/valve; BLE server.
- **Pro board**: controller with dimming + pressure sensor (Pro Rev 1.0, Pro Rev 1.1, Pro Lego).
- **Standard board**: controller without dimming or pressure (Standard Rev 1.x, 2.x, 3.x).
- **Reference rig**: the bench machine used for `@smoke`.

## Other tools considered

A dedicated test management tool would need a free tier that allows commercial use. [Kiwi TCMS](https://kiwitcms.org/)
is open source and self-hosted, and [gherkin-to-kiwi](https://github.com/opendcs/gherkin-to-kiwi) loads these files
into it. [Testomat.io](https://docs.testomat.io/project/import-export/import/import-tests-from-cucumber/) imports
`*.manual.feature` files, but its free tier allows only 2 users and 2 projects.
