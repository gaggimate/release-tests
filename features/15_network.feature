Feature: Network resilience
  The network watchdog probes the gateway every 2 s: after 15 s dead it reconnects Wi-Fi, after 30 s dead it reboots,
  but only with more than 15 min uptime and more than 5 min in Standby. The STA watchdog forces a reconnect after 20 s down.

  Scenario: Router reboot while idle
    Given the display on home Wi-Fi
    When I reboot the router
    Then the display rejoins within 2 minutes without rebooting itself
    And the web UI, mDNS and integrations work again

  @critical
  Scenario: Router reboot during a brew
    Given a brew is running
    When the router goes down
    Then the brew completes normally (brewing never depends on Wi-Fi)
    And the display does not reboot during the brew

  Scenario: Watchdog reboot conditions
    Given uptime over 15 minutes and Standby for over 5 minutes
    When the gateway stops answering but Wi-Fi stays associated for over 30 s
    Then the display reboots once and recovers
    Given uptime under 15 minutes
    Then it does not reboot for the same condition

  Scenario: Wi-Fi out of range for a long time
    When the access point is off for 1 hour
    Then the display keeps controlling the machine, retries with backoff and rejoins when the AP returns

  Scenario: Wi-Fi SSID changed
    Given the configured network no longer exists
    Then the display offers its own AP so I can enter new credentials

  Scenario: Captive portal detection
    Given a phone joined to the display's AP
    Then the phone's captive portal sheet opens the web UI

  Scenario: No Internet but local Wi-Fi works
    Given the router has no Internet uplink
    Then the local web UI works, the update check fails quietly, and NTP-dependent features (auto-wakeup) wait

  Scenario: OTA download on a slow link
    Given the link is throttled to 20 kB/s
    When I update the display
    Then the download finishes (resuming if needed) and the update applies, without the task watchdog rebooting the device

  Scenario: Web UI during Wi-Fi reconnect
    When Wi-Fi drops and reconnects while the dashboard is open
    Then the dashboard reconnects its WebSocket on its own
