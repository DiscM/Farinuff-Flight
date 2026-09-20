extends RefCounted
## English campaign copy keyed by the existing authored beat IDs.
const COPY := {
	&"first_return": "We sent their fire back. The relay answered.",
	&"far_reach_arrival": "One signal. One way home.",
	&"iron_wake_arrival": "Wrecks ahead. Watch for mines.",
	&"ghost_lanes_arrival": "Silent relays. Enemy fire from both sides.",
	&"tempest_veil_arrival": "The signal is stronger. Watch the mine layers.",
	&"echo_field_arrival": "They know where we have been. Keep changing direction.",
	&"quiet_core_arrival": "That signal is ours. Their last defense is ahead.",
	&"generation_2": "The fleet has sent stronger ships.",
	&"generation_3": "They are aiming ahead of us. Change course.",
	&"generation_4": "Their strongest ships are here. The last relay is close.",
	&"endless_departure": "The way home is behind us. The signal leads farther out.",
	&"harbinger_discovery": "Harbinger. Something followed us here.",
	&"core_last_rewrite": "One last defense. Destroy the Core.",
	&"far_reach_briefing": "MOTH // The signal leads home. Assault Commander blocks the first relay at Wave 5. Boost to reflect its shots; destroy weapon pods to reduce its fire.",
	&"far_reach_debrief": "MOTH // Two routes: Iron Wake has armor and mines. Ghost Lanes has speed and crossfire.",
	&"broken_perimeter_briefing": "MOTH // Iron Bulwark guards Wave 10. Destroy its weapon pods to expose the hull.",
	&"broken_perimeter_debrief": "MOTH // The quarantine is holding the signal in. Ships ahead predict our course.",
	&"iron_wake_fragment": "QUARANTINE ORDER 07\n\nNo returns. Disable navigation beacons. Surrender all relays. Do not answer the signal.\n\nHundreds of ships sent the same six notes. Every reply went to the Quiet Core.\n\nMOTH // The wrecks were facing home, engines still running.",
	&"ghost_lanes_fragment": "MAINTENANCE CHANNEL\n\nA patrol gap follows the third sweep. Abandoned relays still answer. Trust their timing, not their coordinates.\n\nThe final message came from every relay at once: someone keeps moving the way out.\n\nMOTH // Every clue leads deeper in.",
	&"tempest_reach_briefing": "MOTH // Tempest predicts our turns. Watch warning lines; change direction. Tempest Veil has mine layers, Echo Field has predictive fire. Both reach Tempest at Wave 15.",
	&"tempest_reach_debrief": "MOTH // The signal is ours, but it comes from the Quiet Core. Destroy it to open the way home.",
	&"tempest_veil_fragment": "SIGNAL SAMPLE 19\n\nSender: Swallowtail. Sent before our arrival; includes turns we just made. Three relay clocks agree.\n\nThe signal breaks as stronger ships arrive. Then the six notes return.\n\nMOTH // The reply arrived before my request.",
	&"echo_field_fragment": "PREDICTED FLIGHT PATHS\n\nThousands of routes. Most end at the perimeter. Every route reaching the Core ends with our ship sending the signal.\n\nThe fleet calls it a successful return and a failed quarantine. Its order: keep the sender alive until the signal returns.\n\nMOTH // The next choice is ours.",
	&"quiet_core_briefing": "MOTH // Tempest Core, Wave 20. Destroy its pods and break its armor. Then head home or continue into Endless.",
	&"expedition_victory": "MOTH // The signal was ours, echoed through the relays. The way home is open.\n\nBeyond the Core, something still answers. Home, or farther out?",
}
static func for_beat(beat: Resource) -> String:
	return str(COPY.get(beat.id, "MOTH // Relay reached. The way home is open."))
