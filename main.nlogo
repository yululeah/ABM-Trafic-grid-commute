globals
[
  grid-x-inc               ;; the amount of patches in between two roads in the x direction
  grid-y-inc               ;; the amount of patches in between two roads in the y direction
  acceleration             ;; the constant that controls how much a car speeds up or slows down by if
  phase                    ;; keeps track of the phase

  num-parking-spots        ;; tracks total number of parking spots

  ;; lists that hold parking spots for each location
  list-parking-house
  list-parking-work
  list-parking-spot

  ;; variables for agents
  total-num-cars
  num-HVs
  num-HV-people           ;;one passenger in a car

  ;; amount of goals successfully met
  num-goals-met

  ;; patch agentsets
  intersections ;; agentset containing the patches that are intersections
  roads         ;; agentset containing the patches that are roads
  work          ;; the place/parkings to go to or leave from
  house         ;; the place/parkings to go to or leave from
  goal-candidates ;; agentset containing the patches of 2 locations drop off and pickup spot
]

;cars is breeds of turtle
breed [ HVs HV ]  ;human-operated vehicle

turtles-own
[
  speed     ;; the speed of the turtle
  up-car?   ;; true if the turtle moves downwards, false if it turns right/left
  wait-time ;; the amount of time since the last time a turtle has moved
  goal      ;; where am I currently headed
  count-down ;; the time it spends in the parking spot
  tick-here
  from       ;; inital spot (for HVs: the location they leave parking spot from)
  goto       ;; destination (goals)
  on?        ;; if the car is running
]

patches-own
[
  intersection?   ;; true if the patch is at the intersection of two roads
  green-light-up? ;; true if the green light is above the intersection,, otherwise, false.
  my-row          ;; the row of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  my-column       ;; the column of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  my-phase        ;; the phase for the intersection. -1 for non-intersection patches.
  auto?           ;; whether or not this intersection will switch automatically.

  ;; for parking lot
  house?          ;; true is this is a parking spot for house
  work?           ;; true is this is a parking spot for work
  occupied?       ;; whether the parking spot is occupied
]

;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;

;; Initialize the display by giving the global and patch variables initial values.
;; Create num-cars of turtles if there are enough road patches for one turtle to
;; be created per road patch.

to setup
  clear-all
  setup-globals
  setup-patches  ;; ask the patches to draw themselves and set up a few variables

  ;; Make an agentset of all patches where there can be one of the two places
  ;; those patches are house, work, shop and school
  set goal-candidates (patch-set house work)

  ;; warning if there are too many cars for the road
  if (num-HVs > count roads) [
    user-message (word
      "There are too many cars for the amount of "
      "road.  Either increase the amount of roads "
      "by increasing the GRID-SIZE-X or "
      "GRID-SIZE-Y sliders, or decrease the "
      "number of cars by lowering the NUM-CAR slider.\n"
      "The setup has stopped.")
    stop
  ]

  ;; create HVs
  create-HVs num-HVs
  [
    set shape "car"
    set color yellow
    set size 1.1
    set up-car? false
    setup-cars
    ;; choose at random a location to depart
    set from one-of goal-candidates
    ;; choose at random a location to go
    set goto one-of goal-candidates with [ self != [ from ] of myself ]
    set goal goto  ;;goal is where am I currently headed
  ]

  ;; give the turtles an initial speed
  ask turtles [ set-car-speed ]
  reset-ticks
end

;; sets up the number of parking spots based on other parameters
to setup-parking-spots

  ask patches [

    if count patches with [pcolor = orange] < (parking-ratio * .01 * num-HVs) [
      if (any? neighbors with [pcolor = grey]) and pcolor != grey and pcolor != red and pcolor != green
      [set pcolor orange
       set occupied? false]
    ]
    ;; This sets up the parking spots for each location
    if (pxcor < 0 and pcolor = orange)
    [set house? true]
    if (pxcor > 0 and pcolor = orange)
    [set work? true]
  ]

  set num-parking-spots count patches with [pcolor = orange]

  ;; creates lists for parking spots of each location
  set list-parking-house patches with [house? = true]
  set list-parking-work patches with [work? = true]
  set list-parking-spot patches with [pcolor = orange]
