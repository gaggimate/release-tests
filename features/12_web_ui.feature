Feature: Web UI
  Preact app embedded in the display firmware, talking over the /ws WebSocket and /api HTTP endpoints.

  Background:
    Given the web UI is open at http://<hostname>.local/

  # ---------------------------------------------------------------- Browsers

  @matrix
  Scenario Outline: Web UI loads and works in each browser
    Given "<browser>" on "<device>"
    Then the dashboard loads within 3 s with live temperature
    And navigation between Dashboard, Profiles, History, Analyzer, Statistics and Settings works
    And the layout has no horizontal scroll on phones

    Examples:
      | browser | device          |
      | Chrome  | desktop         |
      | Firefox | desktop         |
      | Safari  | macOS           |
      | Safari  | iPhone          |
      | Chrome  | Android phone   |

  Scenario: Web UI served after OTA without a stale cache
    Given the browser had the previous release's UI cached
    When the display is updated and I reload
    Then the new UI loads (no mixed old/new assets, no blank page)

  # ---------------------------------------------------------------- Dashboard

  @smoke
  Scenario: Live dashboard during a brew
    When I start a brew
    Then the chart draws pressure, flow, temperature, pump power and weight in real time
    And the metrics update at least twice per second
    And the Recent Shots card shows the new shot after it finishes, with "Open in Analyzer"

  Scenario Outline: Dashboard view modes
    When I switch the dashboard to "<mode>"
    Then the panels for "<mode>" are shown and the choice persists after reload

    Examples:
      | mode     |
      | Simple   |
      | Advanced |
      | Custom   |

  Scenario: Dashboard settings
    When I reorder panels, hide the Water Tank panel, change chart height and recent shot count
    Then the dashboard reflects each change and they persist in this browser only

  Scenario: Mode selector locked when not ready
    Given the controller is disconnected
    Then the mode selector is disabled

  Scenario: Two browsers at once
    Given the dashboard open in two browsers
    When I change the mode in one
    Then the other updates within 2 s and neither disconnects

  Scenario: Many WebSocket clients
    Given 5 browser tabs on the dashboard during a brew
    Then the display stays responsive and the brew is unaffected

  # ---------------------------------------------------------------- History

  @smoke
  Scenario: Shot history
    Given at least 5 shots
    Then the list shows each shot with profile, duration, volume and date
    When I filter by "rated", sort by rating and search by profile name
    Then the results are correct
    When I add notes (rating, dose in/out, grind, beans, taste, text) to a shot
    Then they persist after reload and reboot

  Scenario: Delete a shot
    When I delete a shot
    Then it disappears from the list and the analyzer, and its notes are removed

  Scenario: Export a shot and upload to visualizer.coffee
    When I export a shot as JSON
    Then the file downloads and re-imports into the analyzer
    When I upload a shot to visualizer.coffee with valid credentials
    Then it appears on visualizer.coffee with the correct curves

  Scenario: History while an update is running
    Given an update is running
    Then history requests return a "busy" state (HTTP 503) and the page shows a message rather than an empty list

  # ---------------------------------------------------------------- Analyzer and statistics

  Scenario: Analyzer
    When I open a shot in the analyzer
    Then the phases, exit reasons, weight rate and target matching are shown
    When I compare it with a second shot
    Then both overlay correctly
    When I export a replay video and an image
    Then the files download and play/open

  Scenario: Analyzer browser library
    When I import shots and profiles into the browser library and reload
    Then they are still in IndexedDB and can be exported again

  Scenario: Statistics
    Given 20 shots across 3 profiles over several days
    Then the summary cards, trend chart, heatmap and per-profile tables are populated
    And an advanced search such as a profile name and a date range narrows the results correctly

  # ---------------------------------------------------------------- Settings

  @smoke
  Scenario: Every settings field round-trips
    When I change one value in every section of General, Machine and Plugins and save
    And I reload the page and reboot the display
    Then every changed value is shown as saved
    And values given in seconds in the UI are stored and shown back in seconds

  Scenario: Save and restart
    When I click "Save and restart"
    Then the display reboots and the web UI reconnects on its own

  Scenario: Settings export and import between devices
    When I export settings from device A and import them into device B
    Then B has A's settings except Wi-Fi password handling as documented, and B still reaches its network

  Scenario: Brightness and theme
    When I change main brightness, standby brightness, standby dim timeout and the display theme
    Then the display applies them immediately (brightness) or after the documented action (theme)

  Scenario: Web theme
    When I switch the web theme between System, Light, Dark, Coffee and Nord
    Then all pages stay readable with no hard-coded colours

  Scenario: Download support data
    When I click "Download support data"
    Then a file with logs and, if present, the core dump downloads

  Scenario: Invalid input
    When I enter out-of-range values (flush 90 s, negative temperatures, AP password of 3 characters)
    Then they are clamped or rejected with a message, never stored as-is
