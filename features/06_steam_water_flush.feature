Feature: Steam, hot water and flush

  Background:
    Given a paired RC machine with water in the tank

  @smoke
  Scenario: Steam mode heats and starts pump assist automatically
    Given steam temperature 145 °C and steam pump assist 4 %
    When I switch to Steam mode from the menu
    Then the heating indicator blinks until within 5 °C of 145 °C
    And the steam process starts by itself without a Start tap
    And the pump pulses gently for assist

  @pro
  Scenario: Steam pump assist on a Pro board is flow-controlled with a pressure cap
    Given steam pump assist 4 % and cutoff 2 bar
    When the steam process is running with the steam valve closed
    Then the pressure does not exceed about 2 bar

  @critical
  Scenario: Steam safety limit
    When I leave the machine steaming for 10 minutes
    Then the steam process ends by itself at 10 minutes

  Scenario: Steam temperature adjustment
    When I tap temperature + on the Steam screen
    Then the steam target rises by 1 °C and persists

  Scenario: Leaving Steam mode
    When I switch from Steam to Brew
    Then the boiler cools down to the brew temperature
    And "Temperature not stable" shows until it settles

  Scenario: Start button in Steam mode
    When I tap Start in Steam mode
    Then nothing extra happens (steam starts automatically)

  @smoke
  Scenario: Hot water
    Given water temperature 80 °C
    When I start Water mode and tap Start
    Then the pump runs with the brew valve closed
    When I tap Stop
    Then the pump stops

  @critical
  Scenario: Hot water safety limit
    When I start hot water and do not stop it
    Then it stops by itself at 120 s

  @smoke
  Scenario Outline: Timed flush
    Given flush duration <seconds> s
    When I long-press Start on the Brew screen
    Then the pump runs at 100 % with the valve open for <seconds> s, followed by a 1 s drain
    And the flush is not recorded in history
    And "Flush recommended" clears

    Examples:
      | seconds |
      | 5       |
      | 1       |
      | 60      |

  Scenario Outline: Hold-to-flush
    Given flush duration 0
    When I hold <control> for 8 s and release
    Then the pump runs while held and stops within 0.5 s of release

    Examples:
      | control                                 |
      | the Start button on the touchscreen     |
      | the physical brew switch (momentary)    |
      | the flush button on the web dashboard   |

  @critical
  Scenario: Hold-to-flush safety cap
    Given flush duration 0
    When I hold the flush for 70 s
    Then the flush stops at 60 s

  Scenario: Flush from the web UI while the network drops
    Given flush duration 0 and a hold-flush started from the web UI
    When the browser loses its connection before sending stop
    Then the flush stops at the 60 s cap at the latest

  Scenario: Flush pending logic
    Given a flush just ran
    Then "Flush recommended" is clear
    When I pull a real shot
    Then "Flush recommended" is set again
    When I switch from Steam back to Brew
    Then "Flush recommended" is set
