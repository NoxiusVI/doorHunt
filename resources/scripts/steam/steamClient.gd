extends Node

var appId : String = "480" 

var steamId : int
var steamUsername : String

var specialNames : Dictionary = {
	"76561199024573601" = {"rainbow" = ["sat=0.5"],"wave" = []},
	"76561198129016769" = {"rainbow" = ["sat=0.5"],"shake" = []},
}

func _init() -> void:
	OS.set_environment("SteamAppID", appId)
	OS.set_environment("SteamGameID", appId)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Steam.isSteamRunning():
		push_error("STEAM NOT RUNNING!")
		return
	
	steamId = Steam.getSteamID()
	steamUsername = Steam.getFriendPersonaName(steamId)

func getColoredName(thisSteamId: int) -> String:
	print(thisSteamId)
	var steamName : String = Steam.getFriendPersonaName(thisSteamId)
	var stringId : String = str(thisSteamId)
	var isSpecial : bool = specialNames.has(stringId)
	if isSpecial:
		# Do special name
		var leftToClose : Array = []
		var nameBuilder : String = ""
		for specialThing : String in specialNames[stringId]:
			leftToClose.append(specialThing)
			var specialBuilder : String = specialThing
			for specialData : String in specialNames[stringId][specialThing]:
				specialBuilder += " " + specialData
			nameBuilder += "[%s]" % specialBuilder
		nameBuilder += steamName
		leftToClose.reverse()
		for closing : String in leftToClose:
			nameBuilder += "[/%s]" % closing
		return nameBuilder
	else:
		# Do boring color name
		# Use the Steam ID as the seed for the random number generator
		var rng : RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = thisSteamId
		# Generate a random HSL color
		var h : float = rng.randf_range(0.0, 1.0) # Hue
		var s : float = rng.randf_range(0.5, 1.0) # Saturation (keep it high for vibrant colors)
		var v : float = rng.randf_range(0.7, 1.0) # Value (keep it high for bright colors)
		# Create the Color object from HSL
		var newColor : Color = Color.from_hsv(h, s, v)

		return "[color=%s] %s [/color]" % [newColor.to_html(false),steamName]
