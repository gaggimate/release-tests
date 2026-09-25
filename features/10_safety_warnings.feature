@critical
Feature: Safety and error states
  A failure in this file blocks the release.

  Background:
    Given a paired RC machine on the bench with the controller serial console open

  Scenario: Thermocouple disconnected while idle
    Given the machine is heating in Brew mode
    When I unplug the thermocouple
    Then within a few seconds the controller turns heater, pump, valve and alt relay off
    And the display shows "Temperature error, restart…" and goes to Standby
    And Start on the touchscreen, web UI and physical buttons does nothing
    When I plug the thermocouple back in
    Then the error stays latched until the display is restarted

  Scenario: Thermocouple disconnected during a brew
    Given a brew is running
    When I unplug the thermocouple
    Then the brew stops and all outputs switch off

  Scenario: Intermittent thermocouple
    Given a thermocouple connection that drops about 1 in 3 readings
    Then no error is raised while fewer than half of the last 20 readings fail
    And the error is raised once half or more fail

  Scenario: Over-temperature runaway
    Given a test setup that makes the temperature reading go above 170 °C (e.g. a thermocouple simulator)
    Then the controller raises the runaway error and turns all outputs off

  Scenario Outline: Process safety caps
    When I run <process> without stopping it
    Then it ends by itself after <cap>

    Examples:
      | process                     | cap        |
      | a brew phase with no stop   | 300 s      |
      | steam                       | 10 minutes |
      | hot water                   | 120 s      |
      | hold-to-flush               | 60 s       |

  Scenario: Controller watchdog after display loss
    Given the machine is heating
    When the display freezes or loses power
    Then the controller switches off all outputs after 20 s without a ping

  Scenario: Display UI task freeze
    Given a UI freeze is simulated (debug build) or seen during testing
    Then the logic task keeps pinging, the machine stays controllable from the web UI
    And the System tab task health shows the UI task as unhealthy

  Scenario: Autotune overheat
    When a PID autotune pushes the boiler above 125 °C
    Then the autotune aborts with a runaway error and the heater turns off

  Scenario: Empty water tank with ToF warning set to Error
    Given the ToF sensor reads less than 20 % water and "Water tank low" is set to Error
    When I start a brew
    Then a confirmation appears
    And the LEDs show the error colour

  Scenario: Power loss mid-brew
    Given a brew is running
    When I cut mains power to the machine and restore it
    Then both units boot into the startup mode, the pump and valve stay off, and nothing resumes

  Scenario: Brownout / USB-only power on the controller
    Given the controller is powered from USB only (no mains)
    Then it does not heat or pump spuriously, and the display reports its state sensibly

  Scenario Outline: Warning level settings
    Given warning "<warning>" is set to <level>
    And its condition is active
    Then the status bar <icon>
    And a brew <brew>

    Examples:
      | warning                | level  | icon                  | brew                   |
      | Water tank low         | Ignore | shows no icon         | starts                 |
      | Water tank low         | Warn   | shows the icon        | starts                 |
      | Water tank low         | Error  | shows the icon        | asks for confirmation  |
      | Temperature not stable | Warn   | shows the icon        | starts                 |
      | Scale battery low      | Error  | shows the icon        | asks for confirmation  |
      | Steam switch is on     | Error  | shows the icon        | asks for confirmation  |
      | Flush recommended      | Ignore | shows no icon         | starts                 |
      | Scale not connected    | Warn   | shows the icon        | starts                 |

  Scenario: Temperature-not-stable definition
    When I change the brew target by 3 °C
    Then "Temperature not stable" appears
    And it clears 20 s after every reading is within max(2 °C, 2 %) of target
