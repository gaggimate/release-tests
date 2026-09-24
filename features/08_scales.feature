@matrix
Feature: BLE scales
  Scales are matched by advertised name. The plugin scans only when the controller is connected and the mode is not
  Standby, disconnects in Standby, reconnects to the saved scale automatically, and tares twice before brew and grind.

  # ---------------------------------------------------------------- Per-driver functionality

  @critical
  Scenario Outline: Each scale driver connects, streams weight and tares
    Given a "<scale>" scale switched on in grams
    And the display is in Brew mode
    When I scan on Settings → Bluetooth and connect to it
    Then it shows as connected and is saved as the default scale
    And putting a 100 g reference weight on it shows 100 g ±0.2 g on the display and dashboard within 1 s
    And long-pressing the weight on the Brew screen tares it to 0.0
    And the battery level is <battery>
    And a volumetric 36 g brew stops within ±1.5 g in the cup

    Examples:
      | scale                         | battery                  |
      | Acaia Lunar                   | shown                    |
      | Acaia Pearl S                 | shown                    |
      | Acaia Pyxis                   | shown                    |
      | Acaia Umbra                   | shown                    |
      | Bookoo Themis (BOOKOO_SC)     | shown                    |
      | Decent Scale                  | shown or unknown         |
      | EspressiScale                 | shown or unknown         |
      | Difluid Microbalance          | shown                    |
      | Eclair                        | shown                    |
      | Eureka / CFS-9002             | unknown                  |
      | Eureka unnamed (mfr data)     | unknown                  |
      | Felicita Arc                  | shown or unknown         |
      | Timemore Black Mirror         | shown or unknown         |
      | Timemore Dot                  | shown                    |
      | Varia AKU / AKU Mini          | shown                    |
      | WeighMyBru                    | shown or unknown         |
      | myscale / blackcoffee         | shown or unknown         |

  Scenario Outline: Scale timer control
    Given a connected "<scale>"
    When I brew a volumetric shot
    Then the scale timer <timer>

    Examples:
      | scale         | timer                                   |
      | Bookoo Themis | starts on tare and stops at brew end    |
      | Acaia Lunar   | stops at brew end if supported          |
      | Timemore Dot  | is not controlled (disabled on purpose) |

  Scenario: Bookoo native flow rate
    Given a connected Bookoo scale
    When I brew
    Then the dashboard's weight flow uses the scale's flow rate and looks smooth

  @critical
  Scenario: Timemore Dot tare and streaming
    Given a paired Timemore Dot
    Then weight only streams after the link is encrypted
    When I tare from the display
    Then the scale tares (command 03 0D) and does not trigger extra query reports
    And the controller link latency does not rise

  Scenario: Scale in ounces
    Given a connected scale set to ounces
    When I start a brew
    Then a warning that the scale is not in grams is shown

  # ---------------------------------------------------------------- Lifecycle

  Scenario: Scale disconnects in Standby and reconnects on wake
    Given a saved and connected scale
    When the machine enters Standby
    Then the scale is disconnected and scanning stops
    When I wake the machine
    Then the saved scale reconnects within 15 s without a manual scan

  Scenario: Scale switched off and on while in Brew mode
    Given a connected scale
    When I switch it off
    Then the scale icon shows disconnected and "Scale not connected" appears (if enabled)
    When I switch it on again
    Then it reconnects on its own

  Scenario: Low scale battery
    Given a scale reporting battery below 20 %
    Then "Scale battery low" appears at its configured level (default Error, so brew asks for confirmation)

  Scenario: Switching to another scale
    Given scale A is saved
    When I connect scale B from the Bluetooth page
    Then B is saved and A is no longer auto-connected

  Scenario: Two supported scales in range
    Given scales A (saved) and B are both on
    When the machine wakes
    Then only A connects

  Scenario: Scale connect does not block the display
    Given a saved scale that is switched off
    When I wake the machine
    Then the UI stays responsive (no freeze over 1 s) while the plugin scans and retries

  Scenario: Weight outliers are rejected
    When the scale reports a spike above 10000 g or below −1000 g
    Then the value is ignored and the brew is not stopped by it

  # ---------------------------------------------------------------- Screen × scale combinations

  @critical
  Scenario Outline: Scale and display combinations under load
    Given a "<display>" display with a "<board>" controller
    And a connected "<scale>" scale
    When I brew three volumetric shots back to back
    Then all three stop within ±1.5 g of target
    And the UI frame rate during the shot stays smooth
    And the controller link does not drop
    And no watchdog reset appears on either device

    Examples:
      | display                          | board                      | scale         |
      | LilyGo T-RGB 2.1"                | GaggiMate Pro Rev 1.1      | Acaia Lunar   |
      | LilyGo T-RGB 2.1"                | GaggiMate Standard Rev 3.x | Bookoo Themis |
      | LilyGo T-RGB 2.8"                | GaggiMate Pro Rev 1.0      | Timemore Dot  |
      | Waveshare ESP32-S3 2.1" RGB      | GaggiMate Pro Rev 1.1      | Bookoo Themis |
      | Waveshare ESP32-S3 2.1" RGB      | GaggiMate Standard Rev 2.x | Decent Scale  |
      | LilyGo T-Display S3 AMOLED 1.75" | GaggiMate Pro Rev 1.1      | Timemore Dot  |
      | LilyGo T-Display S3 AMOLED 1.75" | GaggiMate Standard Rev 3.x | Varia AKU     |
      | Waveshare 1.43" Touch AMOLED     | GaggiMate Pro Lego Build   | Felicita Arc  |
      | Waveshare 1.75" AMOLED           | GaggiMate Pro Rev 1.1      | Difluid       |
      | display-headless                 | GaggiMate Pro Rev 1.1      | Acaia Pearl S |
      | display-headless                 | GaggiMate Standard Rev 1.x | Eureka        |
      | display-headless-8m              | GaggiMate Pro Rev 1.1      | Bookoo Themis |
