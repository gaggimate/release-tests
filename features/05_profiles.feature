Feature: Profiles
  Profiles live in /p/<id>.json on the SD card if present, otherwise on LittleFS.
  Type is "standard" or "pro"; the "utility" flag hides a profile from history (e.g. flush).

  @smoke
  Scenario: Create a simple profile in the web UI
    When I create a Simple profile "Test Simple" at 92 °C with preinfusion 5 s at 30 % and brew 25 s at 100 %
    Then it appears in the profile list
    And it can be selected and brewed

  @smoke @pro
  Scenario: Create a pro profile in the web UI
    When I create a Pro profile with 3 phases using pressure, flow and power modes, per-phase temperature, and stop conditions
    Then the chart preview matches the phases
    And after save and reload every field is unchanged

  Scenario: Convert a simple profile to pro
    Given a Simple profile
    When I click "Convert to Pro"
    Then the phases convert with equivalent targets and the profile brews identically

  Scenario: Edit, duplicate, delete
    Given a custom profile "A"
    When I duplicate it
    Then "A (copy)" or similar exists with identical phases and a new id
    When I delete "A" and confirm
    Then it disappears from the list, the display carousel and the favourites

  Scenario: Deleting the selected profile
    Given the selected profile is "A"
    When I delete "A"
    Then another profile is selected and the display shows it
    And a brew does not fail

  Scenario: Deleting the startup profile
    Given the startup profile is "A"
    When I delete "A"
    Then the startup profile resets to "last used"

  Scenario: Delete all profiles
    When I choose "Delete all" and confirm
    Then after a reboot a "Default" profile exists (93 °C, 28 s, 36 g), is selected and favourited

  Scenario: Favourites and order drive the display carousel
    Given favourites "A", "B", "C"
    When I drag them into the order C, A, B in the web UI
    Then the display's profile carousel shows C, A, B
    And the dashboard Quick Select shows the same order
    And the order persists after a reboot

  Scenario: Unfavouriting the last favourite
    When I unfavourite every profile
    Then the display still shows the selected profile and does not crash on the profile select screen

  Scenario: Select a profile on the device
    When I swipe to "B" on the profile select screen and load it
    Then the web UI shows "B" as selected within 2 s

  Scenario: Startup profile
    Given startup profile "B" and selected profile "A"
    When I reboot
    Then "B" is selected

  Scenario Outline: Import profiles
    When I import "<file>" on the Profiles page
    Then <result>

    Examples:
      | file                                     | result                                                        |
      | a GaggiMate single profile JSON          | one profile is added and brews                                |
      | a GaggiMate "export all" array           | all profiles are added                                        |
      | a Decent .tcl profile                    | it converts to a pro profile with sensible phases             |
      | a Meticulous JSON profile                | it converts to a pro profile                                  |
      | a malformed JSON file                    | a clear error is shown and nothing is saved                   |
      | a JSON missing label/type/phases         | it is rejected, and existing profiles are unaffected          |
      | a profile with 12+ phases                | it is saved, brews, and all phases are recorded               |

  Scenario: Export round trip
    When I export a profile and re-import it
    Then the re-imported profile is identical apart from its id

  Scenario: Unicode and long names
    Given a profile named "Café ☕ Ristretto — extra long name to check truncation"
    Then the display shows it truncated cleanly without broken glyphs
    And the web UI, history and statistics show the full name

  Scenario: Utility profiles
    Given a profile marked utility
    Then it appears under the Utility tab, not Extraction
    And brewing it is not recorded in history and skips the finished screen

  Scenario: Profile edits during a brew
    Given a brew is running with profile "A"
    When I save changes to "A" in the web UI
    Then the running brew is not disrupted
    And the next brew uses the new values

  Scenario: Profile requests during OTA are refused
    Given an update is running
    When I try to save a profile
    Then the web UI shows a refusal and nothing is written

  Scenario: Many profiles
    Given 60 profiles exist
    Then the Profiles page loads within 3 s and the display carousel stays responsive
