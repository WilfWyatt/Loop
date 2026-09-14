extends Node2D

# LOOP - a one-minute roguelite built entirely from procedural shapes.
# No external assets required.

const W := 720.0
const H := 1280.0
const WORLD := Rect2(18, 122, 684, 1080)
const LOOP_LENGTH := 60.0
const SAVE_PATH := "user://loop_save.json"

var rng := RandomNumberGenerator.new()
var player := {"pos": Vector2(W/2, H/2+80), "hp": 100.0, "max_hp": 100.0, "speed": 230.0, "damage": 18.0, "fire_rate": 0.34, "shot_speed": 570.0, "magnet": 70.0, "xp": 0, "next_xp": 60, "move_dir": Vector2.ZERO}
var bullets: Array = []
var enemies: Array = []
var drops: Array = []
var particles: Array = []
var texts: Array = []
var upgrades: Array = []
var meta := {"echoes": 0, "loops": 0, "kills": 0, "best": 0}
var elapsed := 0.0
var score := 0
var fire_timer := 0.0
var spawn_timer := 0.0
var boss_spawned := false
var paused := false
var game_over := false
var choosing := false
var upgrade_choices: Array = []
var touch_dir := Vector2.ZERO
var touch_active := false
var touch_start := Vector2.ZERO
var joystick_pos := Vector2(105, H-125)
var rng_seed := 0

var ui: CanvasLayer
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var info: Label
var banner: Label
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
    enemies.clear(); bullets.clear(); drops.clear(); particles.clear(); texts.clear()
    player.pos = Vector2(W/2, H/2+100)
    player.hp = player.max_hp
    boss_spawned = false
    choosing = false
    paused = false
    game_over = false
    touch_dir = Vector2.ZERO
    touch_active = false
    _apply_meta_bonus()
    _announce("LOOP %02d — LEARN FAST" % (meta.loops + 1))
    queue_redraw()

func _apply_meta_bonus() -> void:
    player.damage = 18.0 + min(meta.echoes, 20) * 1.5
    player.max_hp = 100.0 + min(meta.echoes, 20) * 3.0
    player.speed = 230.0 + min(meta.echoes, 15) * 2.0

func _build_ui() -> void:
    ui = CanvasLayer.new(); add_child(ui)
    info = Label.new(); info.position = Vector2(24, 16); info.size = Vector2(672, 34)
    info.add_theme_font_size_override("font_size", 22); ui.add_child(info)
    hp_bar = ProgressBar.new(); hp_bar.position = Vector2(24, 55); hp_bar.size = Vector2(210, 16); hp_bar.show_percentage = false; ui.add_child(hp_bar)
    xp_bar = ProgressBar.new(); xp_bar.position = Vector2(250, 55); xp_bar.size = Vector2(446, 16); xp_bar.show_percentage = false; ui.add_child(xp_bar)
    banner = Label.new(); banner.position = Vector2(24, 86); banner.size = Vector2(672, 42)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; banner.add_theme_font_size_override("font_size", 20); ui.add_child(banner)
    upgrade_panel = Panel.new(); upgrade_panel.position = Vector2(55, 420); upgrade_panel.size = Vector2(610, 430); upgrade_panel.visible = false; ui.add_child(upgrade_panel)
    var title := Label.new(); title.name = "Title"; title.position = Vector2(20, 18); title.size = Vector2(570, 45); title.text = "CHOOSE AN ECHO"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 30); upgrade_panel.add_child(title)
    for i in 3:
        var b := Button.new(); b.position = Vector2(35, 80 + i*105); b.size = Vector2(540, 82); b.add_theme_font_size_override("font_size", 19); upgrade_panel.add_child(b); choice_buttons.append(b); b.pressed.connect(_choose_upgrade.bind(i))

func _process(delta: float) -> void:
    if choosing or paused: queue_redraw(); return
    if game_over:
        queue_redraw(); return
    elapsed += delta
    fire_timer -= delta; spawn_timer -= delta
    if elapsed >= LOOP_LENGTH:
        _complete_loop(); return
    _input_move()
    _move_player(delta)
    _auto_fire()
    _spawn_enemies(delta)
    _update_bullets(delta)
    _update_enemies(delta)
    _update_drops(delta)
    _update_particles(delta)
    _update_texts(delta)
    _check_level_up()
    _update_ui()
    queue_redraw()

