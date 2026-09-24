Feature: Display ↔ controller BLE link
  The display pings every 2 s. The controller turns all outputs off and drops the link after 20 s without a ping.
  After a reconnect the display re-sends its configuration for 8 s and the full state after 5 s.

  Background:
    Given a paired RC display and controller on the bench

  @critical @smoke
  Scenario: Display loss during a brew makes the controller safe
    Given a brew is running
    When I cut power to the display
    Then within 20 s the controller turns heater, pump and valve off
    And the controller log shows the ping timeout
    When I power the display again
    Then it reconnects, the controller error clears, and the display is in Standby

  @critical
  Scenario: Display loss while heating in Brew mode
    Given the machine is idle in Brew mode and heating
    When I cut power to the display
    Then the heater is off within 20 s and stays off

  Scenario: Controller power loss during a brew
    Given a brew is running
    When I cut power to the controller
    Then the display ends the process, shows "Waiting for controller" and goes to Standby
    And the partial shot is either saved (if longer than 7.5 s) or discarded, without corrupting history
    When the controller returns
    Then the display reconnects and PID, pressure scale and pump coefficients are applied again (check the controller log)

  Scenario: Reconnect re-applies non-default configuration
    Given a non-default PID, temperature offset and pressure sensor rating
    When I power cycle the controller
    Then after reconnecting the controller log shows the configured values, not defaults
    And the boiler holds the configured target temperature

  Scenario: BLE range edge
    Given the display is moved until the link is marginal (RSSI about -90 dBm)
    Then the link either stays up or reconnects within 15 s of each drop
    And no command is applied twice (e.g. a mode change is not repeated)

  Scenario: Heavy BLE load with a scale connected
    Given a Bookoo or Acaia scale connected
    When I brew a pressure profile for 40 s
    Then weight, pressure and temperature on the display lag reality by no more than about 1 s
    And the brew stops at the target weight without a multi-second overshoot

  Scenario: Connection interval negotiation while a scale is connected
    Given a scale is connected before the controller link comes up
    When the display connects to the controller
    Then a connection-update refusal (HCI 0x12 / rc 530) is followed by the next interval in the ladder
    And the link works normally

  Scenario: Rapid repeated power cycles
    When I power cycle the controller 10 times at 10 s intervals
    Then the display reconnects every time without rebooting itself
    And after the last cycle the system is ready in under 15 s

  Scenario: Controller serial status dump
    When I send "S" on the controller serial console
    Then it prints the board, outputs, temperatures and link state without disturbing control

  @critical
  Scenario: Protocol mismatch stops pings but keeps the controller safe
    Given the display is on a different protocol version from the controller
    Then the display sends no control commands and no pings
    And the controller keeps heater, pump and valve off
    And the controller drops the link once after 20 s (not during an update) and the display reconnects for OTA
