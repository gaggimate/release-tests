Feature: Calibration and tuning

  Scenario: PID autotune succeeds
    Given the machine is cold (below 40 °C)
    When I start a PID autotune from the Calibration tab with the default duration and my heater wattage
    Then the machine switches to Standby and shows "Autotuning"
    And the web UI shows progress
    And on success new Kp, Ki, Kd and Kf values are saved and shown
    And a following brew holds temperature within ±1 °C at the target

  Scenario: PID autotune timeout keeps the old PID
    Given a PID value I noted
    When an autotune times out or is cancelled by a power cycle of the controller
    Then the failure card is shown and the PID value is unchanged

  Scenario: Manual PID entry
    When I enter a PID string with 4 values and save
    Then the controller log shows the new gains after reconnect
    When I enter an invalid PID string
    Then it is rejected and the old value is kept

  Scenario: Temperature offset
    Given temperature offset +2 °C
    Then the displayed temperature and the target are adjusted consistently and the boiler does not overshoot

  @pro
  Scenario: Pump flow calibration
    Given a Pro board and a scale
    When I run the pump flow calibration
    Then a temporary "[Calibration]" profile is created, selected and brewed
    And the pump model coefficients are saved at the end
    And the previously selected profile is selected again
    And the temporary profile is deleted
    And flow profiles now track target flow better than before (compare a 2 ml/s shot)

  @pro
  Scenario: Pump flow calibration is interrupted
    When I cancel the calibration midway (stop button or controller power loss)
    Then the previous profile is selected again and no "[Calibration]" profile remains
    And the pump coefficients are unchanged

  @pro
  Scenario Outline: Pressure sensor rating
    Given a <rating> bar pressure transducer and the sensor rating set to <rating>
    When I brew a 9 bar profile against a reference gauge
    Then the displayed pressure matches the gauge within ±0.3 bar

    Examples:
      | rating |
      | 12     |
      | 16     |
      | 20     |

  @pro
  Scenario: Gear pump settings
    Given the gear pump addon
    When I change commutation, convergence and integral gains, max pump power and slip coefficients
    Then the values reach the controller (check the log) and brewing still works
    And with all slip coefficients at 0 behaviour matches the previous release