func _input_move() -> void:
    var d := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if touch_active: d = touch_dir
    if d.length() > 1.0: d = d.normalized()
    player.move_dir = d

func _move_player(delta: float) -> void:
    player.pos += player.move_dir * player.speed * delta
    player.pos.x = clamp(player.pos.x, WORLD.position.x+20, WORLD.end.x-20)
    player.pos.y = clamp(player.pos.y, WORLD.position.y+20, WORLD.end.y-20)

func _auto_fire() -> void:
    if fire_timer > 0: return
    var target = _nearest_enemy()
    if target.is_empty(): return
    fire_timer = player.fire_rate
    var dir: Vector2 = (target.pos - player.pos).normalized()
    bullets.append({"pos": player.pos, "vel": dir * player.shot_speed, "damage": player.damage, "life": 1.7})
    _burst(player.pos, 2, 90)

func _nearest_enemy():
    var best: Dictionary = {}; var bd: float = INF
    for e in enemies:
        var d = player.pos.distance_squared_to(e.pos)
        if d < bd: bd = d; best = e
    return best

func _spawn_enemies(delta: float) -> void:
    var intensity: float = 1.0 + elapsed / 38.0 + float(meta.loops) * 0.04
    if spawn_timer <= 0:
        spawn_timer = max(0.22, 0.85 - elapsed*0.006)
        var count: int = 1
        if rng.randf() < min(0.45, elapsed/120.0): count += 1
        for i in count: _spawn_enemy(intensity)
    if not boss_spawned and elapsed >= 45.0:
        boss_spawned = true; _spawn_boss()

func _spawn_enemy(intensity: float) -> void:
    var side := rng.randi_range(0,3); var p := Vector2.ZERO
    if side == 0: p = Vector2(rng.randf_range(WORLD.position.x, WORLD.end.x), WORLD.position.y+8)
    elif side == 1: p = Vector2(WORLD.end.x-8, rng.randf_range(WORLD.position.y, WORLD.end.y))
    elif side == 2: p = Vector2(rng.randf_range(WORLD.position.x, WORLD.end.x), WORLD.end.y-8)
    else: p = Vector2(WORLD.position.x+8, rng.randf_range(WORLD.position.y, WORLD.end.y))
    var elite: bool = rng.randf() < min(0.12, elapsed/500.0)
    enemies.append({"pos":p,"hp":(32.0 + elapsed*1.7)*intensity*(2.0 if elite else 1.0),"max_hp":(32.0+elapsed*1.7)*intensity*(2.0 if elite else 1.0),"speed":70.0+elapsed*1.3+(30 if elite else 0),"r":(15.0 if not elite else 22.0),"elite":elite,"xp":(12 if elite else 5)})

func _spawn_boss() -> void:
    enemies.append({"pos":Vector2(WORLD.get_center().x,WORLD.position.y+80),"hp":900.0+meta.loops*120,"max_hp":900.0+meta.loops*120,"speed":55.0,"r":55.0,"boss":true,"xp":120})
    _announce("THE LOOP REMEMBERS YOU")

func _update_bullets(delta: float) -> void:
    for i in range(bullets.size()-1,-1,-1):
        var b = bullets[i]; b.pos += b.vel*delta; b.life -= delta
        var hit := false
        for j in range(enemies.size()-1,-1,-1):
            var e = enemies[j]
            if b.pos.distance_to(e.pos) < e.r+7:
                e.hp -= b.damage; hit=true; _burst(b.pos,4,120)
                if e.hp <= 0: _kill_enemy(j,e)
                break
        if hit or b.life <= 0 or not WORLD.grow(30).has_point(b.pos): bullets.remove_at(i)

func _kill_enemy(index:int,e:Dictionary) -> void:
    enemies.remove_at(index); meta.kills += 1; score += int(e.xp)*10
    var amount := 1 + rng.randi_range(0,2)
    if e.has("boss"): amount = 12
    drops.append({"pos":e.pos,"kind":"xp","value":e.xp,"life":20.0})
    if rng.randf() < 0.14 or e.has("boss"): drops.append({"pos":e.pos+Vector2(12,0),"kind":"echo","value":amount,"life":20.0})
    if rng.randf() < 0.08: drops.append({"pos":e.pos+Vector2(-10,0),"kind":"heal","value":18,"life":20.0})
    _burst(e.pos,12,180)

