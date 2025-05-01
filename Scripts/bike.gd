extends CharacterBody3D
class_name Bike


@export var speed_limit_natural : float #limite de la velocidad de forma natural
@export var brake : float #freno de la moto
@export var brake_natural : float #freno natural debido a la friccion
@export var set_limit_speed : float #Nuevo limite de velocidad
@export var aceleration : float #La aceleracion
@export var limit_rot_x : float #limite de la rotacion en x 
@export var impulse_wheels : float #impulso en el giro de ruedas

@onready var bike_root : Node3D = $ModelRoot
@onready var rueda_delantera : Node3D = $ModelRoot/Manillar/Delantera
@onready var rueda_trasera : Node3D = $ModelRoot/Trasera
@onready var manillar : Node3D = $ModelRoot/Manillar
@onready var ray_forward : Node3D = $ModelRoot/Manillar/RayForward
@onready var ray_back : Node3D = $ModelRoot/RayBack
@onready var ray_choqueF : Node3D = $ModelRoot/RayChoqueForward
@onready var ray_choqueB : Node3D = $ModelRoot/RayChoqueBack

var speed : float #velocidad
var reduct : float = 2.0 #Redecut del torque de la moto

#Inputs XY
var inputs_x : int
var inputs_z : int

var impulsar : bool# Impulso de la moto

func _process(delta: float) -> void:
	inputs_x = Input.get_axis("ui_right","ui_left")
	inputs_z = Input.get_axis("ui_down","ui_up")

	if not is_on_floor():#Si no esta en el piso la gravedad afecta
		_impulse()
		velocity += get_gravity() * delta 
	if is_on_floor():
		impulsar = true

	if inputs_z != 0 and not Input.is_action_pressed("frenar"):#Aumenta la velocidad
		speed += inputs_z * aceleration
	elif inputs_z == 0 and not Input.is_action_pressed("frenar"):#Detiene la moto con la friccion
		speed = lerpf(speed,0,brake_natural * delta)
	elif Input.is_action_pressed("frenar"):#La moto se detiene con el freno
		speed = lerpf(speed,0,brake * delta)

	speed = clampf(speed,-1.0,speed_limit_natural)#Un limite a la velocidad para permitir un mejor controlo de la moto

	if speed != 0:#La velocidades se multiplican con velocidad dependiendo cual sea la direccion que apunte la moto
		velocity.z = get_global_transform().basis.z.z * speed 
		velocity.x = get_global_transform().basis.z.x * speed

	_rotation_bike()
	_choque()

	move_and_slide()

func _impulse():
#Para que la moto no caiga comoun plomo cuando se despega del piso se agrega un impulso
#Se podia agregar menos gravedad pero las pruebas no me convencieron
	if impulsar:
		velocity.z = speed * 2

func _rotation_bike():
	if inputs_z > 0:#Se aplica un reduccion al torque mientras mas velocidad tenga la moto
		reduct -= 0.001
	else:#Si la moto deja de ser acelerada el torque regresa a su punto de partida
		reduct = lerpf(reduct,2.0,0.5)
	reduct = clampf(reduct,0.1,1.0)#Se el agrega un limite a la reduccion del torque

	rotation_degrees.y += speed * inputs_x * reduct#Gira la moto en el eje X
	bike_root.rotation_degrees.x = lerpf(bike_root.rotation_degrees.x,30.0 * -inputs_x,0.05)#Hace girar el modela como si se estuviera recostando
	manillar.rotation_degrees.y = lerpf(manillar.rotation_degrees.y,inputs_x * 20,0.1)#Gira el manillar

	if wheels_rays() != 0:#Dependiendo la superficies donde se monte la moto reaccionara cambiando su rotacion
		rotation_degrees.x += wheels_rays() * abs(velocity.z)
	else:
		if abs(rotation_degrees.x) < limit_rot_x: rotation_degrees.x = lerpf(rotation_degrees.x,0.0,1.0)
		#Si la rotacion es menor al limite la moto regresa a su punto original

	rotation_wheels(speed * impulse_wheels)

func rotation_wheels(speed_rotation):#Rotacion de la ruedas cuando se mueven
	rueda_delantera.rotation_degrees.z += -speed_rotation
	rueda_trasera.rotation_degrees.z += -speed_rotation

func wheels_rays() -> float:#Detecta la rueda la cual no esta pegada a al superficie, hace que rote para simular fisicas como si estuviera cayendo
	var direction = 0.0
	var collide_forward 
	var collide_back

	if ray_back and ray_forward:
		collide_forward = ray_forward.get_collider()
		collide_back = ray_back.get_collider()

	if collide_forward and not collide_back:
		direction = -1.0
	elif collide_back and not collide_forward:
		direction = 1.0
	elif collide_back and collide_forward:
		direction = 0.0
	else:
		direction = -rotation_degrees.normalized().x

	direction = clampf(direction,-1.0,1.0)

	return direction


func _choque():#Si la moto choca con una pared esta baja su velocidad
	var collide_choqueF
	var collide_choqueB
	
	if ray_choqueF and ray_choqueB:
		collide_choqueB = ray_choqueB.get_collider()
		collide_choqueF = ray_choqueF.get_collider()
	
	if collide_choqueB is Bike or collide_choqueF is Bike:
		return

	elif collide_choqueB or collide_choqueF:
		speed = clampf(speed,-set_limit_speed,set_limit_speed)
