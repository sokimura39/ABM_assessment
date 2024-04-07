globals
[
  ; floor-area-percentage
  num-units ; number of units, calculated from floor-area-percentage
  ; sun-height ; height of sun

  ; ranges
  ; open-range ; range to check for open space
  ; max-view ; maximum of view

  ; weights for calculating amenity
  ; light-weight
  ; view-weight
  ; open-weight
  ; price-weight

  ; amenity-threshold ; people decide to move if amenity below this threshold
  ; selfishness - the ratio of which they only care about themselves, and not about other people's hate

  ; group of patches
  ground ; patches on the ground
  above-ground ; patches above ground
]

breed [dummies dummy] ; just for dummy turtles using in-cone

turtles-own
[
  amenity
  hate ; loss of amenity caused by you being there
  net-amenity
  is-top? ; check if top or not
]

patches-own
[
  ; classification of ground
  area-type
  building-height
  num-neighbours

  ; properties of above ground
  price
  shadow
  view-north
  view-south
  open-space
  patch-amenity
  patch-hate ; the amount of hate (loss in amenity) if added there
  patch-net-amenity ; amenity considering externality

  is-buildable? ; whether it doesn't float

]

;; ----- initialisation -----
to setup
  ca
  reset-ticks
  setup-globals
  setup-patches
  setup-turtles

  ; update status for patches
  classify-ground
  update-patch-amenity

  ; calculate amenity
  calculate-amenity

  ; visualisation
  visualise
end

;; set up global variables
to setup-globals
  ; set number of units
  set num-units floor (world-width * floor-area-percentage / 100)

  ; set ground and above ground
  set ground patches with [pycor = -1]
  set above-ground patches with [pycor >= 0]
end

;; initialise patches
to setup-patches
  ; patches above ground
  ; no area type, price according to height
  ask above-ground
  [
    set area-type "none"
    set price (pycor + 1)
    set shadow 0
    set is-buildable? false
    set patch-amenity -1
    set patch-hate -1
    set patch-net-amenity -1
    set building-height 0
    set num-neighbours 0
  ]
  ; ground patches
  ; set initial type to open
  ask ground
  [
    set area-type "open"
    set price -1
    set shadow -1
    set is-buildable? false
    set patch-amenity -1
    set patch-hate -1
    set patch-net-amenity -1
    set building-height 0
    set num-neighbours 0
  ]
end

;; initialise turtles
to setup-turtles
  ; create turtles
  crt num-units
  [
    set shape "circle"
    setxy random-pxcor max-pycor
    set is-top? false
    set amenity 0
  ]
  ask turtles
  [
    let candidates patches with [(pxcor = [xcor] of myself) and (pycor >= 0) and (not any? turtles-here)]
    move-to min-one-of candidates [pycor]
  ]
  ask turtles
  [
    set heading 0
    if (not any? turtles-on patch-ahead 1)
    [ set is-top? true ]
  ]

end

;; ----- simulation -----
to go
  clear-drawing
  move-units
  classify-ground
  update-patch-amenity
  calculate-amenity
  visualise
  tick
end

;; move turtles around - 1 at a time
to move-units
  ; ask the most unhappy turtle

  let moving-candidate one-of (min-n-of 5 turtles [net-amenity])

  ask moving-candidate
  [
    ; make a list of turtles above you
    let current-above (turtles with [(xcor = ([xcor] of myself) and ycor > [ycor] of myself)])

    ; move to new x position if there are better options
    let new-position-candidates (patches with [(is-buildable? = true) and (pxcor != [xcor] of myself)])

    ; exclude cells where there are already turtles
    set new-position-candidates (new-position-candidates with [not any? turtles-here])

    if (max [patch-net-amenity] of new-position-candidates > net-amenity)
    [
      let new-position (max-one-of new-position-candidates [patch-net-amenity])

      ; push up the ones above your new position
      let new-above (turtles with [(xcor = ([pxcor] of new-position) and ycor >= [pycor] of new-position)])
      if (any? new-above)
      [
        ask new-above
        [ set ycor (ycor + 1) ]
      ]

      ; move to new position
      pd
      move-to new-position
      pu

      ; shift down the ones above the old position
      if (any? current-above)
      [
        ask current-above
        [ set ycor (ycor - 1) ]
      ]
    ]
  ]


end

