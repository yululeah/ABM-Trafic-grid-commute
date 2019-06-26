# Trafic-grid-commute
## WHAT IS IT?
The Commute behavior, Traffic Congestion, and Parking model simulates traffic moving in a simplified city grid with several perpendicular one-way streets that forms an intersection. It allows you to control global variables, such as the parking ratio and the number of people, and explore traffic dynamics, particularly traffic congestion measured by average speed and average waiting time for parking, which add to the total utility.
This model gives the cars destinations (house or work) to investigate the traffic flow of commuting people. The agents in this model use goal-based and adaptive cognition.

## HOW IT WORKS

Each time step, the cars face the next destination they are trying to get to (work or house) and attempt to move forward at their current speed and keep a safety speed. If their current distance to the car directly in front of them is less than their safety distance, they decelerate. If the distance is larger than safety distance, they accelerate. If there is a red light or a stopped car in front of them, they stop. 

In each cycle, each car will be assigned one destination. Traffic lights at the intersection will automatically change at the beginning of each cycle.

Once the car parked, it will take 20 seconds to get into the front door of a company and then the car dispears from the map, at the same time a parking spot is empty for the next one. If a car driving through its destination, however the parking spot is not empty, it will keep driving around until spot opens up.

## It was modifed based on "self-driving-vehicles-master",which is avilabel in https://github.com/zchen09/self-driving-vehicles.git.
Thanks a lot!
