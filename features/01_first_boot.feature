Feature: First boot, network setup and pairing
  A fresh USB install must reach a working, paired machine without developer tools.

  Background:
    Given a display and a controller flashed via USB (web installer) with the release candidate
    And both NVS partitions were erased

  @smoke @critical
  Scenario: Fresh install comes up in AP mode with a password-protected access point
    When the display boots for the first time
    Then an access point named after the device is broadcast
    And the access point requires a WPA2 password
    And the Info screen shows a QR code containing the AP SSID and password
    When I join the AP by scanning the QR code
    Then the captive portal opens the web UI at http://4.4.4.1/

  Scenario: AP password is generated once and stays stable
    Given I noted the AP password from the Info screen
    When I reboot the display twice without configuring Wi-Fi
    Then the AP password is unchanged

  Scenario: Changing the AP password
    When I set the AP password to a 7-character value in General settings
    Then the change is rejected (minimum 8 characters)
    When I set it to "coffee1234" and save and restart
    Then the AP accepts "coffee1234" and rejects the old password

  @smoke
  Scenario: Configure Wi-Fi from the captive portal
    Given I am connected to the display's AP
    When I enter my home SSID and password in General settings and choose "Save and restart"
    Then the display joins the home network
    And the Info screen shows the device URL instead of the AP QR code
    And http://gaggimate.local/ opens the web UI

  Scenario: Wrong Wi-Fi password falls back to AP mode
    When I save a wrong Wi-Fi password and restart
    Then the display fails to join, then brings up its AP again
    And I can correct the password from the portal

  Scenario: Password field is masked and "unchanged" is preserved
    Given Wi-Fi is configured
    When I change only the hostname and save
    Then the Wi-Fi password is not overwritten
    And the stored SSID is still used after restart

  Scenario: Improv serial provisioning
    Given the display is in AP mode and connected over USB
    When I provision Wi-Fi via Improv (e.g. from the web installer)
    Then the credentials are saved and the display reboots onto the network

  Scenario: Custom hostname
    When I set the hostname to "espresso-lab" and restart
    Then http://espresso-lab.local/ resolves

  # ---------------------------------------------------------------- Pairing / bonding

  @smoke @critical
  Scenario: Display and controller pair on first boot
    When both units are powered
    Then the display shows "Waiting for controller" and then enters Standby
    And the BLE status icon shows connected
    And the controller log shows it bonded to this display
    And the System tab shows both firmware versions equal to the release candidate

  @critical
  Scenario: Bonded controller ignores a second display
    Given the controller is bonded to display A
    When a second display B running the release candidate is powered nearby
    Then display B never controls the machine
    And display A stays connected

  Scenario: Replacing a display via the steam-switch pairing window
    Given the controller is bonded to display A and display A is powered off
    When I power on the controller while holding the steam switch on
    And I power on a new display B
    Then display B pairs and controls the machine
    And after display A is powered on again it is not able to control the machine

  Scenario: Controller power cycle keeps the bond
    Given a paired machine
    When I power cycle only the controller
    Then the display reconnects within 15 s without a pairing window

  Scenario: Display power cycle keeps the bond
    Given a paired machine
    When I power cycle only the display
    Then it reconnects within 15 s and restores the selected profile and mode

  Scenario: Timezone and clock
    When I set timezone "America/New_York" and 12 h clock
    Then the Standby clock shows the correct local time in 12 h format after NTP sync
    When I set 24 h clock
    Then the Standby clock switches to 24 h format

  Scenario Outline: Startup mode
    Given startup mode "<mode>"
    When I power cycle the machine
    Then after connecting the display is in "<result>"

    Examples:
      | mode    | result  |
      | Standby | Standby |
      | Brew    | Brew    |

  Scenario: Seed profiles on a fresh install
    Then the Profiles page lists the stock profiles (for example: 9 bar, Adaptive, Flush, Lever, LM Leva)
    And a profile is selected and at least one favourite exists
