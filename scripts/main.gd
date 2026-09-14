extends Node2D

# LOOP v1.1 - LABYRINTH: optional room portals create a multi-room run without breaking the core 60s loop.
# Procedural graphics only: no external assets required.

const W := 720.0
const H := 1280.0
const WORLD := Rect2(18, 122, 684, 1080)
const LOOP_LENGTH := 60.0
const SAVE_PATH := "user://loop_save.json"

var rng := RandomNumberGenerator.new()
var player := {
    "pos": Vector2(W/2, H/2+100), "hp": 100.0, "max_hp": 100.0,
    "speed": 230.0, "damage": 18.0, "fire_rate": 0.34, "shot_speed": 570.0,
    "magnet": 70.0, "xp": 0, "next_xp": 60, "move_dir": Vector2.ZERO,
    "shots": 1, "pierce": 0, "orbit": 0, "orbit_damage": 20.0,
    "crit": 0.08, "combo": 0, "combo_timer": 0.0, "time_charge": 0.0, "weapon": 0
}
var bullets: Array = []
var enemy_bullets: Array = []
var enemies: Array = []
var drops: Array = []
var particles: Array = []
var texts: Array = []
var meta := {"echoes": 0, "loops": 0, "kills": 0, "best": 0, "dash_level": 0, "memory": 0}
var elapsed := 0.0
var score := 0
var fire_timer := 0.0
var spawn_timer := 0.0
var enemy_shot_timer := 0.0
var dash_timer := 0.0
var dash_flash := 0.0
var boss_spawned := false
var event20_done := false
var event40_done := false
var event30_done := false
var memory_message := ""
var game_over := false
var choosing := false
var upgrade_choices: Array = []
var touch_dir := Vector2.ZERO
var touch_active := false
var touch_start := Vector2.ZERO
var joystick_pos := Vector2(105, H-125)
var dash_pos := Vector2(W-105, H-125)
var dash_touch_id := -1
var rng_seed := 0
var anomalies: Array = []
var anomaly_timer := 0.0
var anomaly_active := false
var anomaly_type := ""
var anomaly_time := 0.0
var loop_rule := ""
var rule_multiplier := 1.0
var ghost_path: Array = []
var ghost_path_buffer: Array = []
var ghost_timer := 0.0
var ghost_index := 0
var ghost_fire_timer := 0.0
var ghost_weapon := 0
var frenzy_timer := 0.0
var boss_phase := 0
var boss_attack_timer := 2.0
var screen_flash := 0.0
var pulse_ring := 0.0
var ritual_level := 0
var ritual_timer := 0.0
var ritual_charge := 0
var damage_flash := 0.0
var boss_telegraph := 0.0
var room_index := 1
var portal_active := false
var portal_pos := Vector2.ZERO
var portal_pulse := 0.0
var room_message := ""
var stalker_spawned := false
var chamber_theme := 0

var ui: CanvasLayer
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var info: Label
var banner: Label
var hint: Label
var rule_label: Label
var dash_button: Button
var pulse_button: Button
var upgrade_panel: Panel
var choice_buttons: Array[Button] = []

func _ready() -> void:
    rng.randomize()
    _load_save()
    _build_ui()
    _new_loop()
    queue_redraw()

func _new_loop() -> void:
    elapsed = 0.0
    score = 0
    enemies.clear()
    bullets.clear()
    enemy_bullets.clear()
    drops.clear()
    particles.clear()
    texts.clear()
    player.pos = Vector2(W/2, H/2+100)
    player.hp = player.max_hp
    player.xp = 0
    player.next_xp = 60
    player.move_dir = Vector2.ZERO
    boss_spawned = false
    event20_done = false
    event40_done = false
    event30_done = false
    choosing = false
    anomalies.clear()
    anomaly_timer = 8.0
    anomaly_active = false
    anomaly_type = ""
    anomaly_time = 0.0
    ghost_timer = 0.0
    ghost_index = 0
    ghost_fire_timer = 1.0
    ghost_weapon = int(player.weapon)
    frenzy_timer = 0.0
    ritual_level = 0
    ritual_timer = 0.0
    ritual_charge = 0
    damage_flash = 0.0
    boss_telegraph = 0.0
    boss_phase = 0
    boss_attack_timer = 2.0
    room_index = 1
    portal_active = false
    portal_pos = Vector2.ZERO
    portal_pulse = 0.0
    room_message = "CHAMBER I"
    stalker_spawned = false
    chamber_theme = 0
    ghost_path_buffer.clear()
    _choose_loop_rule()
    player.combo = 0
    player.combo_timer = 0.0
    player.time_charge = 0.0
    player.weapon = int(meta.memory) % 3
    game_over = false
    touch_dir = Vector2.ZERO
    touch_active = false
    dash_timer = 0.0
    dash_flash = 0.0
    _apply_meta_bonus()
    if meta.loops > 0:
        memory_message = "MEMORY %d — %s" % [int(meta.memory), _memory_name()]
    else:
        memory_message = ""
    _announce("LOOP %02d — LEARN FAST" % (meta.loops + 1))
    queue_redraw()

