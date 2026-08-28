class_name GoldBag
extends Area2D

export (Array, Resource) var gold_pickup_sounds: Array
export (Array, Resource) var gold_alt_pickup_sounds: Array

func _on_GoldBag_area_entered(area: Area2D) -> void :
	if area is Gold:
		var gold = area as Gold
		gold.pickup( - 1)

		if ProgressData.settings.alt_gold_sounds:
			SoundManager.play(Utils.get_rand_element(gold_alt_pickup_sounds), - 5, 0.2)
		else:
			SoundManager.play(Utils.get_rand_element(gold_pickup_sounds), 0, 0.2)
