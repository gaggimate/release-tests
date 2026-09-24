Feature: Storage (LittleFS, SD card, shot history)
  If the panel supports SD and a card mounts, profiles and history use SD instead of LittleFS. Nothing is copied
  between them. History is /h/NNNNNN.slog (log v7) + notes JSON + index.bin. Shots of 7.5 s or less are discarded.
  The oldest shots are deleted when free space drops below 500 KB.

  @sd
  Scenario: Inserting an SD card switches storage
    Given profiles and shots on LittleFS and no SD card
    When I insert an empty SD card and reboot
    Then the device uses the SD card: a "Default" profile is created and history is empty
    And the System tab shows SD usage
    When I remove the card and reboot
    Then the original LittleFS profiles and shots are back

  @sd
  Scenario: SD card removed while running
    Given the device is running from SD
    When I pull the card
    Then the device does not crash or corrupt LittleFS
    And saving a profile shows an error (record the behaviour)
    And after reinserting and rebooting everything on the card is intact

  @sd
  Scenario Outline: SD card formats and sizes
    Given a "<card>" card
    When I boot with it
    Then it <result>

    Examples:
      | card                | result                                    |
      | 4 GB FAT32          | mounts                                    |
      | 32 GB FAT32         | mounts                                    |
      | 64 GB exFAT         | does not mount and falls back to LittleFS |
      | corrupt / unformatted | does not mount and falls back to LittleFS |

  Scenario: Shots of 7.5 s or less are discarded
    When I pull a 5 s shot and an 8 s shot
    Then only the 8 s shot is in history

  Scenario: Weight settles after the shot
    Given a scale connected
    When a volumetric shot ends
    Then recording continues about 3 s and the final weight in history includes the drips

  @critical
  Scenario: Automatic pruning when storage is full
    Given no SD card and the data partition nearly full
    When I keep pulling shots
    Then the oldest shots are deleted to keep at least 500 KB free
    And profiles are never deleted
    And the index marks the pruned shots as deleted and the list stays consistent

  @known-issue-GM-235
  Scenario: Rebuild shot history keeps aggregates
    Given shots recorded with the RC (log v7) and with older versions (v5, v6)
    When I click "Rebuild Shot History" and wait for the progress to reach 100 %
    Then every shot's average temperature, max pressure and average flow are the same as before the rebuild

  Scenario: Corrupt index
    Given /h/index.bin is overwritten with random bytes (via a debug build or an SD card reader)
    When the device boots
    Then the index is recreated and the history list works after a rebuild

  Scenario: Shot IDs keep counting
    When I delete the newest shot and pull a new one
    Then the new shot gets a new ID and does not overwrite old notes

  Scenario: Shot history with many entries
    Given 500 shots on an SD card
    Then the history page loads the most recent shots within 3 s and paging/scrolling works
    And the statistics page completes its load without the display rebooting

  Scenario: Legacy recent.bin removed
    Given a /h/recent.bin from an older version
    When the RC boots
    Then the file is deleted and history works
