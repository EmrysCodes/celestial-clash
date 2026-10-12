extends Node

## Local-first networking stub. Match logic talks only to this bridge.
## Future online: replace LocalTransport with a WebRTC / dedicated-server transport
## that serializes the same InputCommand payloads.

signal command_received(command: Dictionary)
signal match_event(event: Dictionary)

var is_online: bool = false
var local_peer_id: int = 1


func submit_command(command: Dictionary) -> void:
	## Authority path for now: echo locally. Online will validate server-side.
	command = command.duplicate(true)
	command["peer_id"] = local_peer_id
	command["t"] = Time.get_ticks_msec()
	command_received.emit(command)


func broadcast_event(event: Dictionary) -> void:
	match_event.emit(event.duplicate(true))


func describe() -> String:
	return "Local vs AI (online transport planned)"
