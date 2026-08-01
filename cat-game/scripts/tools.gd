class_name Tools
## What the cat is holding. A plain enum rather than an item in the bag, because
## the tools are never lost, sold or stacked - they are just modes.

enum { HAND, HOE, CAN, AXE, ROD, BUILD }

const NAMES := {
	HAND: "hand", HOE: "hoe", CAN: "watering can", AXE: "axe",
	ROD: "fishing rod", BUILD: "hammer",
}

const ACTIONS := {
	HAND: "harvest", HOE: "till soil", CAN: "water", AXE: "fell",
	ROD: "cast", BUILD: "build",
}

## Icon per tool, so the belt shows what is in paw instead of spelling it.
const ICONS := {
	HAND: "res://assets/ui/tool_hand.png",
	HOE: "res://assets/ui/tool_hoe.png",
	CAN: "res://assets/ui/tool_can.png",
	AXE: "res://assets/ui/tool_axe.png",
	ROD: "res://assets/ui/tool_rod.png",
	BUILD: "res://assets/ui/tool_hammer.png",
}
