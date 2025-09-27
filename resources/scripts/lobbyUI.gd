extends Control

@export_group("Network")
@export var steamLobby : SteamLobby

@onready var lobbyContainer : ScrollContainer = $Lobbies
@onready var lobbyList : VBoxContainer = $Lobbies/List
@onready var lobbiesButton : Button = $ToggleLobbies
@onready var hostButton : Button = $Host
@onready var leaveButton : Button = $Leave

var lobbiesOpen : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	lobbyContainer.visible = lobbiesOpen
	lobbiesButton.text = "CLOSE LOBBIES" if lobbiesOpen else "OPEN LOBBIES"

func _on_toggle_lobbies_pressed() -> void:
	lobbiesOpen = not lobbiesOpen
	lobbyContainer.visible = lobbiesOpen
	
	lobbiesButton.text = "CLOSE LOBBIES" if lobbiesOpen else "OPEN LOBBIES"
	
	if lobbiesOpen:
		print("STEAM: Requesting lobbies.")
		Steam.addRequestLobbyListStringFilter("mode", "DoorHuntTest", Steam.LOBBY_COMPARISON_EQUAL)
		Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
		Steam.requestLobbyList()


func _on_host_pressed() -> void:
	$"../../Network/ConnectionHandler".onHost()
	#steamLobby.createLobby()


func _on_leave_pressed() -> void:
	$"../../Network/ConnectionHandler".onJoin(1)
	#steamLobby.leaveLobby()
