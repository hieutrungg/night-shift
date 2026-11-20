class_name Greybox01Decor
extends RefCounted
## Decor for greybox_01: an abandoned clothing company's office.
## See docs/DECOR_PLAN.md for the room themes and the placement rules.
## Each entry: [prop id, x, z, turn in degrees, optional height, optional pose]
##   x, z  = centre of the prop's footprint in world metres (x = column, z = row)
##   turn  = 0 faces +Z (south), 90 faces +X (east), 180 north, -90 west
##   height = lift off the floor, for things standing on other props
## Prop ids are Kenney Furniture Kit model names, or see PropFactory.

const ENTRIES: Array[Array] = [
	# P1 archive (x 1-8, z 1-7): shelving aisles and boxes.
	["bookcaseClosedWide", 3.4, 1.25, 0],
	["bookcaseClosedWide", 5.4, 1.25, 0],
	["bookcaseOpen", 7.2, 1.25, 0],
	["bookcaseOpen", 2.4, 3.5, 0],
	["bookcaseOpen", 3.2, 3.5, 0],
	["bookcaseOpen", 4.0, 3.5, 180],
	["bookcaseClosedDoors", 7.75, 6.2, -90],
	["cardboardBoxClosed", 1.3, 3.0, 0],
	["cardboardBoxOpen", 1.4, 3.6, 90],
	["cardboardBoxClosed", 6.5, 5.6, 20],
	["cardboardBoxClosed", 5.9, 2.2, -15],

	# P2 director's office (x 9-16, z 1-7).
	["desk", 10.6, 2.3, 180],
	["chairDesk", 10.6, 1.45, 180],
	["computerScreen", 10.6, 2.45, 180, 0.77],
	["lotta", 14.0, 1.32, 0],
	["bookcaseClosedWide", 9.25, 5.9, 90],
	["rugRectangle", 12.0, 5.3, 0],
	["loungeSofa", 12.0, 6.55, 180],
	["tableCoffee", 12.0, 5.4, 0],
	["lampSquareFloor", 10.6, 6.6, 0],
	["pottedPlant", 14.4, 6.5, 0],

	# P3 fabric samples store (x 21-28, z 1-7).
	["bookcaseOpen", 22.4, 1.25, 0],
	["bookcaseOpen", 23.2, 1.25, 0],
	["bookcaseOpen", 24.0, 1.25, 0],
	["bookcaseOpen", 24.8, 1.25, 0],
	["bookcaseClosedDoors", 27.75, 2.2, -90],
	["cardboardBoxClosed", 26.3, 1.4, 10],
	["cardboardBoxClosed", 26.8, 1.45, -5],
	["cardboardBoxOpen", 26.55, 2.1, 30],
	["coatRackStanding", 22.0, 5.3, 0],
	["coatRackStanding", 23.0, 5.7, 0],
	["lotta", 24.0, 6.71, 180],
	["cardboardBoxOpen", 27.3, 6.4, -30],

	# P4 showroom (x 29-36, z 1-7): where the real mannequin starts,
	# among decoys that look the same but never move.
	["rugRound", 32.5, 4.1, 0],
	["lotta", 30.4, 1.3, 0],
	["coatRackStanding", 33.9, 1.4, 0],
	["lampRoundFloor", 29.4, 6.6, 0],
	["mannequin", 30.1, 5.9, 40, 0.0, 0],
	["mannequin", 34.8, 3.3, -100, 0.0, 2],
	["mannequin", 35.4, 6.5, -140, 0.0, 1],

	# P5 open office 1 (x 1-8, z 8-13).
	["desk", 2.2, 8.4, 0],
	["chairDesk", 2.2, 9.4, 180],
	["computerScreen", 2.2, 8.3, 0, 0.77],
	["bookcaseClosedDoors", 6.4, 8.25, 0],
	["desk", 2.0, 12.6, 180],
	["chairDesk", 2.0, 11.6, 0],
	["computerScreen", 2.0, 12.75, 180, 0.77],
	["computerKeyboard", 2.0, 12.4, 180, 0.77],
	["desk", 3.6, 12.6, 180],
	["chairDesk", 3.6, 11.6, 0],
	["computerScreen", 3.6, 12.75, 180, 0.77],
	["desk", 6.2, 12.6, 180],
	["chairDesk", 6.2, 11.6, 0],
	["computerScreen", 6.2, 12.75, 180, 0.77],
	["pottedPlant", 7.5, 12.5, 0],

	# P6 meeting room (x 9-16, z 8-13).
	["table", 12.4, 10.9, 0],
	["table", 14.08, 10.9, 0],
	["chair", 12.6, 9.95, 0],
	["chair", 13.6, 9.95, 0],
	["chair", 14.6, 9.95, 0],
	["chair", 11.2, 11.85, 180],
	["chair", 13.4, 11.85, 180],
	["chair", 14.4, 11.85, 180],
	["cabinetTelevision", 14.4, 8.3, 0],
	["televisionModern", 14.4, 8.35, 0, 0.62],
	["pottedPlant", 9.4, 8.5, 0],
	["pottedPlant", 15.5, 12.5, 0],

	# P7 open office 2 (x 21-28, z 8-13).
	["deskCorner", 26.9, 9.0, 0],
	["chairDesk", 26.3, 10.4, 0],
	["desk", 22.5, 8.4, 0],
	["chairDesk", 22.5, 9.4, 180],
	["computerScreen", 22.5, 8.3, 0, 0.77],
	["sideTableDrawers", 26.6, 12.75, 180],
	["bookcaseOpen", 21.6, 12.75, 180],
	["cardboardBoxClosed", 25.6, 12.6, 15],

	# P8 staff lockers (x 29-36, z 8-13): tall cabinets block the view.
	["bookcaseClosedDoors", 35.75, 8.6, -90],
	["bookcaseClosedDoors", 35.75, 9.4, -90],
	["bookcaseClosedDoors", 35.75, 10.2, -90],
	["bookcaseClosedDoors", 35.75, 11.0, -90],
	["bookcaseClosedDoors", 35.75, 11.8, -90],
	["bookcaseClosedDoors", 33.0, 12.75, 180],
	["bookcaseClosedDoors", 33.8, 12.75, 180],
	["bookcaseClosedDoors", 34.6, 12.75, 180],
	["bench", 33.8, 10.6, 0],
	["bench", 34.6, 10.6, 0],
	["coatRackStanding", 30.0, 12.5, 0],

	# P9 security office (x 1-8, z 14-20).
	["desk", 3.5, 14.4, 0],
	["chairDesk", 3.5, 15.4, 180],
	["cabinetTelevision", 6.0, 14.3, 0],
	["televisionVintage", 5.6, 14.3, 0, 0.62],
	["televisionVintage", 6.4, 14.3, 0, 0.62],
	["bookcaseClosedDoors", 1.25, 18.6, 90],
	["lotta", 4.6, 19.71, 180],
	["trashcan", 7.6, 19.6, 0],

	# P10 reception (x 9-16, z 14-20): the first room players see.
	["desk", 13.2, 16.0, 90],
	["desk", 13.2, 17.5, 90],
	["chairDesk", 12.2, 16.8, -90],
	["loungeSofa", 14.4, 19.55, 180],
	["rugRectangle", 14.4, 18.95, 0],
	["tableCoffeeGlass", 14.4, 18.4, 0],
	["loungeChair", 10.2, 14.6, 0],
	["pottedPlant", 15.6, 14.5, 0],
	["pottedPlant", 9.5, 19.5, 0],

	# P11 pantry (x 21-28, z 14-20).
	["kitchenCabinet", 22.0, 19.55, 180],
	["kitchenSink", 22.86, 19.55, 180],
	["kitchenCabinet", 23.72, 19.55, 180],
	["kitchenCoffeeMachine", 22.0, 19.55, 180, 0.9],
	["kitchenMicrowave", 23.72, 19.55, 180, 0.9],
	["kitchenFridgeLarge", 21.7, 14.5, 0],
	["tableRound", 25.0, 16.6, 0],
	["chair", 25.0, 15.6, 0],
	["chair", 25.0, 17.6, 180],
	["chair", 23.9, 16.6, 90],
	["chair", 26.1, 16.6, -90],
	["trashcan", 27.6, 19.6, 0],

	# P12 restroom (x 29-36, z 14-20).
	["toilet", 31.0, 14.5, 0],
	["toilet", 32.2, 14.5, 0],
	["toilet", 33.4, 14.5, 0],
	["bathroomSink", 32.0, 19.7, 180],
	["bathroomSink", 33.0, 19.7, 180],
	["bathroomMirror", 32.0, 19.85, 180, 1.1],
	["bathroomMirror", 33.0, 19.85, 180, 1.1],
	["trashcan", 35.5, 19.5, 0],

	# Corridor (x 17-20): along the walls only, never in front of a door.
	["pottedPlant", 17.25, 1.3, 0],
	["pottedPlant", 19.75, 1.3, 0],
	["bench", 17.2, 6.0, 90],
	["trashcan", 19.75, 6.0, 0],
	["pottedPlant", 17.25, 13.0, 0],
	["bench", 19.8, 13.5, -90],
	["trashcan", 17.25, 19.4, 0],

	# Parking lot.
	["cone", 24.0, 22.4, 0],
	["cone", 32.3, 22.4, 0],
	["cone", 23.6, 25.4, 0],
	["crate", 34.0, 24.5, 15],
	["crate", 35.3, 24.2, -10],
]
