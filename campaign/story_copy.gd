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
	&"far_reach_briefing": "MOTH // This signal is our only lead home. I'm your navigator, and we've flown beyond the last known relay. The Custodian Fleet is blocking the way. Boost into their shots to send them back. Defeat the Assault Commander at Wave 5 to reach the first relay. Destroy its weapon pods to cut down its fire.",
	&"far_reach_debrief": "MOTH // The first relay has shown us two routes. Iron Wake is full of armored ships and mines. Ghost Lanes has fast ships firing from both sides. Choose a route, and we'll keep moving.",
	&"broken_perimeter_briefing": "MOTH // Iron Bulwark guards the next relay at Wave 10. Its weapon pods protect its armor. Destroy them to expose the ship beneath. On the way, Iron Wake has armored ships and mines; Ghost Lanes has fast ships and crossfire. Both routes lead to Bulwark.",
	&"broken_perimeter_debrief": "MOTH // I found the quarantine order. The fleet is trying to keep this signal from escaping. The ships ahead are already aiming where they expect us to go.",
	&"iron_wake_fragment": "RECOVERED FRAGMENT // QUARANTINE ORDER 07\n\nNo ships may return. All crews must turn off their navigation beacons and give the Custodian Fleet control of their relays. Do not answer the signal, even if it appears to come from a friendly ship.\n\nThe log lists hundreds of rejected messages. Different ships, different times, the same six notes. Every reply went to the Quiet Core.\n\nMOTH // These wrecks were facing home. Their engines were still running when the order came. Someone believed that answering the signal would let something through.",
	&"ghost_lanes_fragment": "RECOVERED FRAGMENT // MAINTENANCE CHANNEL\n\nThere is a gap between the patrols after the third sweep. Listen for it. The abandoned relays still answer, even the ones taken apart years ago. Follow the timing of their replies. The locations in their messages are wrong.\n\nThe last message has no sender. It seems to have come from every relay at once. Someone left a handwritten note: someone keeps moving the way out.\n\nMOTH // I can work out the timing, but I can't find who wrote this. Every clue leads deeper in.",
	&"tempest_reach_briefing": "MOTH // Tempest is using our past movements to aim ahead of us. Keep changing direction. Tempest Veil has moving mine layers. Echo Field has ships that predict where we're going. Watch for warning lines before you boost. Both routes reach Tempest at Wave 15. After that, we should be close enough to find the sender.",
	&"tempest_reach_debrief": "MOTH // I know this signal. It's coming from our ship. But its source is the Quiet Core. Destroy the Core and we can open a way home.",
	&"tempest_veil_fragment": "RECOVERED FRAGMENT // SIGNAL SAMPLE 19\n\nThe signal identifies its sender as Swallowtail. It was sent before we arrived, yet it includes a course change we only made during this flight. Three relay clocks agree on the time. Both records are intact.\n\nThe signal breaks up whenever the fleet brings in stronger ships. Then the same six notes return. Something is keeping the message alive while everything around it changes.\n\nMOTH // I asked for another sample. The reply arrived before I sent the request. I have both records. I still can't tell which came first.",
	&"echo_field_fragment": "RECOVERED FRAGMENT // PREDICTED FLIGHT PATHS\n\nThe fleet has calculated thousands of routes we might take. Most end at the perimeter. Some reach Tempest. A few reach the Quiet Core. In every one of those, our ship sends the same signal.\n\nThe fleet calls that a successful return. It also calls it a failed quarantine. There is no destination listed beyond the Core, only an order: keep the sender alive until the signal returns.\n\nMOTH // They have our turns, our pauses, even the moments we nearly stopped. But the next choice is still ours.",
	&"quiet_core_briefing": "MOTH // Their strongest ships guard Tempest Core at Wave 20. Destroy its weapon pods, break through its armor, and open the way home. Every route has led us here. Whoever is sending the signal knows we're coming. Once the Core is gone, we can head home or follow the signal farther.",
	&"expedition_victory": "MOTH // The Core is silent. The signal was ours, coming back through every relay we fought past. I have a clear route home. We can leave.\n\nBut something beyond the Core is still answering with those same six notes. Your choice, pilot. Home, or farther out.",
}
static func for_beat(beat: Resource) -> String:
	return str(COPY.get(beat.id, "MOTH // Relay reached. The way home is open."))