func _apply_meta_bonus() -> void:
    var e: int = int(meta.echoes)
    player.damage = 18.0 + min(e, 20) * 1.5
    player.max_hp = 100.0 + min(e, 20) * 3.0
    player.speed = 230.0 + min(e, 15) * 2.0
    player.magnet = 70.0 + min(e, 12) * 5.0
    var mem: int = int(meta.memory)
    if mem == 1:
        player.crit = 0.14
    elif mem == 2:
        player.fire_rate *= 0.90
    elif mem >= 3:
        player.speed *= 1.10
    if meta.has("relics") and data_relic("BLOOD CLOCK"):
        player.max_hp += 20.0
        player.hp = player.max_hp
    if meta.has("relics") and data_relic("DEEP MAGNET"):
        player.magnet *= 1.35
    if meta.has("relics") and data_relic("ECHO ARMOUR"):
        player.max_hp += 15.0
        player.hp = player.max_hp
    if meta.has("relics") and data_relic("GHOST HAND"):
        player.shot_speed *= 1.12
    if meta.has("relics") and data_relic("PARADOX CORE"):
        player.crit = min(0.35, player.crit + 0.05)

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    info = Label.new()
    info.position = Vector2(24, 16)
    info.size = Vector2(672, 34)
    info.add_theme_font_size_override("font_size", 22)
    ui.add_child(info)
    hp_bar = ProgressBar.new()
    hp_bar.position = Vector2(24, 55)
    hp_bar.size = Vector2(210, 16)
    hp_bar.show_percentage = false
    ui.add_child(hp_bar)
    xp_bar = ProgressBar.new()
    xp_bar.position = Vector2(250, 55)
    xp_bar.size = Vector2(446, 16)
    xp_bar.show_percentage = false
    ui.add_child(xp_bar)
    banner = Label.new()
    banner.position = Vector2(24, 86)
    banner.size = Vector2(672, 42)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.add_theme_font_size_override("font_size", 20)
    ui.add_child(banner)
    rule_label = Label.new()
    rule_label.position = Vector2(24, 122)
    rule_label.size = Vector2(672, 30)
    rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule_label.add_theme_font_size_override("font_size", 16)
    ui.add_child(rule_label)
    hint = Label.new()
    hint.position = Vector2(28, H-205)
    hint.size = Vector2(300, 35)
    hint.text = "MOVE"
    hint.add_theme_font_size_override("font_size", 16)
    ui.add_child(hint)
    dash_button = Button.new()
    dash_button.position = Vector2(W-185, H-205)
    dash_button.size = Vector2(155, 48)
    dash_button.text = "BLINK"
    dash_button.add_theme_font_size_override("font_size", 18)
    dash_button.pressed.connect(_dash)
    ui.add_child(dash_button)
    pulse_button = Button.new()
    pulse_button.position = Vector2(W-185, H-150)
    pulse_button.size = Vector2(155, 48)
    pulse_button.text = "TIME PULSE"
    pulse_button.add_theme_font_size_override("font_size", 16)
    pulse_button.pressed.connect(_time_pulse)
    ui.add_child(pulse_button)
    upgrade_panel = Panel.new()
    upgrade_panel.position = Vector2(45, 390)
    upgrade_panel.size = Vector2(630, 500)
    upgrade_panel.visible = false
    ui.add_child(upgrade_panel)
    var title := Label.new()
    title.name = "Title"
    title.position = Vector2(20, 18)
    title.size = Vector2(590, 45)
    title.text = "CHOOSE AN ECHO"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    upgrade_panel.add_child(title)
    for i in 3:
        var b := Button.new()
        b.position = Vector2(35, 85 + i*125)
        b.size = Vector2(560, 96)
        b.add_theme_font_size_override("font_size", 19)
        upgrade_panel.add_child(b)
        choice_buttons.append(b)
        b.pressed.connect(_choose_upgrade.bind(i))

func _process(delta: float) -> void:
    dash_flash = max(0.0, dash_flash-delta)
    ritual_timer = max(0.0, ritual_timer-delta)
    damage_flash = max(0.0, damage_flash-delta)
    boss_telegraph = max(0.0, boss_telegraph-delta)
    if choosing:
        queue_redraw()
        return
    if game_over:
        queue_redraw()
        return
    elapsed += delta
    fire_timer -= delta
    spawn_timer -= delta
    enemy_shot_timer -= delta
    dash_timer = max(0.0, dash_timer-delta)
    anomaly_time = max(0.0, anomaly_time-delta)
    anomaly_active = anomaly_time > 0.0
    player.combo_timer = max(0.0, float(player.combo_timer)-delta)
    if ritual_timer <= 0.0:
        ritual_level = 0
    frenzy_timer = max(0.0, frenzy_timer-delta)
    if player.combo_timer <= 0.0:
        player.combo = 0
    if elapsed >= 50.0 and not stalker_spawned:
        _spawn_echo_stalker()
        stalker_spawned = true
    if elapsed >= LOOP_LENGTH:
        _complete_loop()
        return
    _input_move()
    _move_player(delta)
    if ghost_path_buffer.is_empty() or ghost_path_buffer[-1].distance_to(player.pos) > 45.0:
        ghost_path_buffer.append(player.pos)
        if ghost_path_buffer.size() > 48:
            ghost_path_buffer.pop_front()
    _auto_fire()
    _update_orbit()
    _spawn_enemies(delta)
    _update_anomalies(delta)
    _update_room_portal(delta)
    _update_ghost(delta)
    _update_bullets(delta)
    _update_enemy_bullets(delta)
    _update_enemies(delta)
    _update_drops(delta)
    _update_particles(delta)
    _update_texts(delta)
    _check_level_up()
    _update_ui()
    queue_redraw()

func _input_move() -> void:
    var d := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if touch_active:
        d = touch_dir
    if d.length() > 1.0:
        d = d.normalized()
    player.move_dir = d

func _move_player(delta: float) -> void:
    player.pos += player.move_dir * player.speed * delta
    player.pos.x = clamp(player.pos.x, WORLD.position.x+20, WORLD.end.x-20)
    player.pos.y = clamp(player.pos.y, WORLD.position.y+20, WORLD.end.y-20)

func _dash() -> void:
    if game_over or choosing or dash_timer > 0.0:
        return
    var d: Vector2 = player.move_dir
    if d.length() < 0.1:
        d = Vector2.UP
    player.pos += d.normalized() * 145.0
    player.pos.x = clamp(player.pos.x, WORLD.position.x+25, WORLD.end.x-25)
    player.pos.y = clamp(player.pos.y, WORLD.position.y+25, WORLD.end.y-25)
    dash_timer = max(1.4, 3.2 - int(meta.dash_level)*0.25)
    dash_flash = 0.22
    for e in enemies:
        if player.pos.distance_to(e.pos) < 125:
            e.hp -= player.damage * 1.8
    _burst(player.pos, 22, 260)

func _time_pulse() -> void:
    if game_over or choosing or float(player.time_charge) < 1.0:
        return
    player.time_charge = float(player.time_charge) - 1.0
    for e in enemies:
        var dist: float = player.pos.distance_to(e.pos)
        if dist < 260.0:
            e.hp -= player.damage * 0.9
    enemy_bullets.clear()
    _burst(player.pos,35,320)
    _announce("TIME PULSE")

func data_relic(name: String) -> bool:
    return name in meta.get("relics", [])

func _choose_loop_rule() -> void:
    var rules := ["RAPID LOOP", "HEAVY WORLD", "GREEDY WORLD", "HUNGRY WORLD", "CLEAR SKIES"]
    loop_rule = rules[rng.randi_range(0, rules.size()-1)]
    rule_multiplier = 1.0
    match loop_rule:
        "RAPID LOOP": rule_multiplier = 1.18
        "HEAVY WORLD": rule_multiplier = 0.86
        "GREEDY WORLD": rule_multiplier = 1.0
        "HUNGRY WORLD": rule_multiplier = 1.08
        "CLEAR SKIES": rule_multiplier = 0.95

func _spawn_anomaly() -> void:
    var types := ["HEAL", "GAMBLE", "ECHO", "STASIS"]
    anomaly_type = types[rng.randi_range(0, types.size()-1)]
    var p := Vector2(rng.randf_range(WORLD.position.x+80,WORLD.end.x-80), rng.randf_range(WORLD.position.y+100,WORLD.end.y-80))
    anomalies.append({"pos":p,"type":anomaly_type,"life":14.0,"r":34.0})
    _announce("ANOMALY — %s" % anomaly_type)

