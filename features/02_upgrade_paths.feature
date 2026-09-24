@upgrade
Feature: Upgrading from older versions
  Users arrive from many versions, update display and controller in either order, and get interrupted
  halfway. Every path must end in a working, paired machine, and any data loss must be the documented kind.

  Facts that drive these scenarios:
  - Display OTA downloads from GitHub. "Update both" always flashes the controller first (streamed over BLE), then the display.
  - The protocol changed to framed nanopb after v1.8.1 (PROTOCOL_VERSION 5 today). The display detects legacy controllers (protocol 0)
    and any version mismatch, blocks brewing, and allows OTA only.
  - v1.8.1 and older OTA also write display-filesystem.bin. The data partition changed from SPIFFS to LittleFS, so profiles
    and shots on internal flash are replaced by the seed profiles. Data on an SD card survives.
  - Since GM-106 the web UI is embedded in the app image and OTA never touches the filesystem.
  - The controller now bonds to one display. A display that cannot encrypt is disconnected.
  - "RC" is the master commit planned for release. Tagging master publishes it to every user, so everything here
    runs before, on the nightly of that commit (same code plus NIGHTLY_BUILD), fetched over the nightly channel.
    Baselines from v1.4.0 on can switch to the nightly channel; their OTA compare ranks v1.8.1-208-gX above v1.8.1.

  # ---------------------------------------------------------------- Baselines

  # Prepare every baseline the same way:
  #  1. USB-flash display + controller with the baseline using the web installer; erase NVS.
  #  2. Configure Wi-Fi, set non-default values in every settings group (temps, PID, warnings, buttons, LED colours,
  #     MQTT, Smart Grind IP, auto-wakeup, timezone, brightness, theme, startup profile), pair a scale.
  #  3. Create 3 custom profiles (1 simple, 1 pro with weight stop, 1 with non-ASCII name "Café ☕ Ristretto").
  #     Favourite and reorder them. Select a custom profile.
  #  4. Pull 5 shots (1 with a scale, 1 under 7.5 s which must not be saved) and add notes/ratings to 2 of them.
  #  5. Export settings JSON and "Export all" profiles from the web UI and keep the files.
  #  6. Screenshot the Settings pages and the history list.

  Scenario Outline: Baseline catalogue
    Given baseline "<version>"
    Then I prepare it as described above
    And I record which of the upgrade scenarios below apply: <notes>

    Examples:
      | version               | notes                                                                    |
      | v1.8.1                | main stable baseline: legacy BLE, SPIFFS, old OTA writes filesystem      |
      | v1.8.0                | same as v1.8.1 path, older settings keys                                 |
      | v1.7.3                | first binary shot log (v5) and SD support                                |
      | v1.6.x                | CSV shot history (discarded by v1.7+), headless introduced               |
      | v1.5.x                | settings/profile export introduced                                       |
      | v1.4.0                | first release where display OTA can update the controller                |
      | v1.3.x or older       | controller cannot be OTA-updated from display; USB path only              |
      | previous nightly      | protocol N-1 or equal, LittleFS, embedded web UI                          |
      | nightly 2026-06-03..13 | LittleFS but web UI still in /w on the filesystem (stale files)          |
      | "db" pre-release      | mid-migration protocol version                                           |

  # ---------------------------------------------------------------- Main path: v1.8.x

  @critical @smoke
  Scenario Outline: v1.8.x → RC using the baseline's own "update both" OTA
    Given display and controller on "<from>" prepared as a baseline
    And <storage>
    And the OTA channel is switched to "nightly" and the nightly release is the RC commit
    When I start the update from the baseline web UI and update both
    Then the controller is flashed first and reboots into the RC
    And the display is flashed next and reboots into the RC
    And the display and controller reconnect, bond, and the system reaches Standby with no "Version mismatch"
    And the System tab shows the RC version for both
    And all settings in every group match the pre-upgrade screenshots
    And the settings that are new since the baseline show their defaults (flush duration 5 s, button mapping brew/steam/water, warning levels)
    And the AP now requires the generated password (shown on the Info screen)
    And profiles and shot history are <data_result>
    And the saved scale reconnects when leaving Standby
    And a brew with a custom profile completes and is recorded in history

    Examples:
      | from   | storage                     | data_result                                                           |
      | v1.8.1 | no SD card is inserted      | replaced by seed profiles and an empty history (documented data loss) |
      | v1.8.1 | an SD card is inserted      | unchanged (read from SD)                                              |
      | v1.8.0 | no SD card is inserted      | replaced by seed profiles and an empty history (documented data loss) |

  @critical
  Scenario: Data loss on v1.8.x is recoverable from the exported backup
    Given I upgraded from v1.8.1 without an SD card and the profiles were replaced
    When I import the exported profile JSON on the Profiles page
    And I import the exported settings JSON in Settings
    Then all custom profiles return, including "Café ☕ Ristretto", with identical phases
    And favourites and order can be restored
    And the selected profile and startup profile work again

  Scenario: The v1.8.1 web UI warns to back up before updating
    Given a v1.8.1 display with an update available
    Then the update page shows the backup warning before starting the update

  @critical
  Scenario: v1.8.1 → RC, display only first (controller stays on v1.8.1)
    Given display and controller on v1.8.1
    When I update only the display, by OTA if the baseline UI offers it, otherwise by USB
    Then the RC display finds no nanopb characteristics, reads the legacy INFO JSON and treats the controller as protocol 0
    And the Standby screen shows "Version mismatch, update controller"
    And brewing, steaming and mode changes are blocked on the screen and in the web UI
    And the heater stays off (no control commands and no pings are sent)
    And the System tab shows the controller as v1.8.1 and offers "Update Controller"
    When I click "Update Controller"
    Then the controller firmware streams over BLE with progress shown in the web UI
    And the controller reboots into the RC, bonds with the display and the mismatch clears without power cycling
    And a brew completes

  @critical
  Scenario: v1.8.1 → RC, controller first (display stays on v1.8.1)
    Given display and controller on v1.8.1
    When I update only the controller from the v1.8.1 web UI
    Then the RC controller boots without crash-looping (legacy ERROR characteristic stub present, GM-221)
    And the v1.8.1 display can read the controller's version from the legacy INFO characteristic
    And brew control does not work in this state, and nothing is heated or pumped
    When I update the display from the v1.8.1 web UI
    Then the display reboots into the RC and the pair works normally

  Scenario: v1.8.1 → RC, controller first, then the display power-cycles before its update
    Given the controller is on the RC and the display is still on v1.8.1
    When I power cycle both units
    Then the v1.8.1 display still boots and its web UI is reachable
    And it can still start the display update

  @critical
  Scenario: v1.8.1 "update both" where the display step fails
    Given display and controller on v1.8.1
    When I start "update both" and cut the display's Wi-Fi after the controller finished and before the display download completes
    Then the controller is on the RC and the display remains on v1.8.1 (no half-written image boots)
    And the display web UI is reachable and the update can be retried
    When I restore Wi-Fi and retry
    Then both end on the RC and work

  Scenario: v1.8.1 "update both" where the filesystem step fails after the app was written
    Given the display app partition was written but display-filesystem.bin failed
    When the display boots the RC
    Then it formats the data partition as LittleFS and creates a "Default" profile
    And the web UI (embedded) still loads
    And the system reaches Standby

  # ---------------------------------------------------------------- Older baselines

  Scenario: v1.7.3 → RC with shots on an SD card
    Given display and controller on v1.7.3 with 5 shots (log format v5) and profiles on an SD card
    When I update to the RC (via v1.7.3 OTA, or USB if OTA cannot cross the protocol change)
    Then the v5 shots are listed in history with correct duration, volume and charts
    And shot notes and ratings are kept
    And "Rebuild Shot History" preserves avg temperature, max pressure and avg flow for v5 shots

  Scenario: v1.7.3 → v1.8.1 → RC (stepwise) gives the same end state as a direct upgrade
    Given one machine upgraded v1.7.3 → RC directly and a second v1.7.3 → v1.8.1 → RC
    Then both have identical settings, profiles and history listings (except for documented differences)

  Scenario: v1.6.x → RC
    Given display and controller on v1.6.x with CSV shot history
    When I update to the RC
    Then the old CSV history is not shown and causes no errors
    And settings are kept and the machine brews

  Scenario: v1.5.x → RC with settings export and import
    Given a settings export from v1.5.x
    When I import it into a freshly installed RC
    Then the keys it knows are applied and missing keys keep RC defaults
    And unknown keys are ignored without error

  Scenario: v1.4.0 → RC
    Given display and controller on v1.4.0
    When I update both using the v1.4.0 OTA
    Then the result is either a working RC pair, or a documented "please use USB" path
    And no path leaves the controller running without a watchdog

  Scenario: v1.3.x or older → RC (USB only)
    Given a controller on v1.3.x that cannot be OTA-updated from the display
    When I update the display to the RC by USB
    Then the display shows "Version mismatch, update controller" and does not heat
    When I update the controller to the RC by USB
    Then the pair bonds and works

  # ---------------------------------------------------------------- Nightly and pre-release baselines

  @critical
  Scenario: Previous nightly → RC on the nightly channel
    Given display and controller on the previous nightly and the channel set to "nightly"
    When the device checks for updates (or I force a check from the System tab)
    Then an update is offered
    When I update both
    Then settings, profiles, favourites and shot history (log v6/v7) are unchanged
    And the web UI is served (embedded) after the update
    And the data partition is not reformatted

  Scenario: Nightly with a stale /w web UI folder on LittleFS
    Given a display on a nightly from 2026-06-03 to 13 that has /w on LittleFS
    When I update to the RC
    Then the embedded web UI is served, not the stale files in /w
    And the free space shown includes the stale files (no cleanup exists; record the size)

  Scenario Outline: Display and controller on different protocol versions
    Given the display on "<display>" and the controller on "<controller>"
    Then the Standby screen shows "<message>"
    And brewing is blocked
    And OTA from the System tab resolves the mismatch

    Examples:
      | display | controller       | message                              |
      | RC      | previous nightly | Version mismatch, update controller* |
      | RC      | "db" pre-release | Version mismatch, update controller  |
      | "db"    | RC               | Version mismatch, update display     |
    # *only if the protocol version differs; otherwise the pair works normally

  @critical
  Scenario: Nightly user switching to the "latest" channel is not offered a downgrade
    Given a display on a nightly build newer than the latest stable release
    When I set the OTA channel to "latest"
    Then no update is offered
    And if a downgrade is ever offered it is clearly labelled as a downgrade

  # ---------------------------------------------------------------- Downgrade / rollback

  Scenario: Downgrading the display to v1.8.1 by USB with an RC controller
    Given an RC pair
    When I USB-flash the display with v1.8.1
    Then the v1.8.1 display cannot use the bonded RC controller (no encryption, disconnected)
    And nothing heats
    And re-flashing the RC display restores the pair without re-pairing

  Scenario: Downgrading the controller to v1.8.1 by USB with an RC display
    Given an RC pair
    When I USB-flash the controller with v1.8.1
    Then the RC display shows "Version mismatch, update controller"
    And "Update Controller" from the RC web UI brings it back

  Scenario: Crash-on-boot image does not brick the device
    Given a deliberately broken test build published on a PR channel
    When I OTA it to the display
    Then I record whether the bootloader rolls back to the previous image
    And USB recovery with the web installer works either way

  # ---------------------------------------------------------------- OTA mechanics

  @smoke
  Scenario: Update progress and UI during OTA
    When I start an update
    Then the display switches to Standby and shows "Updating…"
    And the web UI shows progress for each phase (controller then display)
    And profile and history requests from the web UI are refused while updating
    And the brew button and physical switches do nothing while updating

  Scenario: Update is not started or checked while a process runs
    Given a brew is running
    Then the 30-minute update check is skipped
    And starting an update from the web UI during a brew is refused or waits until the brew ends

  @critical
  Scenario: Controller OTA with a nearly full internal flash
    Given no SD card and the data partition filled with shots until less than 700 KB is free
    When I update the controller
    Then either the update succeeds, or it fails with a clear "not enough space" error
    And the controller is still on its previous working firmware
    And no profiles are deleted

  Scenario: Power loss on the controller during a BLE firmware transfer
    Given a controller OTA at about 50 %
    When I cut power to the controller
    And I restore power
    Then the controller boots its previous firmware
    And the display shows the version mismatch or the old version, and the update can be retried

  Scenario: Power loss on the display during the display download
    Given a display OTA at about 50 %
    When I cut power to the display
    Then it boots the previous firmware and the update can be retried

  Scenario: Wi-Fi drops and recovers during the download
    Given a display OTA in progress
    When I block Internet access for 30 s and then restore it
    Then the download resumes (HTTP Range) instead of restarting from zero
    And the update completes and passes the image checksum

  Scenario: GitHub returns an error or no release
    Given the update server returns 404 or 503
    Then the System tab shows an update error text
    And the device keeps working and retries at the next check

  Scenario: Update display only / controller only buttons
    Given both units are one version behind
    When I click "Update Display" only
    Then only the display is updated and the controller mismatch message appears if protocols differ
    When I click "Update Controller"
    Then the pair is consistent again

  Scenario Outline: OTA on every display type
    Given a "<display>" on the previous release
    When I update both from the web UI
    Then the display picks the "<asset>" asset and boots the RC

    Examples:
      | display              | asset                          |
      | LilyGo T-RGB         | display-firmware.bin           |
      | Waveshare RGB        | display-firmware.bin           |
      | AMOLED (any variant) | display-firmware.bin           |
      | display-headless     | display-headless-firmware.bin  |
      | display-headless-8m  | display-headless-firmware.bin  |

  Scenario Outline: OTA on every controller board
    Given a "<board>" controller on the previous release
    When I update the controller from the display
    Then it boots the RC and detects itself as "<board>" again

    Examples:
      | board                      |
      | GaggiMate Standard Rev 1.x |
      | GaggiMate Standard Rev 2.x |
      | GaggiMate Standard Rev 3.x |
      | GaggiMate Pro Rev 1.0      |
      | GaggiMate Pro Rev 1.1      |
      | GaggiMate Pro Lego Build   |

  # ---------------------------------------------------------------- After release

  @post-release @critical
  Scenario: Published release reaches users on the latest channel
    Given the planned version was published and CI has built its GitHub release
    And a display and controller on the previous stable release with the channel "latest"
    When the device checks for updates
    Then the published version is offered
    When I update both
    Then the System tab shows the published version string (no -N-g<sha> suffix) for both
    And a brew completes