;; analyse ground
to classify-ground
  ask ground
  [
    let building-turtles turtles with [xcor = ([pxcor] of myself)]
    ifelse any? building-turtles
    [
      set area-type "built"
      set building-height count building-turtles
    ]
    [ set area-type "open"]
  ]

  ; count neighbours
  ask ground
  [
    ; reset neighbours
    set num-neighbours 0
    foreach (range (-1 - open-range) (1 + open-range))
    [ n ->
      set num-neighbours (num-neighbours + ([building-height] of (patch-at n 0)))
    ]

  ]
  ; copy for all above ground
  ask above-ground
  [
    set num-neighbours [num-neighbours] of (patch pxcor -1)
  ]

end

;; update patch characteristics
to update-patch-amenity
  ; reset amenity and hate
  ask above-ground
  [
    set patch-amenity 0
    set patch-hate 0
  ]

  ; reset light
  ask above-ground
  [ set shadow 0 ]
  ; ask turtles to draw shadow
  ask turtles
  [
    set heading (180 - ((90 - sun-height) / 2))
    ask above-ground in-cone 100 (90 - sun-height) with [pxcor != [xcor] of myself]
    [
      set shadow (shadow + 1)
    ]
    ; reset the heading back to 0
    set heading 0
  ]

  ; set buildable
  ask above-ground
  [
    ; reset buildable
    set is-buildable? false
    ; buildable if: just above ground or something exists just below
    if ((pycor = 0) or (any? turtles-on (patch pxcor (pycor - 1))))
    [ set is-buildable? true ]
  ]

  ; update buildable
  ask above-ground with [is-buildable? = true]
  [
    ; check view
    ; set view to max
    set view-north max-view
    set view-south max-view

    ; check from max to 0 and update to smaller number if there are any patches
    foreach (range max-view 0 -1)
    [ n ->
      if any? turtles-at n 0
      [ set view-north (n - 1) ]
      if any? turtles-at (- n) 0
      [ set view-south (n - 1) ]
    ]

    ; check open space
    set open-space 0
    foreach (range (-1 - open-range) (1 + open-range))
    [ n ->
      if ([area-type] of patch-at n (-1 - pycor) = "open")
      [
        ; add open-space variable
        set open-space (open-space + 1)
      ]
    ]
    ; update patch amenity
    set patch-amenity ((- shadow) * light-weight + (view-south + view-north) * view-weight + open-space * open-weight - price * price-weight)
  ]

  ; update patch hate

  ; consider the cell just above the top of the building
  ask above-ground with [(is-buildable? = true) and (not any? turtles-here)]
  [
    ; hate from loss of view
    ; if space less than max-view, the views improve
    ifelse (view-north + view-south < max-view)
    [ set patch-hate (patch-hate + (view-north + view-south + 2) * view-weight) ]
    ; if space more than max-view, the views for others had max-view
    [ set patch-hate (patch-hate + (max-view * 2 - view-north - view-south) * view-weight) ]

    ; hate from additional shadow
    sprout-dummies 1
    [
      set heading (180 - ((90 - sun-height) / 2))
      let in-shadow count turtles in-cone 100 (90 - sun-height) with [pxcor != [xcor] of myself]
      set patch-hate (patch-hate + in-shadow * light-weight)
      ; kill dummy
      die
    ]
  ]

  ; consider the other cells - get the hate from top of building
  ask above-ground with [(is-buildable? = true) and (any? turtles-here)]
  [
    let top-patch one-of patches with [(is-buildable? = true) and (not any? turtles-here) and (pxcor = ([pxcor] of myself))]
    set patch-hate ([patch-hate] of top-patch)
    ; add the number of units above me - for pushing people up to a higher cost
    ; but that will benefit the difference of amenity of the top and this cell
    let change-push-up ((distance top-patch) * price-weight + patch-amenity - ([patch-amenity] of top-patch))
    ; add the two things together

    ; this is a weird assumption though - pushing up isn't a nice option
    ; set patch-hate patch-hate + change-push-up)
  ]

  ; consider loss of open space
  ask above-ground with [pycor = 0]
  [
    ; check if no cells on pycor = 1 - no building or just one floor
    if (not any? turtles-on patch-at-heading-and-distance 0 1)
    [
      ; count the number of potential users for open space
      set patch-hate (patch-hate + num-neighbours * open-weight)
    ]
  ]

  ; calculate net amenity
  ask above-ground
  [ set patch-net-amenity (patch-amenity * selfishness - patch-hate * (100 - selfishness)) / 100 ]


end

;; calculate amenity
to calculate-amenity
  ask turtles
  [
    ; calculate amenity
    set amenity patch-amenity
    set hate patch-hate
    set net-amenity patch-net-amenity
  ]