func _update_anomalies(delta: float) -> void:
    anomaly_timer -= delta
    if anomaly_timer <= 0.0 and anomalies.size() < 1 and elapsed > 7.0 and elapsed < 54.0:
        anomaly_timer = rng.randf_range(11.0,17.0)
        _spawn_anomaly()
    for i in range(anomalies.size()-1,-1,-1):
        var a: Dictionary = anomalies[i]
        a.life -= delta
        if a.pos.distance_to(player.pos) < a.r + 20.0:
            _trigger_anomaly(a.type)
            anomalies.remove_at(i)
        elif a.life <= 0.0:
            anomalies.remove_at(i)
        else:
            anomalies[i] = a

func _trigger_anomaly(kind: String) -> void:
    match kind:
        "HEAL":
            player.hp = min(player.max_hp, player.hp + 35.0)
            player.time_charge = min(6.0, float(player.time_charge)+1.0)
            score += 120
            _announce("ANOMALY STABILIZED — +HP +TIME")
        "GAMBLE":
            score += 500
            for i in 4:
                _spawn_enemy(1.8, true)
            _announce("ANOMALY GAMBLE — +500 / ELITES AWAKEN")
        "ECHO":
            player.damage *= 1.22
            player.fire_rate *= 0.82
            score += 250
            _announce("ECHO OVERDRIVE — WEAPON EVOLVED")
        "STASIS":
            anomaly_active = true
            anomaly_time = 4.0
            score += 180
            _announce("STASIS — TIME CRACKS")
    _burst(player.pos,28,260)

func _update_ghost(delta: float) -> void:
    if ghost_path.is_empty() or meta.loops <= 0:
        return
    ghost_timer -= delta
    ghost_fire_timer -= delta
    if ghost_timer <= 0.0:
        ghost_timer = 0.55
        ghost_index = (ghost_index + 1) % ghost_path.size()
        var gp: Vector2 = ghost_path[ghost_index]
        for e in enemies:
            if gp.distance_to(e.pos) < 82.0:
                e.hp -= 18.0 + float(meta.loops) * 1.5
        _burst(gp,4,80)
    if ghost_fire_timer <= 0.0:
        ghost_fire_timer = 1.55 if ghost_weapon != 1 else 1.15
        var target: Dictionary = _nearest_enemy_from(ghost_path[ghost_index])
        if not target.is_empty():
            var gp: Vector2 = ghost_path[ghost_index]
            var gd: Vector2 = (target.pos-gp).normalized()
            var gshots: int = 2 if ghost_weapon == 2 else 1
            for i in gshots:
                var spread: float = (float(i)-float(gshots-1)/2.0)*0.12
                bullets.append({"pos":gp,"vel":gd.rotated(spread)*480.0,"damage":10.0+float(meta.loops)*2.0,"life":1.2,"pierce":1,"ghost":true})

func _nearest_enemy_from(origin: Vector2) -> Dictionary:
    var best: Dictionary = {}
    var bd: float = INF
    for e in enemies:
        var d: float = origin.distance_squared_to(e.pos)
        if d < bd:
            bd = d
            best = e
    return best

func _memory_name() -> String:
    match int(meta.memory):
        1: return "TRUE SIGHT"
        2: return "RAPID THOUGHT"
        3: return "HUNTER'S INSTINCT"
        _: return "DORMANT"

func _auto_fire() -> void:
    if fire_timer > 0.0:
        return
    var target: Dictionary = _nearest_enemy()
    if target.is_empty():
        return
    fire_timer = player.fire_rate * (0.58 if frenzy_timer > 0.0 else 1.0)
    var dir: Vector2 = (target.pos - player.pos).normalized()
    if int(player.weapon) == 1:
        dir = dir.rotated(sin(elapsed*4.0)*0.05)
    var shots: int = int(player.shots)
    for i in shots:
        var spread: float = (float(i) - float(shots-1)/2.0) * 0.10
        var shot_dir: Vector2 = dir.rotated(spread)
        var bullet_damage: float = player.damage * (1.25 if int(player.weapon)==2 else 1.0) * (1.35 if frenzy_timer > 0.0 else 1.0)
        bullets.append({"pos":player.pos, "vel":shot_dir*player.shot_speed, "damage":bullet_damage, "life":1.7, "pierce":int(player.pierce)})
    _burst(player.pos, 2, 90)

func _nearest_enemy() -> Dictionary:
    var best: Dictionary = {}
    var bd: float = INF
    for e in enemies:
        var d: float = player.pos.distance_squared_to(e.pos)
        if d < bd:
            bd = d
            best = e
    return best

func _update_room_portal(delta: float) -> void:
    portal_pulse += delta
    # Optional portal windows at 20s and 40s. The player can ignore them and keep fighting.
    if not portal_active and room_index < 3 and elapsed >= float(room_index * 20 - 2):
        portal_active = true
        portal_pos = Vector2(
            WORLD.position.x + 72.0 if room_index % 2 == 1 else WORLD.end.x - 72.0,
            rng.randf_range(WORLD.position.y + 170.0, WORLD.end.y - 170.0)
        )
        room_message = "EXIT OPEN — CHAMBER %s" % ("II" if room_index == 1 else "III")
        _announce(room_message)
    if portal_active and portal_pos.distance_to(player.pos) < 54.0:
        _enter_room()

func _enter_room() -> void:
    portal_active = false
    room_index += 1
    chamber_theme = (chamber_theme + 1) % 4
    enemies.clear()
    enemy_bullets.clear()
    bullets.clear()
    anomalies.clear()
    score += 350 * room_index
    player.time_charge = min(6.0, float(player.time_charge) + 1.0)
    player.hp = min(player.max_hp, player.hp + 12.0)
    if room_index == 2:
        _announce("CHAMBER II — PRESSURE RISES")
    else:
        _announce("CHAMBER III — THE LOOP IS THIN")
    for i in 4 + room_index * 2:
        _spawn_enemy((1.25 + float(room_index) * 0.25), i % 3 == 0)
    _burst(player.pos, 34, 300)

func _spawn_enemies(delta: float) -> void:
    var room_pressure: float = 1.0 + float(max(0, room_index - 1)) * 0.18
    var intensity: float = (1.0 + elapsed/38.0 + float(meta.loops)*0.04) * rule_multiplier * room_pressure
    if spawn_timer <= 0.0:
        spawn_timer = max(0.18, 0.78-elapsed*0.005)
        var count: int = 1
        if rng.randf() < min(0.5, elapsed/110.0):
            count += 1
        for i in count:
            _spawn_enemy(intensity)
    if not event20_done and elapsed >= 20.0:
        event20_done = true
        _announce("HUNT — ELITES INCOMING")
        for i in 5:
            _spawn_enemy(intensity*1.3, true)
    if not event30_done and elapsed >= 30.0:
        event30_done = true
        _announce("RIFT — TIME IS FRAGILE")
        for i in 2:
            _spawn_enemy(intensity*1.8, true)
    if not event40_done and elapsed >= 40.0:
        event40_done = true
        _announce("FRACTURE — THE LOOP SPEEDS UP")
        for i in 8:
            _spawn_enemy(intensity*1.5, false)
    if not boss_spawned and elapsed >= 45.0:
        boss_spawned = true
        _spawn_boss()

