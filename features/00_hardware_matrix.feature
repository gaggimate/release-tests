@matrix
Feature: Hardware detection and capability matrix
  One controller binary serves every PCB revision, detected at boot from the voltage on GPIO11.
  One display binary serves every panel, detected by probing and cached in NVS ("panel" namespace).
  Headless builds run the web UI without a screen.

  # ---------------------------------------------------------------- Controller PCBs

  @critical
  Scenario Outline: Controller identifies its PCB revision and reports capabilities
    Given a controller of type "<board>" flashed with the release candidate
    And the serial console of the controller is open
    When the controller is powered on
    Then after the 5 s start-up delay the log shows board "<board>"
    And the controller does not reboot loop
    And the display's System & Updates tab shows hardware "<board>"
    And the reported capability "dimming" is <dimming>
    And the reported capability "pressure" is <pressure>

    Examples:
      | board                       | dimming | pressure |
      | GaggiMate Standard Rev 1.x  | false   | false    |
      | GaggiMate Standard Rev 2.x  | false   | false    |
      | GaggiMate Standard Rev 3.x  | false   | false    |
      | GaggiMate Pro Rev 1.0       | true    | true     |
      | GaggiMate Pro Rev 1.1       | true    | true     |
      | GaggiMate Pro Lego Build    | true    | true     |

  Scenario Outline: Capability-gated features follow the board
    Given a display paired with a "<board>" controller
    When I open the web UI
    Then the dashboard pressure chart and pressure readout are <pressure_ui>
    And the profile editor offers pressure and flow pump modes <pro_modes>
    And the Machine settings show pressure offset and sensor rating <pressure_ui>
    And the Calibration tab offers pump flow calibration <pump_cal>

    Examples:
      | board                      | pressure_ui | pro_modes          | pump_cal      |
      | GaggiMate Standard Rev 3.x | hidden      | as disabled/PRO    | not available |
      | GaggiMate Pro Rev 1.1      | shown       | enabled            | available     |

  @standard
  Scenario Outline: Standard board pump output uses time-proportioning
    Given a "<board>" controller
    When I run a Simple profile with pump power 50 %
    Then the pump cycles on and off with a window of <window>
    And the shot completes without controller errors

    Examples:
      | board                      | window  |
      | GaggiMate Standard Rev 1.x | ~5000 ms |
      | GaggiMate Standard Rev 2.x | ~1000 ms |
      | GaggiMate Standard Rev 3.x | ~1000 ms |

  Scenario Outline: Alt relay is on the correct pin per board
    Given a "<board>" controller with a grinder or test lamp on the alt relay
    And the setting "Alt relay function" is "Grind"
    When I start a 5 s grind
    Then the alt relay switches on for 5 s and then off
    And no other output switches

    Examples:
      | board                      |
      | GaggiMate Standard Rev 1.x |
      | GaggiMate Standard Rev 2.x |
      | GaggiMate Standard Rev 3.x |
      | GaggiMate Pro Rev 1.1      |

  @critical
  Scenario: Unknown board ID causes a controlled restart, not undefined outputs
    Given a controller whose detect divider reads an unused ID (e.g. ID 5, 500–599 mV)
    When the controller is powered on
    Then heater, pump and valve remain off
    And the controller logs that the board is unknown and restarts after ~5 s

  @pro
  Scenario: Gear pump addon is detected on a Pro board
    Given a "GaggiMate Pro Rev 1.1" controller with the Gearpump addon attached to the ext port
    When the controller boots
    Then the display reports addon type 7
    And the Plugins tab shows the "BLDC pump" settings section
    And a pressure profile brews with the gear pump
    And pump slip coefficients and gains changed in the web UI are applied after save

  @standard @known-issue-GM-237
  Scenario: Gear pump addon connected to a Standard board is ignored safely
    Given a "GaggiMate Standard Rev 3.x" controller with the Gearpump addon on the ext port
    When the controller boots
    Then the controller boots normally and does not crash
    And the display does not report addon type 7

  @tof
  Scenario Outline: Sunrise/Alba board is detected on boards with the 4-pin port
    Given a "<board>" controller with the Alba LED + ToF board attached
    When the controller boots
    Then the capabilities report led_control=true and tof=true
    And the dashboard shows the Water Tank panel
    And the LEDs show the idle colour after the controller is ready

    Examples:
      | board                      |
      | GaggiMate Standard Rev 2.x |
      | GaggiMate Standard Rev 3.x |
      | GaggiMate Pro Rev 1.0      |
      | GaggiMate Pro Rev 1.1      |

  Scenario: Standard Rev 1.x without Sunrise port reports no LEDs or ToF
    Given a "GaggiMate Standard Rev 1.x" controller
    When the controller boots
    Then the capabilities report led_control=false and tof=false
    And the web UI hides the Water Tank panel and the Alba settings are inert

  # ---------------------------------------------------------------- Display panels

  @critical
  Scenario Outline: Display detects its panel and touch controller on a cold boot
    Given a "<panel>" display flashed via USB with the release candidate (NVS erased)
    When it boots for the first time
    Then the UI renders centred and uncropped at <resolution>
    And touch input maps to the correct position in all four corners
    And the panel detection result is cached so the second boot skips probing
    And the backlight responds to the brightness setting (<backlight>)

    Examples:
      | panel                                 | resolution | backlight                    |
      | LilyGo T-RGB 2.1" (CST820)            | 480x480    | 16 pulse steps               |
      | LilyGo T-RGB 2.1" (FT3267)            | 480x480    | 16 pulse steps               |
      | LilyGo T-RGB 2.8" (GT911)             | 480x480    | 16 pulse steps               |
      | Waveshare ESP32-S3 2.1" RGB (CST820)  | 480x480    | PWM, 16 levels               |
      | Waveshare ESP32-S3 RGB (GT911)        | 480x480    | PWM, 16 levels               |
      | LilyGo T-Display S3 AMOLED 1.75"      | 466x466    | panel command, 16 quantized  |
      | Waveshare 1.43" Touch AMOLED (FT3168) | 466x466    | panel command, 16 quantized  |
      | Waveshare 1.75" AMOLED (CST92XX)      | 466x466    | panel command, 16 quantized  |

  Scenario Outline: Panel-specific rendering checks
    Given a "<panel>" display connected to a controller
    When I navigate Standby → Brew → Status (during a shot) → Profile select → Steam → Water → Grind → Info
    Then every screen is fully visible with nothing clipped at the round/square edges
    And the frame rate during a shot is smooth (no multi-second stalls on the pressure/temperature gauges)
    And switching theme between dark and light re-renders all screens correctly
    And on AMOLED panels the dark theme uses true black backgrounds

    Examples:
      | panel                            |
      | LilyGo T-RGB 2.1"                |
      | LilyGo T-RGB 2.8"                |
      | Waveshare ESP32-S3 2.1" RGB      |
      | LilyGo T-Display S3 AMOLED 1.75" |
      | Waveshare 1.43" Touch AMOLED     |
      | Waveshare 1.75" AMOLED           |

  Scenario: Touch wake from standby on panels without a touch interrupt
    Given a "Waveshare 1.43\" Touch AMOLED" display in Standby with the standby display dimmed
    When I tap the screen
    Then the screen wakes (or the documented limitation applies: no touch interrupt means no wake from deep dim)
    And the behaviour matches the release notes

  @sd
  Scenario Outline: SD card slot works on every panel that has one
    Given a "<panel>" display with a FAT32-formatted SD card inserted
    When it boots
    Then the System & Updates tab shows SD usage
    And profiles and shot history are read from and written to the SD card

    Examples:
      | panel                            |
      | LilyGo T-RGB 2.1"                |
      | Waveshare ESP32-S3 2.1" RGB      |
      | LilyGo T-Display S3 AMOLED 1.75" |
      | Waveshare 1.75" AMOLED           |

  Scenario: Panel cache recovers from a crash during panel init
    Given a display whose cached panel entry was written for a different panel type
    When it boots
    Then the cached entry is cleared before init
    And if init fails the next boot runs full detection and the correct panel comes up

  # ---------------------------------------------------------------- Headless

  @critical
  Scenario Outline: Headless display builds run without a screen
    Given a "<device>" flashed via USB with "<env>"
    When it boots
    Then the web UI is reachable (AP portal on first boot, then on Wi-Fi)
    And it pairs with a controller and can start and stop a brew from the web UI
    And no LVGL or panel-driver messages appear in the log
    And the SD card is not mounted even if a card is inserted

    Examples:
      | device                       | env                 |
      | 16 MB ESP32-S3 (LilyGo board) | display-headless    |
      | Seeed XIAO ESP32-S3 (8 MB)    | display-headless-8m |

  Scenario: Headless 8 MB OTA fetches a compatible image
    Given a "display-headless-8m" device on the previous release
    When I start "Update Display" from the web UI
    Then the downloaded image boots on the 8 MB board
    # display-headless-8m is not built by CI; OTA pulls display-headless-firmware.bin (16 MB board). Record the result.

  Scenario: 4 MB headless devices are documented as unsupported
    Given a 4 MB ESP32-S3 running a pre-GM-106 headless build
    Then the release notes state there is no OTA path and no current image for 4 MB boards
