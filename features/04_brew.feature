Feature: Brewing
  A brew runs the selected profile's phases. The target is weight (volumetric) when the profile has a weight target and a
  healthy scale (reading within 1.5 s) is connected, otherwise time. Each phase has a 300 s safety cap.

  Background:
    Given a paired RC machine with water in the tank
    And the machine is in Brew mode at the target temperature

  @smoke @critical
  Scenario: Basic timed shot from the touchscreen
    Given the stock "9 bar" profile is selected and no scale is connected
    When I tap Start on the Brew screen
    Then the Status screen shows phase name, elapsed time, pressure (Pro) and temperature
    And the pump and valve switch on
    And the shot stops by itself at the profile duration
    And the finished screen shows the shot time and returns to Brew on clear
    And the shot appears in history with a chart

  @smoke
  Scenario: Start and stop from the web UI dashboard
    When I click Start in the dashboard's Shot Controls
    Then the display switches to the Status screen
    When I click Stop after 10 s
    Then the brew stops within 0.5 s and the valve releases pressure

  Scenario: Stop mid-shot from the touchscreen
    When I start a brew and tap Stop after 5 s
    Then the pump stops immediately
    And a shot of 7.5 s or less is not stored in history

  @smoke
  Scenario: Volumetric shot with a scale
    Given a connected scale and a profile with a 36 g weight target
    When I start a brew
    Then the scale is tared twice before the pump starts
    And the weight on the screen follows the scale
    And the brew stops so that the final cup weight is within ±1.5 g of 36 g
    And the scale timer stops at the end of the brew (if the scale supports timer control)

  Scenario: Predictive stop auto-adjust converges
    Given "auto-adjust delay" is on and the brew delay is 800 ms
    When I brew 5 volumetric shots with the same profile
    Then the brew delay setting changes after each shot and stays between 0 and 4000 ms
    And the overshoot on shots 4 and 5 is smaller than on shot 1

  Scenario: Predictive stop auto-adjust turned off
    Given "auto-adjust delay" is off
    When I brew a volumetric shot
    Then the brew delay setting is unchanged

  Scenario: Scale disappears mid-shot
    Given a volumetric shot is running
    When I switch off the scale at 10 s
    Then the brew continues on time (or its safety cap) and does not stall at the missing weight
    And the scale icon shows disconnected

  Scenario: Weight target without a scale falls back to time on a Standard board
    Given a Standard controller, a profile with a weight target and no scale
    When I brew
    Then the brew runs on the phase durations

  @release-build @pro
  Scenario: Weight target without a scale falls back to time on a Pro board
    Given a local release build (pio run -e display, no NIGHTLY_BUILD) of the commit under test flashed by USB
    And a Pro controller, a profile with a weight target and no scale
    When I brew
    Then the brew runs on the phase durations and does not use the flow estimate

  @nightly @pro
  Scenario: Nightly flow-estimate volumetric without a scale
    Given a nightly build, a Pro board and no scale
    When I brew a profile with a weight target
    Then the estimated output is used as the volumetric target
    And the brew stops near the target (record the error against a reference scale)

  Scenario: Adjust temperature on the Brew screen
    When I tap temperature + three times
    Then the target rises by 3 °C, the profile is marked modified and the heater follows
    And the target cannot go above 160 °C or below 0 °C

  Scenario: Adjust the time target on the Brew screen
    Given a profile with 2 brew phases of 10 s and 20 s
    When I tap time + 3 times
    Then the total rises by 3 s spread proportionally across the brew phases
    When I tap time − many times
    Then no phase gets shorter than 0.5 s

  Scenario: Adjust the weight target on the Brew screen
    Given a profile with a 36 g target and a connected scale
    When I tap weight + twice
    Then the target shows 38 g
    And "Save" persists 38 g to the profile
    And "Save as new" creates "Copy of <name>", favourited, with 38 g, and leaves the original unchanged

  Scenario: Remove the weight target on the device
    When I delete the volumetric target on the Brew screen
    Then the brew runs on time
    And the stored profile is unchanged unless I save

  Scenario: Tare from the Brew screen
    Given a connected scale with a cup on it
    When I long-press the weight display
    Then both the scale and the controller's volumetric estimate are tared

  @pro
  Scenario Outline: Pro profile pump modes
    Given a pro profile with a single 30 s phase using pump mode "<mode>" with target <target>
    When I brew into a blind basket or real puck
    Then the measured <measure> tracks <target> within <tolerance> after the first 3 s
    And the limit value is respected

    Examples:
      | mode          | target   | measure  | tolerance |
      | pressure      | 9 bar    | pressure | ±0.5 bar  |
      | pressure      | 6 bar    | pressure | ±0.5 bar  |
      | flow          | 2 ml/s   | flow     | ±0.5 ml/s |
      | power         | 60 %     | pump %   | exact     |
      | pressure (-1) | measured | pressure | holds phase-start value |

  @pro
  Scenario Outline: Transitions between phases
    Given a pro profile ramping pressure from 3 to 9 bar over 6 s with transition "<type>"
    When I brew
    Then the pressure curve in the shot chart has the shape "<type>"

    Examples:
      | type        |
      | instant     |
      | linear      |
      | ease-in     |
      | ease-out    |
      | ease-in-out |

  @pro
  Scenario: Adaptive ramp starts from the measured value
    Given a phase with an adaptive linear ramp to 9 bar after a preinfusion at about 2 bar
    When I brew
    Then the ramp starts from the pressure measured at the phase change, not from 0

  @pro
  Scenario Outline: Stop conditions end the phase and record the exit reason
    Given a pro profile whose first phase has stop condition "<condition>" and a 60 s duration
    When I brew
    Then the phase ends when "<condition>" is met, well before 60 s
    And the analyzer shows exit reason "<reason>" for that phase

    Examples:
      | condition             | reason    |
      | weight ≥ 5 g          | weight    |
      | pressure ≥ 4 bar      | pressure  |
      | pressure ≤ 2 bar      | pressure  |
      | flow ≥ 3 ml/s         | flow      |
      | flow ≤ 1 ml/s         | flow      |
      | water pumped ≥ 50 ml  | water     |
      | (none)                | duration  |

  Scenario: Per-phase temperature
    Given a pro profile with phase 1 at 88 °C and phase 2 at 94 °C
    When I brew
    Then the target temperature changes at the phase change and the chart shows both targets

  Scenario: Valve closed phase
    Given a phase with the valve closed
    Then no water reaches the cup during that phase and pressure builds (Pro)

  @critical
  Scenario: Per-phase safety cap
    Given a pro profile with a single phase of 400 s and no stop condition
    When I brew into an empty portafilter
    Then the phase ends at 300 s

  Scenario: Pressure offset for mushroom-valve machines
    Given pressure offset 1.0 bar
    When I brew a 9 bar pressure profile
    Then the displayed pressure is about 9 bar while brewing
    And the offset is not applied outside brewing

  Scenario Outline: Brew confirmation when a warning is at Error level
    Given warning "<warning>" is set to Error and its condition is active
    When I start a brew on the <surface>
    Then a confirmation with "Back" and "Ignore" appears instead of starting
    When I choose "Ignore"
    Then the brew starts
    When I start again and choose "Back"
    Then nothing starts

    Examples:
      | warning                | surface     |
      | Flush recommended      | touchscreen |
      | Water tank low         | web UI      |
      | Temperature not stable | touchscreen |
      | Scale not connected    | web UI      |
      | Scale battery low      | touchscreen |

  Scenario: Warning at Warn level shows an icon but does not block
    Given "Flush recommended" is at Warn level and a flush is pending
    Then the warning icon shows in the status bar
    And a brew starts immediately

  Scenario: Warning at Ignore level is silent
    Given "Temperature not stable" is at Ignore and the boiler is heating
    Then no warning icon is shown and brewing is not blocked

  Scenario: Brew cannot start while not ready
    Given the display is still waiting for the controller
    Then Start on the touchscreen, web UI and the physical button does nothing

  Scenario: Standby timeout
    Given standby timeout 1 minute
    When I leave the machine in Brew mode untouched for 70 s
    Then it enters Standby and the heater target drops
    Given standby timeout 0
    Then the machine never enters Standby on its own

  Scenario: Standby timeout does not interrupt a running process
    Given standby timeout 1 minute
    When I start a 90 s brew
    Then the brew runs to the end before standby is considered