func _spawn_enemy(intensity: float, force_elite: bool = false) -> void:
    var side := rng.randi_range(0,3)
    var p := Vector2.ZERO
    if side == 0:
        p = Vector2(rng.randf_range(WORLD.position.x,WORLD.end.x),WORLD.position.y+8)
    elif side == 1:
        p = Vector2(WORLD.end.x-8,rng.randf_range(WORLD.position.y,WORLD.end.y))
    elif side == 2:
        p = Vector2(rng.randf_range(WORLD.position.x,WORLD.end.x),WORLD.end.y-8)
    else:
        p = Vector2(WORLD.position.x+8,rng.randf_range(WORLD.position.y,WORLD.end.y))
    var roll: float = rng.randf()
    var elite: bool = force_elite or roll < min(0.13, elapsed/450.0)
    var kind: String = "chaser"
    if not elite and roll > 0.72:
        kind = "shooter"
    elif not elite and roll > 0.52:
        kind = "swift"
    var hp: float = (30.0+elapsed*1.7)*intensity*(2.0 if elite else 1.0)
    var speed: float = 70.0+elapsed*1.2
    if kind == "swift": speed *= 1.45
    if kind == "shooter": speed *= 0.72
    if elite: speed += 28.0
    enemies.append({"pos":p,"hp":hp,"max_hp":hp,"speed":speed,"r":22.0 if elite else 15.0,"elite":elite,"kind":kind,"xp":14 if elite else 6,"shot_cd":rng.randf_range(1.0,2.5)})

func _spawn_echo_stalker() -> void:
    var hp: float = 260.0 + float(meta.loops) * 55.0
    var spawn_pos := WORLD.get_center() + Vector2(0, -250)
    if not ghost_path.is_empty():
        spawn_pos = ghost_path[ghost_path.size() / 2]
    enemies.append({
        "pos": spawn_pos,
        "hp": hp,
        "max_hp": hp,
        "speed": 105.0,
        "r": 24.0,
        "kind": "stalker",
        "xp": 45,
        "shot_cd": 1.8,
        "memory": true
    })
    _announce("SOMETHING REMEMBERS...")

func _spawn_boss() -> void:
    var hp: float = 900.0+float(meta.loops)*120.0
    enemies.append({"pos":Vector2(WORLD.get_center().x,WORLD.position.y+80),"hp":hp,"max_hp":hp,"speed":55.0,"r":55.0,"boss":true,"xp":150,"shot_cd":0.5})
    _announce("THE LOOP REMEMBERS YOU")

func _update_bullets(delta: float) -> void:
    for i in range(bullets.size()-1,-1,-1):
        var b: Dictionary = bullets[i]
        b.pos += b.vel*delta
        b.life -= delta
        var remove_bullet := false
        for j in range(enemies.size()-1,-1,-1):
            var e: Dictionary = enemies[j]
            if b.pos.distance_to(e.pos) < e.r+7.0:
                e.hp -= b.damage
                b.pierce -= 1
                _burst(b.pos,4,120)
                if e.hp <= 0.0:
                    _kill_enemy(j,e)
                if b.pierce < 0:
                    remove_bullet = true
                    break
        if remove_bullet or b.life <= 0.0 or not WORLD.grow(30).has_point(b.pos):
            bullets.remove_at(i)
        else:
            bullets[i] = b

func _update_enemy_bullets(delta: float) -> void:
    for i in range(enemy_bullets.size()-1,-1,-1):
        var b: Dictionary = enemy_bullets[i]
        b.pos += b.vel*delta
        b.life -= delta
        if b.pos.distance_to(player.pos) < 15.0:
            player.hp -= b.damage
            damage_flash = 0.16
            _burst(player.pos,6,100)
            enemy_bullets.remove_at(i)
            if player.hp <= 0.0:
                _die()
        elif b.life <= 0.0 or not WORLD.grow(40).has_point(b.pos):
            enemy_bullets.remove_at(i)
        else:
            enemy_bullets[i] = b

func _update_enemies(delta: float) -> void:
    if enemy_shot_timer <= 0.0:
        enemy_shot_timer = 0.45
    boss_attack_timer -= delta
    for i in range(enemies.size()-1,-1,-1):
        var e: Dictionary = enemies[i]
        var d: Vector2 = player.pos-e.pos
        var dist: float = d.length()
        if e.get("kind","") == "shooter" and dist < 430.0:
            if float(e.get("shot_cd",1.0)) <= 0.0:
                var shot_dir: Vector2 = d.normalized()
                enemy_bullets.append({"pos":e.pos,"vel":shot_dir*220.0,"damage":10.0,"life":4.0})
                e.shot_cd = 2.0
        else:
            if dist > 1.0:
                var move_speed: float = float(e.speed) * (0.18 if anomaly_active else 1.0)
                e.pos += d.normalized()*move_speed*delta
        e.shot_cd = float(e.get("shot_cd",1.0))-delta
        if e.has("boss"):
            var hp_ratio: float = float(e.hp)/float(e.max_hp)
            var new_phase: int = 2 if hp_ratio < 0.34 else (1 if hp_ratio < 0.67 else 0)
            if new_phase != boss_phase:
                boss_phase = new_phase
                _announce("BOSS PHASE %d" % (boss_phase+1))
                _burst(e.pos,30+boss_phase*15,260)
            if boss_attack_timer <= 0.0:
                boss_attack_timer = 2.2 if boss_phase == 0 else (1.55 if boss_phase == 1 else 1.0)
                boss_telegraph = 0.42
                var radial_count: int = 8+boss_phase*4
                for k in radial_count:
                    var a: float = float(k)*TAU/float(radial_count)+elapsed*0.35
                    enemy_bullets.append({"pos":e.pos,"vel":Vector2.from_angle(a)*(180.0+boss_phase*45.0),"damage":8.0+boss_phase*3.0,"life":4.0})
            if dist > 170.0:
                e.pos += d.normalized()*float(e.speed)*delta*0.35
        if dist < e.r+15.0:
            var contact: float = 22.0 if e.has("boss") else (11.0 if e.get("elite",false) else 8.0)
            player.hp -= contact*delta
            damage_flash = 0.08
            if player.hp <= 0.0:
                _die()
        enemies[i] = e