end


;; ----- visualisation -----
to visualise
  ; visualise ground
  ask ground
  [
    if (area-type = "built")
    [ set pcolor brown ]

    if (area-type = "open")
    [ set pcolor green ]
  ]

  ; visualise light
  ask above-ground
  [
    ifelse (visualise-net-amenity = true)
    [ set pcolor scale-color pink patch-net-amenity -200 50 ]
    [ set pcolor scale-color gray shadow 10 0 ]
  ]

  ; visualise turtles by amenity
  ask turtles
  [
    set shape "circle"

    ifelse (visualise-net-amenity = true)
    [
      set color scale-color blue net-amenity (- (light-weight + view-weight + open-weight + price-weight) * 5)  ((light-weight + view-weight + open-weight + price-weight) * 5)
    ]
    [
      set color scale-color blue amenity (- (light-weight + view-weight + open-weight + price-weight) * 5)  ((light-weight + view-weight + open-weight + price-weight) * 5)
    ]

  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
150
15
1089
321
-1
-1
9.31
1
10
1
1
1
0
1
0
1
0
99
-1
30
0
0
1
ticks
30.0

BUTTON
80
15
143
48
NIL
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

BUTTON
80
55
143
88
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
80
95
143
128
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
280
395
465
428
max-view
max-view
0
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
280
360
465
393
open-range
open-range
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
80
360
265
393
floor-area-percentage
floor-area-percentage
0
500
300.0
10
1
%
HORIZONTAL

SLIDER
80
465
265
498
selfishness
selfishness
0
100
0.0
1
1
%
HORIZONTAL

SWITCH
690
325
890
358
visualise-net-amenity
visualise-net-amenity
1
1
-1000

PLOT
690
360
890
500
Mean amenity of turtles
NIL
NIL
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"amenity" 1.0 0 -16777216 true "" "plot mean [amenity] of turtles"

SLIDER
480
360
665
393
light-weight
light-weight
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
480
395
665
428
view-weight
view-weight
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
480
430
665
463
open-weight
open-weight
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
480
465
665
498
price-weight
price-weight
0
10
5.0
1
1
NIL
HORIZONTAL

TEXTBOX
490
335
675
353
Weight of Each Amenity
16
0.0
1

SLIDER
80
395
265
428
sun-height
sun-height
0
90
45.0
1
1
deg
HORIZONTAL

TEXTBOX
85
335
235
353
Model Parameters
16
0.0
1

TEXTBOX
290
335
440
353
Neighbour Range
16
0.0
1

TEXTBOX
85
440
235
458
Selfishness of Turtles
16
125.0
1

PLOT
890
360
1090
500
amenity_distribution 
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-pen-mode 1\nset-plot-x-range (min [amenity] of turtles) (max [amenity] of turtles) \nset-histogram-num-bars 10" ""
PENS
"default" 1.0 0 -16777216 true "" "set-plot-x-range (min [amenity] of turtles) (max [amenity] of turtles) \nset-histogram-num-bars 10\nhistogram ([amenity] of turtles)"

MONITOR
690
500
890
545
mean amenity
mean ([amenity] of turtles)
2
1
11

PLOT
1090
15
1290
155
Mean hate of turtles
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
"hate" 1.0 0 -16777216 true "" "plot mean [hate] of turtles"

MONITOR
1090
155
1290
200
mean hate
mean [hate] of turtles
2
1
11

PLOT
1090
360
1290
500
distribution_building_height
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-pen-mode 1\nset-histogram-num-bars min list 10 ((max [building-height] of ground) + 1)\nset-plot-x-range 0 (max [building-height] of ground) " ""
PENS
"default" 1.0 0 -16777216 true "" "set-histogram-num-bars min list 10 ((max [building-height] of ground) + 1)\nset-plot-x-range 0 (max [building-height] of ground) \nhistogram ([building-height] of ground)"

MONITOR
1090
500
1290
545
std_dev of building height
standard-deviation ([building-height] of ground)
2
1
11

PLOT
1090
220
1290
360
std_dev of building height
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot standard-deviation ([building-height] of ground)"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="brief_explanation" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="250"/>
    <metric>mean [amenity] of turtles</metric>
    <metric>standard-deviation [building-height] of ground</metric>
    <steppedValueSet variable="selfishness" first="0" step="10" last="100"/>
    <steppedValueSet variable="floor-area-percentage" first="100" step="100" last="500"/>
  </experiment>
</experiments>
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