end

;; set up our destinations (draw + set goal patches)
to setup-places
  ask patches [
  if (pxcor = 7 and pycor = 7)
   [set pcolor black
    set plabel "work"]
  if (pxcor = -7 and pycor = -7)
    [set pcolor yellow
    set plabel "house"]
  if (pxcor = 7 and pycor = -7)
    [set pcolor black
    set plabel "work"]
  if (pxcor = -7 and pycor = 7)
    [set pcolor yellow
    set plabel "house"]
  ]
  ;; we are setting our goal patches for look for parking (HVs)
  set work patches with [pxcor = 10 and pycor = 0]  ;;?
  set house patches with [pxcor = -10 and pycor = 0]
end

;; Initialize the global variables to appropriate values
to setup-globals
  ;; set current-intersection nobody ;; just for now, since there are no intersections yet
  set phase 0
  set num-goals-met 0
  set total-num-cars num-people
  set num-HVs total-num-cars
  set num-HV-people num-HVs

  ;; don't make acceleration 0.1 since we could get a rounding error and end up on a patch boundary
  set acceleration 0.099
  set grid-x-inc world-width / grid-size-x   ;the amount of patches in between two roads in the x direction
  set grid-y-inc world-height / grid-size-y
end

;; Make the patches have appropriate colors, set up the roads and intersections agentsets,
;; and initialize the traffic lights to one setting
to setup-patches
  ;; initialize the patch-owned variables and color the patches to a base-color
  ask patches [
    set intersection? false
    set auto? false
    set green-light-up? true
    set my-phase -1
    set pcolor brown + 3
  ]
  setup-places

    ;; set up new roads
  set roads patches with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) or
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]
    set intersections roads with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) and
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]
  ask roads [ set pcolor grey ]
  setup-intersections
  setup-parking-spots
end

;; Give the intersections appropriate values
;; Make all the traffic lights start off so that the lights are red
;; horizontally and green vertically.
to setup-intersections
  ask intersections [
    set intersection? true
    set green-light-up? true
    set my-phase 0
    set auto? true
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
    set-signal-colors
  ]
end

;; Initialize the turtle variables to appropriate values and place the turtle on an empty road patch.
to setup-cars  ;; turtle procedure
  set speed 0
  set wait-time 0
  set on? true  ;running
  put-on-empty-road ;; places cars on empty spot on road
  ifelse intersection? [
    let temp random 2
    ifelse temp = 0
      [ set up-car? true ] ;; randomly sets some of cars to be going vertically and some to go horizontally
      [ set up-car? false ]

  ]
  [
    ; if the turtle is on a vertical road (rather than a horizontal one)
    ifelse (floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0)
      [ set up-car? true ]
      [ set up-car? false ]
  ]

  ; sets the cars direction (north or east)
  ifelse up-car?
    [ set heading 0 ] ;north
    [ set heading 90 ] ;east

end

;; Find a road patch without any turtles on it and place the turtle there.
to put-on-empty-road  ;; turtle procedure
  move-to one-of roads with [ not any? turtles-on self ]
end


;;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Run the simulation
to go

  ;; sets up traffic lights
  set-signals

  ;; specifc tasks for HVs
  ask-concurrent HVs [

  ifelse reachDestination = false
  ;if this is not destination
  [
      set on? true ;running
      set-car-dir
      set-safety-distance-HV
      fd speed
      record-data     ;; record data for plotting
  ]
 ;if this is destination
    [
    ; check if the car is parked in lot or not
     ;if it is parked
     ifelse on? = false
    [
      ;if the parking time is up
      ifelse count-down <= 0   ;;parking time count-down
      [ move-to-company ]   ;;after 20s, the car enter the company and disppear
      ;if parking time not up
      [decrement-counter]  ;;continue counting down

    ]
    ; the car is not parked
    [
       ;; create temporary variable for current location and look for parking spot next to current location
      let cur-spot find-spot
      let x [pxcor] of cur-spot
      let y [pycor] of cur-spot

        ;; first, a hv looks for parking spots, and report whether it found one or not
      ifelse x != 0 and y != 0
      ;the hv found a spot
      [
        move-to-spot x y ; hv will move to open parking spot
        set-counter ;; sets parking count down
      ]
      ;the car does not have a parking spot
      [
        go-around ;; keep driving around until spot opens up
      ]
    ]
    ]
  ]

  next-phase ;; update the phase and the global clock
  tick
