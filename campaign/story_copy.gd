extends RefCounted
## English campaign copy keyed by the existing authored beat IDs.
const COPY := {
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
	&"expedition_victory": "MOTH // The homeward relay is open. But the signal continues beyond its source. We can go home now, or follow it into the void.",
}
static func for_beat(beat: Resource) -> String:
	return str(COPY.get(beat.id, "MOTH // Relay recovered. The return route is open."))