func _kill_enemy(index: int, e: Dictionary) -> void:
    enemies.remove_at(index)
    meta.kills += 1
    player.combo = int(player.combo) + 1
    player.combo_timer = 2.4 + float(ritual_charge)*0.35
    if int(player.combo) % 5 == 0:
        ritual_level = min(3, int(player.combo)/5)
        ritual_timer = 3.5
        var ritual_bonus: int = 80 * ritual_level
        score += ritual_bonus
        player.time_charge = min(6.0, float(player.time_charge)+0.25)
        _announce("RITUAL %d — +%d" % [ritual_level, ritual_bonus])
        _burst(e.pos, 10 + ritual_level*6, 210)
    if int(player.combo) == 10:
        frenzy_timer = 6.0
        _announce("FRENZY — 10 KILL CHAIN")
    if int(player.combo) == 20:
        player.time_charge = min(6.0, float(player.time_charge)+1.0)
        score += 1000
        _announce("PARADOX CHAIN — +1000")
    var combo_mult: float = 1.0 + min(3.0, float(player.combo) * 0.08)
    score += int(float(e.xp)*10.0*combo_mult)
    if rng.randf() < float(player.crit) and not e.has("boss"):
        score += int(e.xp)*8
        _announce("CRITICAL ECHO x%d" % int(player.combo))
    var amount: int = 1+rng.randi_range(0,2)
    if e.has("boss"):
        amount = 12
    drops.append({"pos":e.pos,"kind":"xp","value":int(e.xp),"life":20.0})
    if rng.randf() < 0.14 or e.has("boss"):
        drops.append({"pos":e.pos+Vector2(12,0),"kind":"echo","value":amount,"life":20.0})
    if rng.randf() < 0.08:
        drops.append({"pos":e.pos+Vector2(-10,0),"kind":"heal","value":18,"life":20.0})
    if rng.randf() < (0.035 if not e.has("boss") else 1.0):
        drops.append({"pos":e.pos+Vector2(0,12),"kind":"time","value":2.5,"life":16.0})
    _burst(e.pos,12 if not e.has("boss") else 35,180)

func _update_drops(delta: float) -> void:
    for i in range(drops.size()-1,-1,-1):
        var d: Dictionary = drops[i]
        d.life -= delta
        var dist: float = d.pos.distance_to(player.pos)
        if dist < float(player.magnet):
            d.pos = d.pos.move_toward(player.pos,min(500.0*delta,dist))
        if dist < 24.0:
            if d.kind == "xp":
                player.xp += int(d.value)
            elif d.kind == "echo":
                meta.echoes += int(d.value)
                _save()
            elif d.kind == "heal":
                player.hp = min(player.max_hp,player.hp+float(d.value))
            elif d.kind == "time":
                player.time_charge = min(6.0, float(player.time_charge)+float(d.value))
                _announce("TIME CHARGE +%0.1fs" % float(d.value))
            _burst(d.pos,8,150)
            drops.remove_at(i)
        elif d.life <= 0.0:
            drops.remove_at(i)
        else:
            drops[i] = d

func _check_level_up() -> void:
    if int(player.xp) >= int(player.next_xp):
        player.xp -= int(player.next_xp)
        player.next_xp = int(float(player.next_xp)*1.35)
        _open_upgrade()

func _open_upgrade() -> void:
    choosing = true
    upgrade_choices = []
    var pool: Array = [
        ["OVERCHARGE","Damage +35%",func(): player.damage *= 1.35],
        ["QUICK HANDS","Fire rate +25%",func(): player.fire_rate *= 0.75],
        ["PHASE BOOTS","Move speed +20%",func(): player.speed *= 1.20],
        ["SOUL MAGNET","Pickup range +70%",func(): player.magnet *= 1.70],
        ["IRON HEART","Max HP +30 and heal",func(): player.max_hp += 30.0; player.hp = player.max_hp],
        ["RICOCHET","Shot speed +25%",func(): player.shot_speed *= 1.25],
        ["TWIN FIRE","Fire an extra shot",func(): player.shots += 1],
        ["PIERCING","Shots pierce +1 enemy",func(): player.pierce += 1],
        ["VOID SHARDS","Orbiting shard damage +1",func(): player.orbit += 1; player.orbit_damage += 8.0],
        ["RITUAL MASTERY","Longer combo window + ritual power",func(): player.combo_timer += 1.5; ritual_charge += 1; player.damage *= 1.08]
    ]
    pool.shuffle()
    upgrade_choices = pool.slice(0,3)
    for i in 3:
        choice_buttons[i].text = str(upgrade_choices[i][0])+"\n"+str(upgrade_choices[i][1])
    upgrade_panel.visible = true

func _choose_upgrade(i: int) -> void:
    if i >= upgrade_choices.size():
        return
    var f: Callable = upgrade_choices[i][2]
    f.call()
    choosing = false
    upgrade_panel.visible = false
    _announce("ECHO ACQUIRED")

func _update_orbit() -> void:
    # Orbiting shards are handled visually and as a proximity weapon in _process.
    if int(player.orbit) <= 0:
        return
    var count: int = int(player.orbit)
    for e in enemies:
        var dist: float = player.pos.distance_to(e.pos)
        if dist < 65.0 + count*5.0:
            e.hp -= float(player.orbit_damage)*0.018*float(count)
            if e.hp <= 0.0:
                var idx: int = enemies.find(e)
                if idx >= 0:
                    _kill_enemy(idx,e)
                    break

func _complete_loop() -> void:
    ghost_path.clear()
    for p in ghost_path_buffer:
        ghost_path.append(p)
    meta.loops += 1
    meta.best = max(int(meta.best),score)
    var reward: int = 3+int(score/1000)
    meta.echoes += reward
    if meta.loops >= 2 and int(meta.memory) < 3:
        meta.memory += 1
        _announce("MEMORY UNLOCKED — %s" % _memory_name())
    if not meta.has("relics"):
        meta.relics = []
    if meta.loops in [3, 6, 9, 12, 15]:
        var relics := ["BLOOD CLOCK", "DEEP MAGNET", "ECHO ARMOUR", "GHOST HAND", "PARADOX CORE"]
        var relic: String = relics[(meta.loops/3)-1]
        if relic not in meta.relics:
            meta.relics.append(relic)
            _announce("PERMANENT RELIC — %s" % relic)
    _save()
    _announce("RESET — +%d ECHOES" % reward)
    await get_tree().create_timer(1.4).timeout
    _new_loop()

func _die() -> void:
    if game_over:
        return
    game_over = true
    meta.best = max(int(meta.best),score)
    _save()
    _announce("YOU DIED — TAP TO REWIND")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if game_over:
                _new_loop()
                return
            if event.position.x < 300.0 and event.position.y > H-300.0:
                touch_active = true
                touch_start = joystick_pos
                _set_touch_dir(event.position)
        else:
            touch_active = false
            touch_dir = Vector2.ZERO
    elif event is InputEventScreenDrag and touch_active:
        _set_touch_dir(event.position)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
        _new_loop()

func _set_touch_dir(p: Vector2) -> void:
    var offset: Vector2 = p-touch_start
    if offset.length() > 130.0:
        offset = offset.normalized()*130.0
    touch_dir = offset/130.0