end

;; have the traffic lights change color if phase equals each intersections' my-phase
to set-signals
  ask intersections with [ auto? and phase = floor ((my-phase * ticks-per-cycle) / 100) ] [
    set green-light-up? (not green-light-up?)
    set-signal-colors
  ]
end

;; This procedure checks the variable green-light-up? at each intersection and sets the
;; traffic lights to have the green light up or the green light to the left.
to set-signal-colors  ;; intersection (patch) procedure
    ifelse green-light-up? [
      ask patch-at -1 0 [ set pcolor red ]
      ask patch-at 0 -1 [ set pcolor green ]
    ]
    [
      ask patch-at -1 0 [ set pcolor green ]
      ask patch-at 0 -1 [ set pcolor red ]
    ]
end

to set-speed [ delta-x delta-y ] ;; turtle procedure
  ;; get the turtles on the patch in front of the turtle
  let turtles-ahead turtles-at delta-x delta-y

  ;; if there are turtles in front of the turtle, slow down
  ;; otherwise, speed up
  ifelse any? turtles-ahead [
    ifelse any? (turtles-ahead with [ up-car? != [ up-car? ] of myself ]) [
      set speed 0
    ]
    [
      set speed [speed] of one-of turtles-ahead
      slow-down
    ]
  ]
  [ speed-up ]
end

;; set the turtles' speed based on whether they are at a red traffic light or the speed of the
;; turtle (if any) on the patch in front of them
to set-car-speed  ;; turtle procedure
  ; if at red light, stop
  ifelse pcolor = red [
    set speed 0
  ]
  [
    ; if not at red light, go
   ifelse up-car?
    [set-speed 0 -1 ]
    [set-speed 1 0 ]
  ]
end

;; sets direction of car
to set-car-dir

  ; if at an intertersection
  if intersection? [
    ; if driving north and at intersection, will randomly decide if wants to turn right
    ifelse up-car?
    [
      let temp random 2
      ifelse temp = 0
      [ set up-car? true ] ; turn left
      [ set up-car? false ] ; turn right
    ]
    [; if driving east and at intersection, will randomly decide if wants to turn left
      let temp random 2
      ifelse temp = 0
      [ set up-car? true ] ; turn left
      [ set up-car? false ] ; turn right
    ]
  ]

  ifelse up-car?
    [ set heading 0 ]
    [ set heading 90 ]
end

;; sets a distance that HV needs to keep from the cars in front - plan to modify this as build model
to set-safety-distance-HV
  let distance-car 1

  let one-patch (not any? turtles-on patch-ahead 1) ;;and (not any? turtles-on patch-ahead 2)
  ifelse one-patch
  [set distance-car distance-car + 1]
  [set distance-car distance-car + 0]

  let two-patches (one-patch and not any? turtles-on patch-ahead 2)
  ifelse two-patches
  [set distance-car distance-car + 1]
  [set distance-car distance-car + 0]

  let three-patches (two-patches and not any? turtles-on patch-ahead 3)
  ifelse three-patches
  [set distance-car distance-car + 1]
  [set distance-car distance-car + 0]

  ;; for HV make sure the distance in front is three
  ifelse distance-car > 3 and pcolor != red
  [speed-up]
  [ifelse distance-car < 3
    [slow-down]
    []
  ]
  ifelse distance-car = 1
  [set speed 0]
  []
end

