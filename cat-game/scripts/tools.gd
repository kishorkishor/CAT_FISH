class_name Tools
## What the cat is holding. A plain enum rather than an item in the bag, because
## the tools are never lost, sold or stacked - they are just modes.

enum { HAND, HOE, CAN, ROD, BUILD }

const NAMES := {
	HAND: "hand", HOE: "hoe", CAN: "watering can", ROD: "fishing rod", BUILD: "hammer",
}

const ACTIONS := {
	HAND: "harvest", HOE: "till soil", CAN: "water", ROD: "cast", BUILD: "build",
}
