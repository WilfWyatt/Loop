extends Node2D

# LOOP v0.8 - MIRROR: the previous loop starts fighting beside you.
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
    boss_phase = 0
    boss_attack_timer = 2.0
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
    frenzy_timer = max(0.0, frenzy_timer-delta)
    if player.combo_timer <= 0.0:
        player.combo = 0
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

func _spawn_enemies(delta: float) -> void:
    var intensity: float = (1.0 + elapsed/38.0 + float(meta.loops)*0.04) * rule_multiplier
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
                var radial_count: int = 8+boss_phase*4
                for k in radial_count:
                    var a: float = float(k)*TAU/float(radial_count)+elapsed*0.35
                    enemy_bullets.append({"pos":e.pos,"vel":Vector2.from_angle(a)*(180.0+boss_phase*45.0),"damage":8.0+boss_phase*3.0,"life":4.0})
            if dist > 170.0:
                e.pos += d.normalized()*float(e.speed)*delta*0.35
        if dist < e.r+15.0:
            var contact: float = 22.0 if e.has("boss") else (11.0 if e.get("elite",false) else 8.0)
            player.hp -= contact*delta
            if player.hp <= 0.0:
                _die()
        enemies[i] = e

func _kill_enemy(index: int, e: Dictionary) -> void:
    enemies.remove_at(index)
    meta.kills += 1
    player.combo = int(player.combo) + 1
    player.combo_timer = 2.4
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
        ["VOID SHARDS","Orbiting shard damage +1",func(): player.orbit += 1; player.orbit_damage += 8.0]
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
    rule_label.text = "RULE: %s   •   TIME %0.1f%s" % [loop_rule, float(player.time_charge), fury_text]
    hp_bar.value = player.hp/player.max_hp*100.0
    xp_bar.value = float(player.xp)/float(player.next_xp)*100.0
    dash_button.text = "BLINK %0.1fs" % dash_timer if dash_timer > 0.0 else "BLINK"
    pulse_button.text = "PULSE %0.1fs" % float(player.time_charge) if float(player.time_charge) < 1.0 else "TIME PULSE"
    hint.text = "MOVE     %s" % memory_message if memory_message != "" else "MOVE"
    if not game_over and banner.modulate.a < 0.1:
        banner.text = "RESET IN %05.1fs" % remain

func _draw() -> void:
    draw_rect(Rect2(0,0,W,H),Color("10111c"))
    draw_rect(WORLD,Color("171b2b"))
    draw_rect(WORLD,Color("454a67"),false,3)
    var off: float = fmod(elapsed*18.0,60.0)
    for x in range(int(WORLD.position.x)-60,int(WORLD.end.x)+60,60):
        draw_line(Vector2(x+off,WORLD.position.y),Vector2(x+off,WORLD.end.y),Color("242942"),1)
    for y in range(int(WORLD.position.y)-60,int(WORLD.end.y)+60,60):
        draw_line(Vector2(WORLD.position.x,y+off),Vector2(WORLD.end.x,y+off),Color("242942"),1)
    for a in anomalies:
        var ac := Color("67f0c0") if a.type=="HEAL" else Color("ffd15c") if a.type=="GAMBLE" else Color("bd8cff") if a.type=="ECHO" else Color("72c9ff")
        var pulse := 1.0 + sin(Time.get_ticks_msec()/160.0)*0.10
        draw_circle(a.pos, float(a.r)*pulse, ac, false, 5)
        draw_circle(a.pos, 12.0, ac)
    for d in drops:
        var pulse: float = 1.0+sin(Time.get_ticks_msec()/130.0+float(d.pos.x))*0.12
        var c := Color("5cf2a5") if d.kind=="xp" else Color("ffd85c") if d.kind=="echo" else Color("ff6f91")
        draw_circle(d.pos,12.0*pulse,c)
        draw_circle(d.pos,20.0*pulse,c,false,3)
    for b in bullets:
        draw_circle(b.pos,7.0,Color("fff3a1"))
    for b in enemy_bullets:
        draw_circle(b.pos,8.0,Color("ff4f75"))
    for e in enemies:
        var c := Color("ff5577") if e.has("boss") else Color("b35cff") if e.get("elite",false) else Color("ff874d") if e.get("kind","") != "shooter" else Color("ffcf5c")
        draw_circle(e.pos,float(e.r),c)
        draw_circle(e.pos,float(e.r)+3.0,Color("ffffff55"),false,2)
        if float(e.get("max_hp",0.0)) > 0.0:
            draw_rect(Rect2(e.pos+Vector2(-e.r,-e.r-10),Vector2(e.r*2.0,4)),Color("351927"))
            draw_rect(Rect2(e.pos+Vector2(-e.r,-e.r-10),Vector2(e.r*2.0*float(e.hp)/float(e.max_hp),4)),Color("ff5c7a"))
    if int(player.orbit) > 0:
        for i in int(player.orbit):
            var a: float = elapsed*3.0+float(i)*TAU/float(player.orbit)
            var op: Vector2 = player.pos+Vector2.from_angle(a)*(48.0+8.0*int(player.orbit))
            draw_circle(op,9.0,Color("b9a1ff"))
            draw_circle(op,14.0,Color("b9a1ff55"),false,2)
    var d: Vector2 = player.get("move_dir",Vector2.UP)
    if d.length()<0.1:
        d=Vector2.UP
    var side: Vector2 = d.rotated(2.5)*18.0
    var tip: Vector2 = player.pos+d*30.0
    var ship_c := Color("ffffff") if dash_flash>0.0 else Color("5ce1ff")
    draw_colored_polygon(PackedVector2Array([tip,player.pos-side,player.pos-side*0.35-d*5.0,player.pos+side]),ship_c)
    if meta.loops > 0 and not ghost_path.is_empty():
        for gp in ghost_path:
            draw_circle(gp, 4.0, Color("bda8ff55"))
    for p in particles:
        draw_circle(p.pos,max(1.0,float(p.life)*5.0),Color("ffffff"))
    if float(player.time_charge) >= 1.0:
        draw_circle(player.pos, 90.0 + sin(elapsed*8.0)*8.0, Color("8fdcff55"), false, 4)
    if frenzy_timer > 0.0:
        draw_circle(player.pos, 52.0 + sin(elapsed*14.0)*6.0, Color("ffd45c66"), false, 5)
    draw_circle(joystick_pos,68.0,Color("ffffff18"))
    draw_circle(joystick_pos,68.0,Color("ffffff66"),false,3)
    var knob: Vector2 = joystick_pos+touch_dir*45.0
    draw_circle(knob,27.0,Color("ffffff38"))
    draw_circle(knob,27.0,Color("ffffffaa"),false,2)
    if game_over:
        draw_rect(Rect2(0,0,W,H),Color(0,0,0,0.55))
        draw_string(ThemeDB.fallback_font,Vector2(0,620),"TAP TO REWIND",HORIZONTAL_ALIGNMENT_CENTER,W,34,Color("ffffff"))

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