;; decrease the speed of the car
to slow-down  ;; turtle procedure
  ifelse speed <= 0
    [ set speed 0 ]
    [ set speed speed - acceleration ]
end

;; increase the speed of the car
to speed-up  ;; turtle procedure
  ifelse speed > speed-limit
    [ set speed speed-limit ]
    [ set speed speed + acceleration ]
end

;; keep track of the amount of time a car has been stopped
;; if its speed is 0 and it is not parked
to record-data  ;; turtle procedure
  ifelse speed = 0 and on? = true [
    set wait-time wait-time + 1
  ]
  [ set wait-time 0 ]
end

;; cycles phase to the next appropriate value
to next-phase
  ;; The phase cycles from 0 to ticks-per-cycle, then starts over.
  set phase phase + 1
  if phase mod ticks-per-cycle = 0 [ set phase 0 ]
end

;; method to see if HV has reached destination
to-report reachDestination
  let reach? false
  ; 2 cases for each destination
  ; case 1
  if goto = one-of house [
    let x [pxcor] of patch-here
    let y [pycor] of patch-here
    ;; checks for range of road where an HV can park for their destination
    if x >= -18 and x <= -1 [
      set reach? true
    ]
  ]
  ;case 2
  if goto = one-of work [
    let x [pxcor] of patch-here
    let y [pycor] of patch-here
    if x <= 18 and x >= 1 [
      set reach? true
    ]
  ]

  report reach?
end

;; if hv has found an open spot, move to that spot to park
to move-to-spot [x y]
    setxy x y
    set on? false ;; turns off car while parked

  ;; changes the patch of the parking spot to be occupied
    ask patches with [pxcor = x and pycor = y] [
      set occupied? true
    ]
  ; updates number of goals met
    set num-goals-met num-goals-met + 1

end

;; reports if a parking spot has been found
to-report find-spot
  let found false
  let spot one-of patches with [pxcor = 0 and pycor = 0]

    ; case 1: checks the two patches between the road for house parking spots
    if goto = one-of house [
      let spot1 one-of neighbors4 with [ pxcor < 0 ]
        if member? spot1 list-parking-house [
          set spot spot1
          set found not [occupied?] of spot1 ; checks if parking spot is occupied, if not occupied sets found spot to true
        ]
      ]
   ;case 2: checks for open parking spots for work parking
   if goto = one-of work [
      let spot1 one-of neighbors4 with [ pxcor > 0 ]

      if member? spot1 list-parking-work [
          set spot spot1
          set found not [occupied?] of spot1
        ]
    ]
; if found a parking spot that is not occupied, it will report that spot
; if occupied it will return x = 0 and y = 0
  ifelse found [report spot]
  [report one-of patches with [pxcor = 0 and pycor = 0]]
end

;; if the HV didn't find a spot, keep driving until find one (may modify this later to take into account our safety distances)
to go-around
  if count [turtles-here] of patch-ahead 1 = 0 [fd 1]
end

;; if parking time is up, move back to the road
to move-to-company

  ;; checks all parking lists to find which destination it is parked at
    if member? patch-here list-parking-work
    [
      ask patch-here [set occupied? false]
      die
      set num-HVs num-HVs - 1
    ]

    if member? patch-here list-parking-house
    [
      ask patch-here [set occupied? false]
      die
      set num-HVs num-HVs - 1
    ]
end

;; sets up parking count down
to set-counter
    set count-down 20 ;; set parking time
end

to decrement-counter
    set count-down count-down - 1
end


; Copyright 2019 Lu Yu
; See Info tab for documentation.
@#$#@#$#@
GRAPHICS-WINDOW
35
20
568
554
-1
-1
15.0
1
20
1
1
1
0
1
1
1
-17
17
-17
17
1
1
1
ticks
30.0

PLOT
1040
405
1258
580
Average Wait Time of Cars
Time
Average Wait
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [wait-time] of turtles"

PLOT
820
405
1036
580
Average Speed of Cars
Time
Average Speed
0.0
100.0
0.0
1.0
true
false
"set-plot-y-range 0 speed-limit" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [speed] of turtles"

