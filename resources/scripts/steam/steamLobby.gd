extends Node
class_name SteamLobby

# -- PREFAB VARIABLES --
@export var lobbyButtonPrefab : PackedScene

# -- NETWORK VARIABLES --
@export var connectionHandler : ConnectionHandler

# -- OTHER VARIABLES --
@export var lobbyButtonList : VBoxContainer

# -- LOBBY INFORMATION VARAIBLES --
const PACKET_READ_LIMIT: int = 32

var lobbyData : Dictionary
var lobbyId: int = 0
var lobbyMembers: Array = []
var maxMembers: int = 4
var canVotekick: bool = false

func _ready() -> void:
	Steam.join_requested.connect(onLobbyJoinRequest)
	Steam.lobby_created.connect(onLobbyCreated)
	Steam.lobby_data_update.connect(onLobbyDataUpdate)
	Steam.lobby_invite.connect(onLobbyInvite)
	Steam.lobby_joined.connect(onLobbyJoined)
	Steam.lobby_match_list.connect(onLobbyMatchList)
	Steam.persona_state_change.connect(onPersonaChange)

	# Check for command line arguments
	checkCommandLine()

func _physics_process(_delta: float) -> void:
	Steam.run_callbacks()

func createLobby() -> void:
	if lobbyId != 0: return # Make sure we aren't in a lobby already.
	#lobbyId = 1
	#connectionHandler.onHost()
	print("STEAM LOBBY: Attempting to create a lobby.")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, maxMembers)

func joinLobby(thisLobbyId : int) -> void:
	if lobbyId != 0: return # Make sure we aren't in a lobby already.
	#lobbyId = 1
	#connectionHandler.onJoin(0)
	print("STEAM LOBBY: Attempting to join a lobby, LobbyID: %s" % thisLobbyId)
	lobbyMembers.clear()
	Steam.joinLobby(thisLobbyId)

func leaveLobby() -> void:
	# If in a lobby, leave it
	if lobbyId == 0: return
	Steam.leaveLobby(lobbyId)
	lobbyId = 0
	
	# Close session with all users
	for thisMember : Dictionary in lobbyMembers:
		if thisMember['steam_id'] == SteamClient.steamId: continue

	lobbyMembers.clear()


func onLobbyCreated(connectId: int, thisLobbyId: int) -> void:
	print("Yas")
	if connectId == 1:
		# Set the lobby ID
		lobbyId = thisLobbyId
		print("STEAM LOBBY: Created a lobby, LobbyID: %s" % lobbyId)
		
		var lobbyOwnerName : String =  Steam.getFriendPersonaName(Steam.getLobbyOwner(lobbyId))
		var lobbyOwnerFull : String = lobbyOwnerName + ("'" if lobbyOwnerName[lobbyOwnerName.length()-1] == "s" else "'s")
		
		Steam.setLobbyJoinable(lobbyId, true)
		Steam.setLobbyData(lobbyId, "name", "%s Lobby" % lobbyOwnerFull)
		Steam.setLobbyData(lobbyId, "mode", "DoorHuntTest")

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("STEAM LOBBY: Allowing Steam to be relay backup: %s" % set_relay)

func onLobbyJoined(thisLobbyId: int, _permissions: int, _locked: bool, response: int) -> void:
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Ye")
		# Set this lobby ID as your lobby ID
		lobbyId = thisLobbyId
		var hostId : int = Steam.getLobbyOwner(lobbyId)
		
		if SteamClient.steamId == hostId:
			connectionHandler.onHost()
		else:
			connectionHandler.onJoin(hostId)
		
		# Get the lobby members
		getLobbyMembers()
	# Else it failed for some reason
	else:
		# Get the failure reason
		var fail_reason: String

		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."
		print("STEAM LOBBY: Failed to join this lobby, Reason: %s" % fail_reason)

func onLobbyMatchList(theseLobbies: Array) -> void:
	for thisLobby : int in theseLobbies:
		# Pull lobby data from Steam, these are specific to our example
		var lobbyName: String = Steam.getLobbyData(thisLobby, "name")
		var lobbyMode: String = Steam.getLobbyData(thisLobby, "mode")

		# Get the current number of members
		var lobbyPlayers: int = Steam.getNumLobbyMembers(thisLobby)
		
		for button : Button in lobbyButtonList.get_children():
			button.queue_free()
		
		# Create a button for the lobby
		var newLobbyButton: Button = lobbyButtonPrefab.instantiate()
		newLobbyButton.set_text("Lobby %s: %s [%s] - %s Player(s)" % [thisLobby, lobbyName, lobbyMode, lobbyPlayers])
		newLobbyButton.set_name("lobby_%s" % thisLobby)
		newLobbyButton.connect("pressed", Callable(self, "joinLobby").bind(thisLobby))
		lobbyButtonList.add_child(newLobbyButton)


func onLobbyJoinRequest(thisLobbyId: int, friendId: int) -> void:
	var ownerName: String = Steam.getFriendPersonaName(friendId)
	print("STEAM LOBBY: Joining %s's lobby..." % ownerName)
	joinLobby(thisLobbyId)

func onLobbyDataUpdate(_success : int, _thisLobbyId :int, _thisMemberId : int) -> void:
	pass

func onLobbyInvite(_inviter : int, _thisLobbyId : int, _thisGameId : int) -> void:
	pass

func onPersonaChange(this_steam_id: int, _flag: int) -> void:
	# Make sure you're in a lobby and this user is valid or Steam might spam your console log
	if lobbyId > 0:
		print("STEAM LOBBY: A user (%s) had information change, update the lobby list." % this_steam_id)
		
		# Update the player list
		getLobbyMembers()

func getLobbyMembers() -> void:
	# Clear your previous lobby list
	lobbyMembers.clear()

	# Get the number of members from this lobby from Steam
	var memberAmount: int = Steam.getNumLobbyMembers(lobbyId)

	# Get the data of these players from Steam
	for thisMemberId : int in range(0, memberAmount):
		# Get the member's info
		var memberSteamId: int = Steam.getLobbyMemberByIndex(lobbyId, thisMemberId)
		var memberSteamName: String = Steam.getFriendPersonaName(memberSteamId)
		
		lobbyMembers.append({"steam_id":memberSteamId, "steam_name":memberSteamName})

func checkCommandLine() -> void:
	var cmdArguments: Array = OS.get_cmdline_args()
	
	if cmdArguments.size() == 0: return
	if cmdArguments[0] != "+connect_lobby": return
	if int(cmdArguments[1]) <= 0: return
	# At this point, you'll probably want to change scenes
	# Something like a loading into lobby screen
	print("STEAM LOBBY: Joining via command line, LobbyID: %s" % cmdArguments[1])
	joinLobby(int(cmdArguments[1]))
