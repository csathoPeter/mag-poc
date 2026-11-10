class_name Helix
extends Node3D
## A nagy pillanat: a kész tábla 36 bázispárja kettős spirállá csavarodik, maggá húzódik és a földbe hull.
## A tábla helyéről indul (a képernyőn ott, ahol a játékos kirakta), utána nő ki a növény.

signal landed

const AT := Color("#f0b35a")
const GC := Color("#55c6c0")
const BALL := Color("#f6efe0")
const DURATION := 3.3

var rungs := MultiMesh.new()
var balls := MultiMesh.new()
var t := 0.0
var running := false
var cell := .1
var center := Vector3.ZERO
var right := Vector3.RIGHT
var up := Vector3.UP
var axis_at := Vector3.ZERO  # a spirál tengelyének közepe
var ground := Vector3.ZERO  # ide hull a mag


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 10
	sph.rings = 6
	for pair in [[rungs, cyl, 36], [balls, sph, 72]]:
		var mm: MultiMesh = pair[0]
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = pair[1]
		mm.instance_count = pair[2]
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.extra_cull_margin = 16384.0
		add_child(inst)
	for i in 72:
		balls.set_instance_color(i, BALL)
	visible = false


## grid: a kész tábla (0 = A=T, 1 = G≡C); board_center és cell_size világkoordinátában, a kamera síkjában.
func start(grid: Array, board_center: Vector3, cell_size: float, cam_basis: Basis, axis_center: Vector3, ground_at: Vector3) -> void:
	for k in 36:
		rungs.set_instance_color(k, GC if grid[k / 6][k % 6] == 1 else AT)
	center = board_center
	cell = cell_size
	right = cam_basis.x
	up = cam_basis.y
	axis_at = axis_center
	ground = ground_at
	t = 0.0
	running = true
	visible = true
	_pose()


func advance(delta: float) -> void:
	if not running:
		return
	t += delta
	if t >= DURATION:
		running = false
		visible = false
		landed.emit()
		return
	_pose()


## Egy adott pillanat beállítása (képernyőképhez).
func pose_at(time: float) -> void:
	t = time
	_pose()


func _pose() -> void:
	var morph := smoothstep(0.0, 1.0, t / .95)
	var collapse := smoothstep(0.0, 1.0, (t - 1.95) / .75)
	var fall_raw := clampf((t - 2.7) / .55, 0.0, 1.0)
	var fall := fall_raw * fall_raw
	var spin := t * 2.4
	var rr := cell * 1.05
	var hs := cell * .34
	var seed_at := axis_at.lerp(ground, fall)
	for k in 36:
		var y := k / 6
		var x := k % 6
		var gc := center + right * ((x - 2.5) * cell) + up * ((2.5 - y) * cell)
		var th := k * .62 + spin
		var hc := axis_at + Vector3.UP * ((17.5 - k) * hs)
		var off := Vector3(cos(th), 0, sin(th)) * rr
		var a := (gc - right * cell * .36).lerp(hc + off, morph).lerp(seed_at, collapse)
		var b := (gc + right * cell * .36).lerp(hc - off, morph).lerp(seed_at, collapse)
		var d := b - a
		var length := maxf(d.length(), 1e-4)
		var q := Quaternion(Vector3.UP, d / length) if length > 1e-3 else Quaternion.IDENTITY
		var rw := cell * .06 * (1.0 - collapse * .8)
		rungs.set_instance_transform(k, Transform3D(Basis(q) * Basis.from_scale(Vector3(rw, length, rw)), (a + b) * .5))
		var br := cell * .14 * (1.0 - collapse * .35)
		var bb := Basis.from_scale(Vector3.ONE * br)
		balls.set_instance_transform(k * 2, Transform3D(bb, a))
		balls.set_instance_transform(k * 2 + 1, Transform3D(bb, b))