func _update_enemies(delta: float) -> void:
    for e in enemies:
        var d:Vector2 = player.pos-e.pos
        if d.length()>1: e.pos += d.normalized()*e.speed*delta
        if e.pos.distance_to(player.pos) < e.r+15:
            player.hp -= (18.0 if e.has("boss") else 9.0)*delta
            if player.hp <= 0: _die()

func _update_drops(delta: float) -> void:
    for i in range(drops.size()-1,-1,-1):
        var d=drops[i]; d.life-=delta
        var dist=d.pos.distance_to(player.pos)
        if dist < player.magnet:
            d.pos=d.pos.move_toward(player.pos,min(500.0*delta,dist))
        if dist < 24:
            if d.kind=="xp": player.xp += d.value
            elif d.kind=="echo": meta.echoes += d.value; _save()
            elif d.kind=="heal": player.hp=min(player.max_hp,player.hp+d.value)
            _burst(d.pos,8,150); drops.remove_at(i)
        elif d.life<=0: drops.remove_at(i)

func _check_level_up() -> void:
    if player.get("xp",0) >= player.get("next_xp",60):
        player.xp -= player.next_xp; player.next_xp = int(player.next_xp*1.35); _open_upgrade()

func _open_upgrade() -> void:
    choosing=true; upgrade_choices=[]
    var pool=[
        ["OVERCHARGE","Damage +35%",func(): player.damage*=1.35],
        ["QUICK HANDS","Fire rate +25%",func(): player.fire_rate*=0.75],
        ["PHASE BOOTS","Move speed +20%",func(): player.speed*=1.2],
        ["SOUL MAGNET","Pickup range +70%",func(): player.magnet*=1.7],
        ["IRON HEART","Max HP +30 and heal",func(): player.max_hp+=30; player.hp=player.max_hp],
        ["RICOCHET","Shot speed +25%",func(): player.shot_speed*=1.25]
    ]
    pool.shuffle()
    upgrade_choices=pool.slice(0,3)
    for i in 3:
        choice_buttons[i].text = upgrade_choices[i][0]+"\n"+upgrade_choices[i][1]
    upgrade_panel.visible=true

func _choose_upgrade(i:int) -> void:
    if i>=upgrade_choices.size(): return
    var f=upgrade_choices[i][2]; f.call(); choosing=false; upgrade_panel.visible=false
    _announce("ECHO ACQUIRED")

func _complete_loop() -> void:
    meta.loops += 1; meta.best=max(meta.best,score); meta.echoes += 3 + int(score/1000); _save()
    _announce("RESET — +%d ECHOES" % (3 + int(score/1000)))
    await get_tree().create_timer(1.6).timeout
    _new_loop()

func _die() -> void:
    game_over=true; meta.best=max(meta.best,score); _save(); _announce("YOU DIED — TAP TO REWIND")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if game_over:
                _new_loop()
                return
            # Only touches in the lower-left joystick zone control movement.
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

func _set_touch_dir(p:Vector2) -> void:
    var offset := p - touch_start
    if offset.length() > 130.0:
        offset = offset.normalized() * 130.0
    touch_dir = offset / 130.0

func _burst(p:Vector2,n:int,speed:float) -> void:
    for i in n:
        particles.append({"pos":p,"vel":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(speed*0.4,speed),"life":rng.randf_range(.25,.65)})

func _announce(s:String) -> void:
    banner.text=s; banner.modulate.a=1.0

func _update_particles(delta:float)->void:
    for i in range(particles.size()-1,-1,-1):
        particles[i].pos += particles[i].vel*delta; particles[i].vel*=0.93; particles[i].life-=delta
        if particles[i].life<=0: particles.remove_at(i)

func _update_texts(delta:float)->void:
    for i in range(texts.size()-1,-1,-1):
        texts[i].life-=delta; texts[i].pos.y-=20*delta
        if texts[i].life<=0: texts.remove_at(i)
    banner.modulate.a=max(0.0,banner.modulate.a-delta*0.25)

