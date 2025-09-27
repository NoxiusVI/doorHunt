extends Node
class_name ConnectionHandler

var peer2 : ENetMultiplayerPeer
var peer : SteamMultiplayerPeer

var doEnet : bool = true

@export_group("Inputs")
@export var addressInput : LineEdit
@export var portInput : LineEdit
@export_group("Spawner")
@export var mpSpawner : MultiplayerSpawner
@export var playerScene : PackedScene
@export_group("Profiles")
@export var possibleNames : PackedStringArray

func spawnPlayer(peerIndex : int) -> NetworkRigidBody3D:
	var newPlayerNode : NetworkRigidBody3D = playerScene.instantiate()
	newPlayerNode.set("name", str(peerIndex))
	newPlayerNode.set("peerId", peerIndex)
	newPlayerNode.set_multiplayer_authority(peerIndex)
	#newPlayerNode.get_node("Nameplate/NameViewport/NameLabel").set("text",SteamClient.getColoredName(peer.get_steam_id_for_peer_id(peerIndex)))
	newPlayerNode.get_node("Nameplate/NameViewport/NameLabel").set("text",str(peerIndex))
	print("PEER ID: ",peerIndex)
	return newPlayerNode

func _ready() -> void:
	mpSpawner.spawn_function = spawnPlayer

func onPeerConnected(peerIndex : int) -> void:
	mpSpawner.spawn(peerIndex)

func onHost() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.multiplayer_peer == null:
		if doEnet:
			peer2 = ENetMultiplayerPeer.new()
			peer2.create_server(7777)
			peer2.peer_connected.connect(onPeerConnected)
			multiplayer.multiplayer_peer = peer2
		else:
			peer = SteamMultiplayerPeer.new()
			peer.create_host(0)
			peer.peer_connected.connect(onPeerConnected)
			multiplayer.multiplayer_peer = peer
		mpSpawner.spawn(1)


func onJoin(hostId : int) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.multiplayer_peer == null:
		if doEnet:
			peer2 = ENetMultiplayerPeer.new()
			peer2.create_client("localhost",7777)
			multiplayer.multiplayer_peer = peer2
		else:
			peer = SteamMultiplayerPeer.new()
			peer.create_client(hostId)
			multiplayer.multiplayer_peer = peer
