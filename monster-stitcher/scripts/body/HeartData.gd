class_name HeartData
extends Resource

var heart_name: String = "Common Heart"

## The passive ability this heart grants. Instantiate via HeartPassive.make().
var passive_id: Enums.HeartPassiveID = Enums.HeartPassiveID.NONE

## Flat stat bonuses contributed to the monster's aggregate stats
var passive_stats: Dictionary[Enums.Stat, int] = {
	Enums.Stat.VITALITY: 0, Enums.Stat.ATTACK: 0, Enums.Stat.DEFENSE: 0, Enums.Stat.CHARISMA: 0, Enums.Stat.LUCK: 0, Enums.Stat.SPEED: 0, Enums.Stat.RESOURCEFULNESS: 0, Enums.Stat.MAGIC_ATTACK: 0, Enums.Stat.MAGIC_DEFENSE: 0,
}

var parent_monster: MonsterBody = null

## Live passive instance created from passive_id in MonsterBody.initialize()
var passive: HeartPassive = null

func get_stat(stat_name: Enums.Stat) -> int:
	return passive_stats.get(stat_name, 0)

func _init(
	name_param			: String,
	passive_id_param	: Enums.HeartPassiveID,
	stats_param			: Dictionary[Enums.Stat, int]
) -> void:
	heart_name 	= name_param
	passive_id 	= passive_id_param
	passive 	= HeartPassive.make(passive_id)

	for stat in Enums.Stat.values():
		passive_stats[stat] = stats_param.get(stat, 0)

# Called by MonsterBody.initialize()
func initialize(parent: MonsterBody) -> void:
	parent_monster = parent
