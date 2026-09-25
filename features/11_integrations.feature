Feature: Integrations and plugins
  HomeKit, Boiler Fill, Smart Grind and MQTT are registered at boot, so toggling them needs a restart.
  HomeKit replaces mDNS when enabled.

  # ---------------------------------------------------------------- HomeKit

  Scenario: Pair with Apple Home
    Given HomeKit enabled, saved and restarted, and the display on home Wi-Fi
    When I add the accessory in Apple Home using the setup code shown in the Plugins tab
    Then a thermostat accessory appears with the current boiler temperature
    When I set it to Heat
    Then the machine leaves Standby and enters Brew mode
    When I set it to Off
    Then the machine enters Standby
    When I change the target temperature in Home
    Then the brew target changes on the display

  Scenario: HomeKit replaces mDNS
    Given HomeKit enabled
    Then http://<hostname>.local/ behaviour is recorded (mDNS plugin is not registered)
    And the web UI remains reachable by IP

  Scenario: HomeKit survives a Wi-Fi reconnect
    Given a paired HomeKit accessory
    When I reboot the router
    Then Apple Home shows the accessory as responding again within 2 minutes

  # ---------------------------------------------------------------- mDNS

  Scenario: mDNS after Wi-Fi reconnect
    When I reboot the router
    Then http://<hostname>.local/ resolves again after the display rejoins

  # ---------------------------------------------------------------- Boiler Fill

  Scenario: Boiler fill on startup
    Given Boiler Fill enabled with startup fill 5 s, saved and restarted
    When the machine powers on and the controller is ready
    Then the pump runs for 5 s once

  Scenario: Boiler fill after steam
    Given Boiler Fill enabled with steam fill 5 s
    When I switch from Steam to Brew
    Then the pump runs for 5 s
    When I switch from Steam to Standby
    Then the pump does not run

  # ---------------------------------------------------------------- Auto-wakeup

  Scenario: Scheduled wakeup
    Given auto-wakeup enabled with a schedule 2 minutes from now for today's weekday, and NTP time synced
    And the machine is in Standby
    Then at the scheduled minute the machine enters Brew mode

  Scenario: Weekday filter
    Given a schedule for tomorrow's weekday only
    Then no wakeup happens today at that time

  Scenario: Multiple schedules
    Given schedules at 07:00 Mon–Fri and 09:00 Sat–Sun
    Then both are saved, survive a reboot and fire on the right days

  Scenario: The last schedule cannot be deleted
    When I delete schedules until one remains
    Then the delete control for the last one is disabled

  Scenario: No NTP, no wakeup
    Given the display is in AP mode (no Internet time)
    Then no wakeup fires and nothing crashes

  # ---------------------------------------------------------------- LEDs and ToF

  @tof
  Scenario Outline: LED colours follow the machine state
    Given the Alba board with custom colours
    When the machine is <state>
    Then the LEDs show <colour>

    Examples:
      | state                        | colour                   |
      | in Standby                   | off                      |
      | idle in Brew mode            | idle colour              |
      | brewing                      | active colour            |
      | just finished a shot         | finished colour          |
      | low on water or in an error  | error colour             |

  @tof
  Scenario: LED colour migration from the old RGBW settings
    Given a v1.8.1 baseline with custom LED R/G/B/W values
    When I upgrade to the RC
    Then the idle colour equals the converted hex of the old values

  @tof
  Scenario: Water level calibration
    Given empty-tank distance 210 mm and full-tank distance 30 mm
    When I fill the tank in steps
    Then the Water Tank panel goes from 0 % to 100 % roughly linearly
    And "Water tank low" appears below 20 %

  @tof
  Scenario: ToF sensor unplugged at runtime
    When I disconnect the Alba cable while running
    Then the controller keeps working, logs the fault and recovers with backoff when reconnected
    And the LEDs return after reconnecting

  Scenario: External LED brightness
    When I change external brightness from 75 to 20
    Then the LEDs dim accordingly
