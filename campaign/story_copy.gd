extends RefCounted
## English campaign copy keyed by the existing authored beat IDs.
const COPY := {
	&"first_return": "Returned fire. The relay answered.",
	&"far_reach_arrival": "One signal. One route back.",
	&"iron_wake_arrival": "Quarantine wrecks. Watch the mine lanes.",
	&"ghost_lanes_arrival": "Silent relays. Crossfire ahead.",
	&"tempest_veil_arrival": "Signal strong. Mine layers in motion.",
	&"echo_field_arrival": "Their firing solutions carry our cadence.",
	&"quiet_core_arrival": "Our signature. Their final defense.",
	&"generation_2": "They have rebuilt the perimeter.",
	&"generation_3": "They are predicting our flight record.",
	&"generation_4": "Apex rewrite. The last relay is close.",
	&"endless_departure": "Home is behind us. Follow the signal.",
	&"harbinger_discovery": "Harbinger. Something followed us here.",
	&"core_last_rewrite": "Last rewrite. Break the return loop.",

	&"far_reach_briefing": "MOTH // We are beyond the last charted relay. A repeating handshake is our only route home. Follow it through the Custodian Fleet. Reflect their fire, recover the relay, and break the Assault Commander at Wave 5.",
	&"far_reach_debrief": "MOTH // Relay coordinate recovered. The fleet is rebuilding its defenders. Two paths cross the broken perimeter: armor and mines, or speed and crossfire. Choose the pressure your ship can handle.",
	&"broken_perimeter_briefing": "MOTH // The next relay is sealed by Iron Bulwark. Its weapon pods sustain its armor. Strip them away to expose the hull. Your chosen route changes the defenders we meet on the way.",
	&"broken_perimeter_debrief": "MOTH // Quarantine protocol recovered. The fleet is not defending a place. It is trying to contain this signal. The next relay is predicting our movements.",
	&"iron_wake_fragment": "RECOVERED FRAGMENT // Return traffic denied. Reinforce the perimeter. The same handshake appears in every rejected transmission.",
	&"ghost_lanes_fragment": "RECOVERED FRAGMENT // A route remains between the patrols. Every marker points inward, toward a sender the network refuses to name.",
	&"tempest_reach_briefing": "MOTH // Tempest is building firing solutions from our flight record. Keep changing direction. We will cross this sector through mobile mine layers or the prediction fleet's telegraphs.",
	&"tempest_reach_debrief": "MOTH // I recognize the cadence now. The return signal carries our transponder signature. The Quiet Core is its source. Break the last relay and we can open a way home.",
	&"tempest_veil_fragment": "RECOVERED FRAGMENT // Origin signature: Swallowtail. The timestamp precedes our arrival. MOTH requests another sample.",
	&"echo_field_fragment": "RECOVERED FRAGMENT // The prediction engine keeps returning the same answer: our own ship, transmitting from the Core.",
	&"quiet_core_briefing": "MOTH // Final approach. Apex defenders guard the Tempest Core at Wave 20. Destroy its weapon pods, break its armor, and open the homeward relay. Whatever is sending this signal knows we are coming.",
	&"expedition_victory": "MOTH // The Core is silent. The handshake was ours: the same transponder signature, returning through every relay we broke. I can see a homeward coordinate now. It is stable. We can leave this fleet and its predictions behind.\n\nBut the transmission has not stopped. Something beyond the Core is answering in our cadence. The way home is open, pilot. So is the way onward.",
}
static func for_beat(beat: Resource) -> String:
	return str(COPY.get(beat.id, "MOTH // Relay recovered. The return route is open."))
