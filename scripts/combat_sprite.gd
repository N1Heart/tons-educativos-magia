class_name CombatSprite
extends RefCounted

## Sprite animado de um lutador (criatura ou personagem) no retrato do combate.
## Cuida de: tocar as animações padrão (idle / ataque / dano / morte) com
## velocidades próprias, voltar ao idle depois de ataque e dano, ficar na
## última pose depois da morte, e encaixar o desenho no retrato.

const ESCALA_ANIM := {&"idle": 1.0, &"dano": 2.0, &"ataque": 2.0, &"morte": 1.5}
## Quanto do retrato o desenho pode ocupar e onde ficam os pés (fração da altura).
const ALTURA_MAX := 0.78
const LARGURA_MAX := 0.7
const BASE := 0.92

var no: Node2D            # nó que é posicionado/escalado (a criatura, ou o próprio sprite)
var spr: AnimatedSprite2D
var morto := false


func _init(p_no: Node2D, p_spr: AnimatedSprite2D) -> void:
	no = p_no
	spr = p_spr
	if spr == null or spr.sprite_frames == null:
		return
	for anim in [&"ataque", &"dano", &"morte"]:
		if spr.sprite_frames.has_animation(anim):
			spr.sprite_frames.set_animation_loop(anim, false)  # volta ao idle (ou fica na última pose)
	spr.animation_finished.connect(_on_fim)
	tocar(&"idle")


func tocar(anim: StringName) -> void:
	if spr == null or spr.sprite_frames == null or morto:
		return
	if not spr.sprite_frames.has_animation(anim):
		return
	if anim == &"morte":
		morto = true
	spr.speed_scale = ESCALA_ANIM.get(anim, 1.0)
	spr.play(anim)


func tocando(anim: StringName) -> bool:
	return spr != null and spr.is_playing() and spr.animation == anim


func _on_fim() -> void:
	if not morto:
		tocar(&"idle")


## Área ocupada pelo desenho (sem a margem transparente) no primeiro quadro de
## "idle", em coordenadas locais do sprite (considera flip_h e a posição do
## sprite). Rect2() vazio se não for possível medir.
static func area_visivel(spr: AnimatedSprite2D) -> Rect2:
	if spr == null or spr.sprite_frames == null or not spr.sprite_frames.has_animation(&"idle"):
		return Rect2()
	var tex := spr.sprite_frames.get_frame_texture(&"idle", 0)
	if tex == null:
		return Rect2()
	var img := tex.get_image()
	if img == null:
		return Rect2()
	var usado := img.get_used_rect()
	if usado.size == Vector2i.ZERO:
		return Rect2()
	var centro := Vector2(img.get_size()) / 2.0
	var r := Rect2(Vector2(usado.position) - centro, Vector2(usado.size))
	if spr.flip_h:
		r.position.x = -(r.position.x + r.size.x)
	return Rect2(r.position + spr.position, r.size)


## Ajusta tamanho e posição ao retrato: escala para caber (em passos inteiros
## quando ≥ 2, para manter os pixels nítidos), centraliza na horizontal e apoia
## os pés na base. 'escala_fixa' > 0 força um tamanho. Com vários lutadores no
## mesmo retrato (equipe), cada um usa a sua fatia: 'fatia' de 0 a 'total' - 1.
func encaixar(retrato: Control, escala_fixa: float = 0.0, fatia: int = 0, total: int = 1) -> void:
	if no == null or not is_instance_valid(no):
		return
	var largura := retrato.size.x / maxi(1, total)
	var centro_fatia := largura * (fatia + 0.5)
	var area := area_visivel(spr)
	if no == spr:
		area.position -= spr.position  # a posição do próprio sprite é o que estamos calculando
	var escala := escala_fixa
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		no.scale = Vector2.ONE * (escala if escala > 0.0 else 1.5)
		no.position = Vector2(centro_fatia, retrato.size.y * 0.5)
		return
	if escala <= 0.0:
		escala = minf(retrato.size.y * ALTURA_MAX / area.size.y, largura * LARGURA_MAX / area.size.x)
		escala = clampf(escala, 0.5, 4.0)
		if escala >= 2.0:
			escala = floorf(escala)
	no.scale = Vector2.ONE * escala
	var centro_x := (area.position.x + area.size.x * 0.5) * escala
	var base_y := (area.position.y + area.size.y) * escala
	no.position = Vector2(centro_fatia - centro_x, retrato.size.y * BASE - base_y)