func _burst(p: Vector2,n: int,speed: float) -> void:
    for i in n:
        particles.append({"pos":p,"vel":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(speed*0.4,speed),"life":rng.randf_range(0.25,0.65)})

func _announce(s: String) -> void:
    banner.text = s
    banner.modulate.a = 1.0

func _update_particles(delta: float) -> void:
    for i in range(particles.size()-1,-1,-1):
        var p: Dictionary = particles[i]
        p.pos += p.vel*delta
        p.vel *= 0.93
        p.life -= delta
        if p.life <= 0.0:
            particles.remove_at(i)
        else:
            particles[i] = p

func _update_texts(delta: float) -> void:
    for i in range(texts.size()-1,-1,-1):
        var t: Dictionary = texts[i]
        t.life -= delta
        t.pos.y -= 20.0*delta
        if t.life <= 0.0:
            texts.remove_at(i)
        else:
            texts[i] = t
    banner.modulate.a = max(0.0,banner.modulate.a-delta*0.25)

func _update_ui() -> void:
    var remain: float = max(0.0,LOOP_LENGTH-elapsed)
    info.text = "♥ %d/%d   ECHO %d   KILLS %d   x%d   LOOP %02d" % [int(player.hp),int(player.max_hp),int(meta.echoes),int(meta.kills),int(player.combo),int(meta.loops)+1]
    var fury_text: String = "   •   FRENZY %0.1fs" % frenzy_timer if frenzy_timer > 0.0 else ""
    if ritual_timer > 0.0:
        fury_text += "   •   RITUAL %d" % ritual_level
    rule_label.text = "%s   •   RULE: %s   •   TIME %0.1f%s" % [room_message, loop_rule, float(player.time_charge), fury_text]
    hp_bar.value = player.hp/player.max_hp*100.0
    xp_bar.value = float(player.xp)/float(player.next_xp)*100.0
    dash_button.text = "BLINK %0.1fs" % dash_timer if dash_timer > 0.0 else "BLINK"
    pulse_button.text = "PULSE %0.1fs" % float(player.time_charge) if float(player.time_charge) < 1.0 else "TIME PULSE"
    hint.text = "MOVE     %s" % memory_message if memory_message != "" else "MOVE"
    if not game_over and banner.modulate.a < 0.1:
        banner.text = "RESET IN %05.1fs" % remain

func _draw_floor() -> void:
    # Stone floor tiles with alternating slabs and subtle cracks.
    draw_rect(WORLD, Color("121522"))
    var tile := 48
    for y in range(int(WORLD.position.y), int(WORLD.end.y), tile):
        for x in range(int(WORLD.position.x), int(WORLD.end.x), tile):
            var ix := int((x-WORLD.position.x)/tile)
            var iy := int((y-WORLD.position.y)/tile)
            var base := Color("1b2030") if (ix+iy)%2 == 0 else Color("181d2b")
            draw_rect(Rect2(x+1,y+1,tile-2,tile-2), base)
            draw_line(Vector2(x+4,y+tile-3), Vector2(x+tile-8,y+tile-3), Color("0d1019"), 2)
            if (ix*7+iy*11)%9 == 0:
                draw_line(Vector2(x+12,y+16), Vector2(x+18,y+22), Color("0c0f18"), 2)
                draw_line(Vector2(x+18,y+22), Vector2(x+28,y+18), Color("0c0f18"), 2)
    draw_rect(WORLD, Color("69718c"), false, 4)
    draw_rect(WORLD.grow(-8), Color("080a10"), false, 2)

    # The labyrinth changes character between chambers.
    var theme_col := Color("6b78a8") if chamber_theme == 0 else Color("7f5ca8") if chamber_theme == 1 else Color("a05c55") if chamber_theme == 2 else Color("4f9aa0")
    draw_rect(WORLD.grow(-18), theme_col.darkened(0.72), false, 2)
    for i in 5:
        var a := elapsed*0.15 + float(i)*TAU/5.0
        var p := WORLD.get_center() + Vector2.from_angle(a)*(270.0 + sin(elapsed*0.7+float(i))*18.0)
        draw_circle(p, 3.0, theme_col)

func _draw_wall_details() -> void:
    # Heavy brick frame makes the playfield feel like a real dungeon.
    var top := WORLD.position.y
    var left := WORLD.position.x
    var right := WORLD.end.x
    var bottom := WORLD.end.y
    draw_rect(Rect2(left, top-26, WORLD.size.x, 26), Color("0b0d14"))
    draw_rect(Rect2(left, bottom, WORLD.size.x, 26), Color("0b0d14"))
    draw_rect(Rect2(left-26, top, 26, WORLD.size.y), Color("0b0d14"))
    draw_rect(Rect2(right, top, 26, WORLD.size.y), Color("0b0d14"))
    for y in range(int(top-22), int(bottom+4), 22):
        var off := 0 if int((y-top)/22)%2 == 0 else 18
        for x in range(int(left-18), int(right+18), 36):
            draw_rect(Rect2(x+off,y,32,18), Color("252a3a"), true)
            draw_rect(Rect2(x+off,y,32,18), Color("0b0e17"), false, 2)
    # Corner runes.
    for c in [Vector2(left+28,top+28),Vector2(right-28,top+28),Vector2(left+28,bottom-28),Vector2(right-28,bottom-28)]:
        draw_circle(c, 15, Color("2c3750"), false, 2)
        draw_arc(c, 10, elapsed*0.4, elapsed*0.4+PI*1.45, 18, Color("7358ff88"), 2)

func _draw_torches() -> void:
    var torches := [
        Vector2(WORLD.position.x+42,WORLD.position.y+92),
        Vector2(WORLD.end.x-42,WORLD.position.y+92),
        Vector2(WORLD.position.x+42,WORLD.end.y-92),
        Vector2(WORLD.end.x-42,WORLD.end.y-92),
        Vector2(W/2,WORLD.position.y+30),
        Vector2(W/2,WORLD.end.y-30)
    ]
    for i in torches.size():
        var t: Vector2 = torches[i]
        var flick := 1.0 + sin(elapsed*7.0+float(i))*0.12
        draw_circle(t, 34.0*flick, Color("ff8a3d12"))
        draw_circle(t, 20.0*flick, Color("ffb64d18"))
        draw_rect(Rect2(t+Vector2(-3,8),Vector2(6,18)),Color("5a3a2b"))
        draw_circle(t+Vector2(0,-2),7.0*flick,Color("ffcb62"))
        draw_circle(t+Vector2(0,-7),4.0*flick,Color("fff0a1"))

