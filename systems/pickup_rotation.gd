extends RefCounted
## Fair variety without extra drops: each eligible pickup appears once per bag.
## Separate boss bags never select a nuke; repeat protection also spans mode changes.
var _field: Array[int] = []
var _boss: Array[int] = []
var _last := -1

func next(boss_active: bool) -> int:
	var bag: Array[int] = _boss if boss_active else _field
	if bag.is_empty():
		for kind in range(PowerUp.Type.NUKE if boss_active else PowerUp.Type.NUKE + 1):
			bag.append(kind)
		bag.shuffle()
	if bag.size() > 1 and bag.back() == _last:
		var swap := bag[0]
		bag[0] = bag.back()
		bag[bag.size() - 1] = swap
	_last = bag.pop_back()
	return _last
