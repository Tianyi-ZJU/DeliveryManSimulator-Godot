extends RefCounted

# Thresholds and downgrade rules from Unity Assets/Scripts/EndBehaviour.cs.
static func calculate(money: int, late: int, bad: int) -> String:
	if money < 2000:
		return "F"
	if money < 3000:
		return "D"
	if money < 6000:
		var tier := (money - 3000) / 1000
		return ["D", "C", "B"][tier] if late > 10 and bad > 0 else ["C", "B", "A"][tier]
	var offset := 1 if money >= 7000 else 0
	var ranks := ["B", "A", "S", "SS", "SSS", "SSSS"]
	if bad > 5:
		return ranks[offset]
	if late > 10:
		return ranks[1 + offset]
	if late > 5 or bad > 1:
		return ranks[2 + offset]
	if late > 0:
		return ranks[3 + offset]
	return ranks[4 + offset]