func _draw_portal_visual() -> void:
    if not portal_active:
        return
    var pp := 1.0 + sin(portal_pulse*7.0)*0.10
    draw_circle(portal_pos, 66.0*pp, Color("744cff16"))
    draw_circle(portal_pos, 48.0*pp, Color("8b6cff33"))
    draw_arc(portal_pos, 43.0*pp, -PI/2.0, PI*1.5, 40, Color("8d7cff"), 7.0)
    draw_arc(portal_pos, 32.0*pp, PI/2.0, PI*2.5, 32, Color("d6d0ff"), 4.0)
    draw_circle(portal_pos, 23.0, Color("070814"))
    for k in 6:
        var a := portal_pulse*1.8+float(k)*TAU/6.0
        var orbit_p := portal_pos+Vector2.from_angle(a)*(55.0*pp)
        draw_circle(orbit_p,5.0,Color("ffffff"))
    draw_string(ThemeDB.fallback_font, portal_pos+Vector2(-58,-62), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e7ddff"))

func _draw_drop_visual(d: Dictionary) -> void:
    var pulse := 1.0+sin(Time.get_ticks_msec()/130.0+float(d.pos.x))*0.12
    var c := Color("63f4ad") if d.kind=="xp" else Color("ffd85c") if d.kind=="echo" else Color("ff6f91") if d.kind=="heal" else Color("72c9ff")
    var p: Vector2 = d.pos
    draw_circle(p, 18.0*pulse, c.darkened(0.65))
    draw_circle(p, 12.0*pulse, c)
    draw_circle(p, 5.0, Color("ffffffcc"))
    if d.kind=="echo":
        draw_arc(p, 20.0*pulse, 0, TAU, 18, Color("ffd85c99"), 3)
    elif d.kind=="heal":
        draw_rect(Rect2(p-Vector2(3,9),Vector2(6,18)),Color("fff1f5"))
        draw_rect(Rect2(p-Vector2(9,3),Vector2(18,6)),Color("fff1f5"))
    elif d.kind=="time":
        draw_arc(p, 18.0*pulse, -PI/2, TAU-PI/2, 20, c, 3)

func _draw_enemy_visual(e: Dictionary) -> void:
    var p: Vector2 = e.pos
    var r: float = float(e.r)
    var is_boss := e.has("boss")
    var elite := bool(e.get("elite",false))
    var kind := str(e.get("kind","chaser"))
    var bob := sin(elapsed*5.0+p.x*0.01)*2.0
    p.y += bob
    var body := Color("e84d65") if is_boss else Color("a957ff") if elite else Color("ff7048") if kind=="chaser" else Color("4dd7ff") if kind=="swift" else Color("e8c35a")
    draw_circle(p+Vector2(0,5), r+6, Color("00000088"))
    if is_boss:
        draw_circle(p, r+14+sin(elapsed*3.0)*3.0, Color("ff335522"))
        draw_circle(p, r, Color("2a1522"))
        draw_circle(p, r-8, body)
        draw_arc(p, r+9, elapsed, elapsed+PI*1.55, 32, Color("ffb35a"), 5)
        draw_arc(p, r+18, -elapsed*0.7, -elapsed*0.7+PI*1.15, 24, Color("9c6cff"), 4)
        draw_circle(p+Vector2(-18,-5),7,Color("ffdb62"))
        draw_circle(p+Vector2(18,-5),7,Color("ffdb62"))
        draw_circle(p+Vector2(-18,-5),3,Color("3b0d18"))
        draw_circle(p+Vector2(18,-5),3,Color("3b0d18"))
        return
    if kind=="stalker":
        var pulse := 1.0 + sin(elapsed*9.0)*0.10
        draw_circle(p, r+9.0*pulse, Color("c58cff22"))
        draw_circle(p, r, Color("11101f"))
        draw_arc(p, r+5.0, elapsed*2.0, elapsed*2.0+PI*1.4, 24, Color("d5b4ff"), 4)
        draw_circle(p+Vector2(-7,-2),4,Color("ffffff"))
        draw_circle(p+Vector2(7,-2),4,Color("ff5cf0"))
        draw_line(p-Vector2(0,r+4), p+Vector2(0,r+13), Color("c58cffaa"), 3)
    elif kind=="shooter":
        draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p+Vector2(-r,0)]),body)
        draw_circle(p, r*0.43, Color("151927"))
        draw_circle(p, r*0.18, Color("fff0a0"))
    elif kind=="swift":
        var pts := PackedVector2Array([p+Vector2(0,-r-5),p+Vector2(r+4,0),p+Vector2(0,r+5),p+Vector2(-r+4,0)])
        draw_colored_polygon(pts,body)
        draw_line(p+Vector2(-r,0),p+Vector2(-r-12,0),body,4)
    else:
        draw_circle(p,r,body)
        draw_circle(p,r-5,Color("1a1724"))
        draw_circle(p+Vector2(-5,-2),4,Color("ff4d61"))
        draw_circle(p+Vector2(5,-2),4,Color("ff4d61"))
        draw_line(p+Vector2(-7,8),p+Vector2(7,8),body,3)
    if elite:
        draw_arc(p,r+6,elapsed,elapsed+TAU*0.75,24,Color("d9b5ff"),3)
    if float(e.get("max_hp",0.0))>0.0:
        var bar_w := r*2.2
        draw_rect(Rect2(p+Vector2(-bar_w/2,-r-15),Vector2(bar_w,5)),Color("090b12"))
        draw_rect(Rect2(p+Vector2(-bar_w/2,-r-15),Vector2(bar_w*clamp(float(e.hp)/float(e.max_hp),0.0,1.0),5)),Color("ff5c7a"))

func _draw_player_visual() -> void:
    var p: Vector2 = player.pos
    var d: Vector2 = player.get("move_dir",Vector2.UP)
    if d.length()<0.1:
        d=Vector2.UP
    var side := d.rotated(PI/2.0)
    var glow := Color("5ce1ff44") if dash_flash<=0.0 else Color("ffffff88")
    draw_circle(p, 40.0+sin(elapsed*6.0)*3.0, glow)
    draw_circle(p+Vector2(0,12), 23, Color("00000099"))
    var cloak := Color("263b59")
    var body_pts := PackedVector2Array([p+d*28.0,p-side*17.0-d*2.0,p-side*13.0-d*18.0,p+side*13.0-d*18.0,p+side*17.0-d*2.0])
    draw_colored_polygon(body_pts,cloak)
    draw_polyline(PackedVector2Array([p+d*28.0,p-side*17.0-d*2.0,p-side*13.0-d*18.0,p+side*13.0-d*18.0,p+side*17.0-d*2.0,p+d*28.0]),Color("6aa7d4"),3)
    draw_circle(p+d*3.0,11,Color("d6e6ef"))
    draw_circle(p+d*6.0+side*4.0,2.5,Color("ff5cf0"))
    draw_circle(p+d*6.0-side*4.0,2.5,Color("ff5cf0"))
    var gun_start := p+d*12.0+side*9.0
    draw_line(gun_start,gun_start+d*24.0,Color("b8c5d6"),6)
    draw_line(gun_start+d*3.0,gun_start+d*25.0,Color("ffca63"),3)
    if int(player.orbit)>0:
        for i in int(player.orbit):
            var a := elapsed*3.0+float(i)*TAU/float(player.orbit)
            var op := p+Vector2.from_angle(a)*(52.0+8.0*int(player.orbit))
            draw_circle(op,10,Color("a98cff"))
            draw_circle(op,16,Color("a98cff33"),false,3)

