Feature: Physical brew and steam switches
  The controller reports raw switch edges. The display maps button 0 (brew), 1 (steam) and 2 (both within 200 ms)
  to an action: none, brew, steam, water, flush or a specific profile. Long press is 400 ms.

  Scenario Outline: Latching switches (stock Gaggia)
    Given the "momentary buttons" setting is off and the default mapping brew/steam/water
    When I <action>
    Then <result>

    Examples:
      | action                                   | result                                                       |
      | turn the brew switch on                  | a brew starts                                                |
      | turn the brew switch off during a brew   | the brew stops                                               |
      | turn the steam switch on                 | the machine enters Steam mode                                |
      | turn the steam switch off                | the machine leaves Steam mode                                |
      | turn both on within 200 ms               | the combo action (water) runs                                |

  Scenario Outline: Momentary buttons
    Given the "momentary buttons" setting is on
    When I <action>
    Then <result>

    Examples:
      | action                                  | result                                              |
      | press brew once                         | a brew starts                                       |
      | press brew again during the brew        | the brew stops                                      |
      | hold brew for more than 400 ms          | a flush starts                                      |
      | press steam                             | Steam mode toggles                                  |

  Scenario: Map a button to a profile
    Given the brew button mapped to profile "Lever"
    When I press brew
    Then "Lever" is selected and a brew starts with it

  Scenario: Map a button to flush with hold-to-flush
    Given the steam button mapped to flush and flush duration 0
    When I hold steam for 5 s
    Then the flush runs for about 5 s

  Scenario: Map a button to none
    Given the steam button mapped to "none"
    When I press steam
    Then nothing happens

  Scenario: Steam switch left on at boot (latching)
    Given latching switches and the steam switch on
    When the machine powers up
    Then "Steam switch is on" appears
    And brewing asks for confirmation only if the warning is set to Error level

  @critical
  Scenario: Steam switch held at controller power-on opens the pairing window
    Given latching switches
    When I power on the controller with the steam switch on
    Then the controller accepts a new display for pairing
    And no heating starts until a display connects

  Scenario: Buttons during OTA or protocol mismatch
    Given an update is running or there is a protocol mismatch
    When I press any physical switch
    Then nothing starts

  Scenario: Buttons in Standby
    Given the machine is in Standby
    When I turn the brew switch on
    Then the machine wakes and brews, or wakes only (record which, and compare with the previous release)
