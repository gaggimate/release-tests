Feature: Grind mode and Smart Grind
  Grind mode shows only when Smart Grind is enabled or the alt relay function is "Grind".
  Smart Grind switches a Tasmota plug over HTTP (/cm?cmnd=Power On|off).

  Scenario: Grind mode hidden when nothing can grind
    Given alt relay function "None" and Smart Grind disabled
    Then the menu and the web mode selector show no Grind entry

  @smoke
  Scenario: Timed grind on the alt relay
    Given alt relay function "Grind" and grind time 10 s
    When I start a grind
    Then the alt relay is on for 10 s ±0.2 s

  Scenario: Grind by weight with a scale
    Given volumetric grind on, grind target 18 g, a scale connected with an empty cup
    When I start a grind
    Then the scale is tared twice and the grind stops near 18 g (predictive, grind delay adjusted)

  Scenario: Grind target limits
    When I adjust the grind time target
    Then it stays between 5 s and 300 s in 1 s steps
    When I adjust the grind weight target
    Then it stays between 5 g and 250 g in 0.5 g steps

  Scenario: Stop a grind early
    When I stop a grind after 3 s
    Then the relay switches off immediately

  Scenario Outline: Smart Grind modes with a Tasmota plug
    Given Smart Grind enabled with the Tasmota IP and mode "<mode>", saved and restarted
    When I run a 5 s grind
    Then the plug <behaviour>

    Examples:
      | mode                          | behaviour                                             |
      | Turn off at target            | is switched off at the end                            |
      | Off, then on again            | switches off at target and back on after about 0.5 s  |
      | On at start, off at target    | switches on at start and off at the end               |

  Scenario: Smart Grind requires a restart to take effect
    When I enable Smart Grind and save without restarting
    Then the Grind mode appears only after a restart (documented behaviour)

  Scenario: Smart Grind plug unreachable
    Given the Tasmota IP points to a device that is offline
    When I run a grind
    Then the display does not freeze and the grind timer still ends
    And the error is logged

  Scenario: Legacy Smart Grind toggle migrates
    Given a baseline with the old Smart Grind toggle enabled
    When I upgrade to the RC
    Then Smart Grind mode is "Off, then on again"