SLIDER
700
15
880
48
num-people
num-people
1
400
100.0
1
1
NIL
HORIZONTAL

PLOT
600
405
814
580
Stopped Cars
Time
Stopped Cars
0.0
100.0
0.0
100.0
true
false
"set-plot-y-range 0 total-num-cars" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [speed = 0]"

BUTTON
600
65
685
110
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
600
15
684
60
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
890
55
1035
88
speed-limit
speed-limit
0.1
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
890
15
1035
48
ticks-per-cycle
ticks-per-cycle
1
100
73.0
1
1
NIL
HORIZONTAL

SLIDER
700
55
880
88
parking-ratio
parking-ratio
0
200
73.0
1
1
%
HORIZONTAL

MONITOR
700
90
885
135
Number of Parking Spots
num-parking-spots
0
1
11

PLOT
600
140
1250
395
Number of Goals Met
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot num-goals-met"

SLIDER
1060
15
1232
48
grid-size-x
grid-size-x
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
1060
55
1232
88
grid-size-y
grid-size-y
0
10
5.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## ACKNOWLEDGMENT

This model is partially based on the example from Chapter Five of the book "Introduction to Agent-Based Modeling: Modeling Natural, Social and Engineered Complex Systems with NetLogo", by Uri Wilensky & William Rand.

* Wilensky, U. & Rand, W. (2015). Introduction to Agent-Based Modeling: Modeling Natural, Social and Engineered Complex Systems with NetLogo. Cambridge, MA. MIT Press.

## WHAT IS IT?

The Commute behavior, Traffic Congestion, and Parking model simulates traffic moving in a simplified city grid with several perpendicular one-way streets that forms an intersection. It allows you to control global variables, such as the parking ratio and the number of people, and explore traffic dynamics, particularly traffic congestion measured by average speed and average waiting time for parking, which add to the total utility.

This model gives the cars destinations (house or work) to investigate the traffic flow of commuting people. The agents in this model use goal-based and adaptive cognition.

## HOW IT WORKS

Each time step, the cars face the next destination they are trying to get to (work or house) and attempt to move forward at their current speed and keep a safety speed. If their current distance to the car directly in front of them is less than their safety distance, they decelerate. If the distance is larger than safety distance, they accelerate. If there is a red light or a stopped car in front of them, they stop. 

In each cycle, each car will be assigned one destination. Traffic lights at the intersection will automatically change at the beginning of each cycle.

Once the car parked, it will take 20 seconds to get into the front door of a company and then the car dispears from the map, at the same time a parking spot is empty for the next one. If a car driving through its destination, however the parking spot is not empty, it will keep driving around until spot opens up.

## HOW TO USE IT

Change any setting that you would like to change. Press the SETUP button.

Start the simulation by pressing the GO button. 

### Buttons

SETUP --  sets up patches and parking spots for each destination. Parking spots are randomly allocated based on parking ratio. 
GO -- runs the simulation indefinitely. Cars travel from their homes to their work.

### Sliders

SPEED-LIMIT -- sets the maximum speed for the cars.

NUM-PEOPLE -- sets the number of cars in the simulation.

PARKING-RATIO -- percentage of HVs that have a parking spot

TICKS-PER-CYCLE -- sets the number of ticks that will elapse for each cycle. This has no effect on manual lights. This allows you to increase or decrease the granularity with which lights can automatically change.

### Monitors

A number of monitors display a number of variables including total number of cars and total number of parking spots at all four locations.

### Plots

NUMBER OF GOALS MET -- displays the cumulative number of goals met by HVs. For HVs, the goal is to find a spot and park once they reach destination.

STOPPED CARS -- displays the number of stopped cars over time.

AVERAGE SPEED OF CARS -- displays the average speed of cars over time (excluding parked cars).

AVERAGE WAIT TIME OF CARS -- displays the average time cars are stopped over time (excluding parked cars).
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 180 15 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 285 165 285 225 285 225 15 180 15
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
