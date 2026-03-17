## PartTooltip.gd
## Call PartTooltip.build(part) on hover to get a TooltipData object.
## Your UI reads fields off TooltipData — no game logic in the UI layer.
class_name PartTooltip
extends RefCounted

class TooltipData:
	var part_name		: String 				= ""
	var slot_label		: String 				= ""
	var type_label		: String 				= ""
	var type_matchup	: String 				= ""
	var current_hp		: int    				= 0
	var max_hp			: int    				= 0
	var hp_percent		: float  				= 1.0
	var move			: MoveTooltip 			= null
	var stats			: Array[StatEntry]   	= []
	var statuses		: Array[StatusEntry] 	= []
	var level			: int  					= 1
	var is_stunned		: bool 					= false

	func to_plain_text() -> String:
		var lines: Array[String] = []
		lines.append("%s  [%s · %s]" % [part_name, slot_label, type_label])

		if type_matchup != "":
			lines.append(type_matchup)

		lines.append("HP: %d / %d" % [current_hp, max_hp])

		if move:
			lines.append(""); lines.append("▶ %s  (cost: %d)" % [move.move_name, move.energy_cost])

			if move.description != "":
				lines.append("  " + move.description)

			lines.append("  %s · %s" % [move.damage_type_label, move.target_label])

			if move.base_damage > 0:
				lines.append("  Damage: %d  Crit: %.0f%%" % [move.base_damage, move.crit_chance * 100.0])

			if move.heal_amount > 0:
				lines.append("  Heals: %d HP" % move.heal_amount)

			for effect_line in move.effect_lines:
				lines.append("  • " + effect_line)

		if stats.size() > 0:
			lines.append("")
			lines.append("Passive Stats:")

			for s in stats:
				lines.append("  %s%d %s — %s" % ["+" if s.value > 0 else "", s.value, s.label, s.description])

		if statuses.size() > 0:
			lines.append("")
			lines.append("Statuses:")

			for st in statuses:
				var dur = "(%d turns)" % st.turns_remaining if st.turns_remaining >= 0 else "(permanent)"
				lines.append("  %s %s %s" % [st.icon, st.label, dur])

		lines.append("")
		lines.append("Lv.%d " % [level])

		if is_stunned:
			lines.append("⚡ STUNNED")

		return "\n".join(lines)

class MoveTooltip:
	var move_name			: String = ""
	var description			: String = ""
	var energy_cost			: int    = 0
	var base_damage			: int    = 0
	var heal_amount			: int    = 0
	var damage_type_label	: String = ""
	var target_label		: String = ""
	var crit_chance			: float  = 0.0

	# one line per MoveEffect.describe()
	var effect_lines		: Array[String] = []

class StatEntry:
	var label			: String = ""
	var value			: int    = 0
	var description		: String = ""

class StatusEntry:
	var label			: String = ""
	var icon			: String = ""
	var description		: String = ""
	var turns_remaining	: int    = 0


static func build(part: BodyPartData) -> TooltipData:
	var tip 			= TooltipData.new()
	tip.part_name    	= part.part_name
	tip.slot_label   	= Enums.get_slot_label(part.slot)
	tip.type_label   	= Enums.get_type_label(part.type)
	tip.type_matchup 	= Enums.get_type_matchup_hint(part.type)
	tip.current_hp   	= part.current_hp
	tip.max_hp      	= part.max_hp
	tip.hp_percent   	= float(part.current_hp) / float(part.max_hp) if part.max_hp > 0 else 0.0

	if part.move:
		var mt 					= MoveTooltip.new()
		mt.move_name         	= part.move.move_name
		mt.description       	= part.move.description
		mt.energy_cost       	= part.move.energy_cost
		mt.target_label      	= Enums.get_target_label(part.move.target_mode)
		mt.effect_lines      	= part.move.get_effect_descriptions()

		# Pull damage/heal summary from effects
		for e in part.move.effects:
			if e is MoveEffect.Damage:
				var dmg = e as MoveEffect.Damage
				mt.base_damage       = dmg.base_damage
				mt.damage_type_label = Enums.get_damage_type_label(dmg.damage_type)
				mt.crit_chance       = dmg.crit_chance

			elif e is MoveEffect.HealPart:
				mt.heal_amount = (e as MoveEffect.HealPart).amount

		tip.move = mt

	for stat in Enums.all_stats():
		var val: int 		= part.passive_stats.get(stat, 0)

		if val == 0:
			continue

		var entry      		= StatEntry.new()
		entry.label    		= Enums.get_stat_label(stat)
		entry.value    		= val
		entry.description 	= Enums.get_stat_description(stat)
		tip.stats.append(entry)

	for effect in part.statuses:
		var sid    				= effect.get_id()
		var entry  				= StatusEntry.new()
		entry.label           	= Enums.get_status_label(sid)
		entry.icon            	= Enums.get_status_icon(sid)
		entry.description     	= Enums.get_status_description(sid)
		entry.turns_remaining 	= effect.turns_remaining
		tip.statuses.append(entry)

	tip.level         			= part.level
	tip.is_stunned    			= part.has_status(Enums.StatusID.STUNNED)
	return tip
