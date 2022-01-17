# Communication Strategies for Model-Based Agents With Epidemic Algorithms in Decentralized Transportation Scenarios

This artifact contains the models and measurement for a study where we investigate centralized (blackboard and directed updates to all other agents) and epidemic (anti-entropy agents with 1-to-1 adjacent communication and push/pull exchange, anti-entropy agents with 1-to-n adjacent communication and push/pull exchange, and agents with 1-to-n adjacent communication based on rumor spreading) communication strategies for model-based agents (MBA) in a transportation setting without central control and with stochastic disturbances.  
We conduct experiments about the delivery of randomly produced items in this setting and compare the performance and communication behaviour of all strategies. 
Overall, we want to provide insights on building and improving the communication among agent populations to achieve desired emergences in industrial transportation settings that avoids centralized components

<img src="https://github.com/wintechis/Model_Based_VS_SRA_Stigmergy/blob/main/setup.png" alt="fig1" width="250"/>
Fig. 1 - Initial setup for scenario A: 17 transporters, 4 stations, shop floor size 25x25


<br>We simulate a shop floor (e.g. Fig. 1 for scenario A) that contains four major components (Fig. 2): a fixed number of stations and transporters, a varying amount of colored items, and a discrete, quadratic grid where transporters move. 
Distinct colored items are randomly produced by stations and have to be transported to another designated station of matching color. Transporters shall fulfill this transportation task.  
Each station can hold at most one item and waits until a transporter picks up the item before another one is produced. Transporters can carry only one item at a time. 
As disturbance, we introduced fixed periods after which the stations' colors are randomly swapped. We varied these disturbances to occur every {50cyc,100cyc,250cyc,500cyc} cycles. Agents' perception is limited to their adjacent fields.

<img src="https://github.com/wintechis/Model_Based_VS_SRA_Stigmergy/blob/main/BasicScenarioAnnotated.PNG" alt="fig2" width="250">
Fig 2 - Shop floor components: A) Green station with pink item, B) Transporter with blue item, C) empty transporter, D) empty pink station. All components are located on the shop floor's tiles (black and white grid).

We studied two scenarios:
- Scenario A: 17 transporters, 4 stations, shop floor size 25x25
- Scenario B: 64 transporters, 16 stations, shop floor size 50x50

## Contents
/images - image files that display an overview of scenario A's task performance and communication

/models - contains agent behaviour and environment for experiments
  - /ShopFloor_Grid.gaml - defines shop floor and grid
  - /Station_Item.gaml - defines behaviour of stations and items
  - /Residue_Traffic_Delay/ - contains model-based agent behavior and measurements
    - MBA_AE (AE): anti-entropy agents - for push / pull and 1-to-1 / 1-to-n communication (configurated via variable 'communication_mode')
    - MBA_Blackboard (BB): agents communicating via a centralized, monolithic blackboard
    - MBA_Direct_Mail (DM): agents using directed messages to communicate directly with every other member of the population
    - MBA_NonCom (NonCom): agents that do not communicate 
    - MBA_Rumor (RUMORk): agents that use gossiping to communicate and ceise attemps when they fail "k" times (limit "k" can be configured in the model)
  - /simulation_results/[knowledge,performance]/*.csv - raw results per model, abbreviation in names as above. File endings suggest the size of the scenario (_25 and _50 for A and B).
  - /simulation_results
    - /_complete/*.ods - consolidated tables of all measured values of task performance and communication, including charts for scenarios A and B
    - /AE_extended/* - measures and tables for extended anti-entropy experiment with 32 and 64 transporters in scenario A

## Setup for [GAMA](https://gama-platform.github.io/)

- Install GAMA according to these [steps](https://gama-platform.github.io/wiki/Installation)
  -  [System Requirements](https://gama-platform.github.io/wiki/Installation#system-requirements)
- [Import the project into your workspace](https://gama-platform.github.io/wiki/ImportingModels)
- Select the model you are interested in from /models/Residue_Traffic_Delay/
- Run the included experiments:
  - "[Modelname]": run a simulation of the model with a GUI, an animated shop floor and charts
  - "No_Charts": same as above with shop floor tiles names, but without charts
  - "Performance/Knowledge": run a batch of simulations, pre-set to 5k cycles and 20 repetitions. Results are saved under the above given names in /Residue_Traffic_Delay/simulation_results/[knowledge,performance]/ ; size of shopfloor can be configured via parameters (see GAMA documentation).
- Note that the simulation results are saved in separate files and have to be put externally together, e.g. to be displayed in a chart