func _update_ui() -> void:
    var remain=max(0.0,LOOP_LENGTH-elapsed)
    info.text="♥ %d/%d     ECHOES %d     KILLS %d     LOOP %02d" % [int(player.hp),int(player.max_hp),meta.echoes,meta.kills,meta.loops+1]
    hp_bar.value=player.hp/player.max_hp*100.0
    xp_bar.value=player.get("xp",0)/float(player.get("next_xp",60))*100.0
    banner.text="RESET IN %05.1fs" % remain if not game_over and banner.modulate.a<0.1 else banner.text

func _draw() -> void:
    draw_rect(Rect2(0,0,W,H),Color("10111c"))
    draw_rect(WORLD,Color("171b2b")); draw_rect(WORLD,Color("454a67"),false,3)
    # moving grid gives the loop a living-space feel
    var off=fmod(elapsed*18.0,60.0)
    for x in range(int(WORLD.position.x)-60,int(WORLD.end.x)+60,60): draw_line(Vector2(x+off,WORLD.position.y),Vector2(x+off,WORLD.end.y),Color("242942"),1)
    for y in range(int(WORLD.position.y)-60,int(WORLD.end.y)+60,60): draw_line(Vector2(WORLD.position.x,y+off),Vector2(WORLD.end.x,y+off),Color("242942"),1)
    for d in drops:
        var pulse=1.0+sin(Time.get_ticks_msec()/130.0+d.pos.x)*0.12
        var c=Color("5cf2a5") if d.kind=="xp" else Color("ffd85c") if d.kind=="echo" else Color("ff6f91")
        draw_circle(d.pos,9*pulse,c); draw_circle(d.pos,15*pulse,c, false,2)
    for b in bullets: draw_circle(b.pos,5,Color("fff3a1"))
    for e in enemies:
        var c=Color("ff5577") if e.has("boss") else Color("b35cff") if e.get("elite",false) else Color("ff874d")
        draw_circle(e.pos,e.r,c); draw_circle(e.pos,e.r+3,Color("ffffff55"),false,2)
        if e.get("max_hp",0)>0: draw_rect(Rect2(e.pos+Vector2(-e.r,-e.r-10),Vector2(e.r*2,4)),Color("351927")); draw_rect(Rect2(e.pos+Vector2(-e.r,-e.r-10),Vector2(e.r*2*e.hp/e.max_hp,4)),Color("ff5c7a"))
    # player ship
    var d:Vector2=player.get("move_dir",Vector2.UP); if d.length()<0.1: d=Vector2.UP
    var side=d.rotated(2.5)*13; var tip=player.pos+d*20
    draw_colored_polygon(PackedVector2Array([tip,player.pos-side,player.pos-side*0.35-d*5,player.pos+side]),Color("5ce1ff"))
    for p in particles: draw_circle(p.pos,max(1.0,p.life*5),Color("ffffff"))
    # Mobile virtual joystick.
    draw_circle(joystick_pos, 68, Color("ffffff18"))
    draw_circle(joystick_pos, 68, Color("ffffff66"), false, 3)
    var knob := joystick_pos + touch_dir * 45.0
    draw_circle(knob, 27, Color("ffffff38"))
    draw_circle(knob, 27, Color("ffffffaa"), false, 2)
    if game_over:
        draw_rect(Rect2(0,0,W,H),Color(0,0,0,0.55))
        draw_string(ThemeDB.fallback_font,Vector2(0,620),"TAP TO REWIND",HORIZONTAL_ALIGNMENT_CENTER,W,34,Color("ffffff"))

func _save()->void:
    var f: FileAccess = FileAccess.open(SAVE_PATH,FileAccess.WRITE); if f: f.store_string(JSON.stringify(meta)); f.close()

func _load_save()->void:
    if not FileAccess.file_exists(SAVE_PATH):
        meta={"echoes":0,"loops":0,"kills":0,"best":0}; return
    var f=FileAccess.open(SAVE_PATH,FileAccess.READ)
    var data: Variant = JSON.parse_string(f.get_as_text()); f.close()
    if data is Dictionary:
        for k in meta:
            if data.has(k): meta[k]=data[k]
    player.xp=0; player.next_xp=60; player.move_dir=Vector2.ZERO