func _draw_hud_world() -> void:
    # Small, high-contrast markers that remain readable on a phone.
    if float(player.time_charge)>=1.0:
        draw_arc(player.pos,88.0+sin(elapsed*8.0)*7.0,0,TAU,40,Color("72dfff77"),4)
    if frenzy_timer>0.0:
        draw_arc(player.pos,56.0+sin(elapsed*14.0)*5.0,0,TAU,40,Color("ffd45c99"),5)
    if ritual_timer>0.0:
        draw_arc(player.pos,68.0+ritual_level*10.0+sin(elapsed*12.0)*4.0,-PI/2.0,-PI/2.0+TAU*float(ritual_level)/3.0,24,Color("ffd45c"),7)
    if pulse_ring>0.0:
        var pr := 90.0+(0.75-pulse_ring)*420.0
        draw_arc(player.pos,pr,0,TAU,48,Color("8fdcff") if pulse_ring>0.25 else Color("8fdcff55"),6)

func _draw() -> void:
    # VISUAL PASS: procedural dark-fantasy dungeon, built entirely from Godot primitives.
    draw_rect(Rect2(0,0,W,H),Color("070910"))
    draw_rect(Rect2(8,108,W-16,H-108),Color("0d111c"))
    _draw_floor()
    _draw_wall_details()
    _draw_torches()

    # Subtle moving atmosphere.
    draw_circle(Vector2(W/2,H/2+70),290.0+sin(elapsed*0.7)*10.0,Color("263b6010"))
    draw_circle(Vector2(W/2,H/2+70),250.0,Color("596aa020"),false,3)
    var grid_off := fmod(elapsed*10.0,96.0)
    for x in range(int(WORLD.position.x),int(WORLD.end.x),96):
        draw_line(Vector2(x+grid_off,WORLD.position.y+6),Vector2(x+grid_off,WORLD.end.y-6),Color("38415b14"),1)

    _draw_portal_visual()

    # Thin dimensional seams: the dungeon is beginning to come apart.
    for i in 4:
        var seam_x := WORLD.position.x + 120.0 + float(i)*150.0 + sin(elapsed*0.5+float(i))*28.0
        var seam_y := WORLD.position.y + 160.0 + fmod(elapsed*18.0+float(i)*220.0, WORLD.size.y-260.0)
        draw_line(Vector2(seam_x,seam_y), Vector2(seam_x+18.0,seam_y-34.0), Color("b98cff25"), 2)
        draw_line(Vector2(seam_x+18.0,seam_y-34.0), Vector2(seam_x+34.0,seam_y-6.0), Color("6fe9ff20"), 2)

    if elapsed > 50.0 and not stalker_spawned:
        draw_circle(player.pos, 130.0+sin(elapsed*10.0)*10.0, Color("c58cff22"), false, 5)

    for a in anomalies:
        var ac := Color("67f0c0") if a.type=="HEAL" else Color("ffd15c") if a.type=="GAMBLE" else Color("bd8cff") if a.type=="ECHO" else Color("72c9ff")
        var ap := 1.0+sin(Time.get_ticks_msec()/160.0)*0.12
        draw_circle(a.pos,float(a.r)*ap,ac.darkened(0.55),false,5)
        draw_circle(a.pos,12.0,ac)
        draw_circle(a.pos,5.0,Color("ffffff"))

    for d in drops:
        _draw_drop_visual(d)
    for b in bullets:
        draw_line(b.pos-b.vel.normalized()*12.0,b.pos,Color("fff3a1aa"),5)
        draw_circle(b.pos,7.0,Color("fff3a1"))
    for b in enemy_bullets:
        draw_line(b.pos-b.vel.normalized()*14.0,b.pos,Color("ff4f7588"),5)
        draw_circle(b.pos,8.0,Color("ff4f75"))

    for e in enemies:
        if e.has("boss") and boss_telegraph>0.0:
            draw_circle(e.pos,105.0+(0.42-boss_telegraph)*90.0,Color("ff557744"),false,6)
        _draw_enemy_visual(e)

    _draw_player_visual()

    if meta.loops>0 and not ghost_path.is_empty():
        for i in ghost_path.size():
            var gp: Vector2 = ghost_path[i]
            var alpha := 0.10+0.20*float(i%5)/5.0
            draw_circle(gp,4.0,Color(0.74,0.66,1.0,alpha))
    for p in particles:
        draw_circle(p.pos,max(1.0,float(p.life)*5.0),Color("ffffff"))

    _draw_hud_world()

    # Chamber marker.
    draw_rect(Rect2(W/2-86, WORLD.position.y+10, 172, 30), Color("070910aa"))
    draw_string(ThemeDB.fallback_font, Vector2(W/2-80, WORLD.position.y+31),
        "CHAMBER %s" % ["I","II","III","IV"][min(chamber_theme,3)],
        HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color("e6e3ff"))

    # Mobile controls.
    draw_circle(joystick_pos,72.0,Color("ffffff10"))
    draw_circle(joystick_pos,72.0,Color("ffffff66"),false,3)
    draw_circle(joystick_pos+touch_dir*45.0,29.0,Color("ffffff35"))
    draw_circle(joystick_pos+touch_dir*45.0,29.0,Color("ffffffaa"),false,2)

    if damage_flash>0.0:
        draw_rect(Rect2(0,0,W,H),Color(1,0.12,0.25,damage_flash*0.42))
    if game_over:
        draw_rect(Rect2(0,0,W,H),Color(0,0,0,0.62))
        draw_circle(Vector2(W/2,590),120,Color("ff557711"),false,5)
        draw_string(ThemeDB.fallback_font,Vector2(0,590),"THE LOOP CLAIMS YOU",HORIZONTAL_ALIGNMENT_CENTER,W,34,Color("ffffff"))
        draw_string(ThemeDB.fallback_font,Vector2(0,640),"TAP TO REWIND",HORIZONTAL_ALIGNMENT_CENTER,W,24,Color("d8cfff"))
func _save() -> void:
    var f: FileAccess = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(meta))
        f.close()

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        meta={"echoes":0,"loops":0,"kills":0,"best":0,"dash_level":0,"memory":0,"relics":[]}
        return
    var f := FileAccess.open(SAVE_PATH,FileAccess.READ)
    var data: Variant = JSON.parse_string(f.get_as_text())
    f.close()
    if data is Dictionary:
        for k in meta:
            if data.has(k):
                meta[k]=data[k]
        if not meta.has("relics"):
            meta.relics = []
    player.xp=0
    player.next_xp=60
    player.move_dir=Vector2.ZERO
