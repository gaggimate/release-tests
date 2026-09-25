Feature: Long-running stability
  Run in parallel with the rest of the release pass on a spare rig. Keep both serial consoles logging to files.

  @critical
  Scenario: 24-hour idle soak
    Given a paired machine in Brew mode with standby timeout 0, a scale saved and the dashboard open in a browser
    When it runs for 24 hours
    Then neither device reboots
    And the free heap (internal and PSRAM) on the System tab does not keep falling
    And the BLE link to the controller never stays down for more than 15 s
    And the task health flags stay green

  Scenario: 24-hour standby soak with auto-wakeup
    Given the machine in Standby with an auto-wakeup schedule each morning
    When it runs for 24 hours
    Then the wakeup fires once at the scheduled time and the machine is controllable afterwards

  @critical
  Scenario: 10-shot run
    Given a scale connected and profiles rotating between simple, pro and volumetric
    When I pull 10 shots (blind/calibration basket is fine) with flushes between them
    Then every shot is recorded with a correct chart
    And no shot misses its stop condition
    And the free heap after shot 10 is within 10 % of the value after shot 1

  Scenario: Mode cycling
    When I cycle Standby → Brew → Steam → Water → Grind → Brew → Standby 100 times using the web UI or a script
    Then no command is lost, no reboot happens and the final state is Standby

  Scenario: Scale connect/disconnect cycling
    When I switch the scale off and on 5 times during Brew mode
    Then it reconnects every time and the UI never freezes for more than 1 s

  Scenario: Core dump check
    Given all other release tests are done
    Then "Download support data" has no core dump, or each core dump is filed as a GitHub issue
