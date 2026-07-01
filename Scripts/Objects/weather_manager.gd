extends Node2D

# 1. The Output Signal (Broadcasts to the rest of the game)
signal weather_changed(new_weather_state: String)

# 2. Weather States
enum Weather { CLEAR, CLOUDY, OVERCAST, STORM }
var current_weather: Weather = Weather.CLEAR

# 3. Component Links
@export var cloud_material: ShaderMaterial # Drag your CanvasLayer ColorRect's material here
@export var rain_particles: GPUParticles2D # Optional: Drag a rain particle system here
@export var transition_time: float = 15.0  # How long the crossfade takes in seconds

# 4. The Weather Profiles (Target Shader Values)
var weather_profiles = {
	Weather.CLEAR: {
		"cloud_density": 0.75, # High density threshold = fewer clouds
		"shadow_core_color": Color(0.05, 0.1, 0.2, 0.2), # Very faint shadows
		"sun_rim_color": Color(1.0, 0.9, 0.6, 0.5), # Bright sun rims
		"warp_intensity": 0.5, # Calm air
		"time_speed": 0.2
	},
	Weather.CLOUDY: {
		"cloud_density": 0.5,
		"shadow_core_color": Color(0.05, 0.1, 0.2, 0.6),
		"sun_rim_color": Color(1.0, 0.9, 0.6, 0.4),
		"warp_intensity": 1.2,
		"time_speed": 0.5
	},
	Weather.OVERCAST: {
		"cloud_density": 0.2, # Low threshold = sky is mostly covered
		"shadow_core_color": Color(0.02, 0.05, 0.1, 0.8), # Dark, heavy shadows
		"sun_rim_color": Color(1.0, 0.9, 0.6, 0.0), # Sun is blocked, no rim light
		"warp_intensity": 0.8, 
		"time_speed": 0.3
	},
	Weather.STORM: {
		"cloud_density": 0.1, # Total blackout
		"shadow_core_color": Color(0.01, 0.02, 0.05, 0.9), # Pitch black storm clouds
		"sun_rim_color": Color(0.0, 0.0, 0.0, 0.0),
		"warp_intensity": 3.0, # Highly turbulent, aggressive warping
		"time_speed": 1.5 # Fast moving
	}
}

func _ready():
	# Optional: Start a timer to randomly change weather every 60 seconds
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 60.0
	timer.timeout.connect(_on_random_weather_trigger)
	timer.start()

# --- The Core Transition Logic ---
func transition_to_weather(new_state: Weather):
	if current_weather == new_state: 
		return # Prevent transitioning to the weather we already have
		
	current_weather = new_state
	var profile = weather_profiles[new_state]
	
	# Create a tween and set it to PARALLEL so all shader values change simultaneously
	var tween = get_tree().create_tween().set_parallel(true)
	
	# Tween every parameter in the profile dictionary
	for param_name in profile.keys():
		var target_value = profile[param_name]
		var property_path = "shader_parameter/" + param_name
		
		tween.tween_property(cloud_material, property_path, target_value, transition_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	
	# Handle Particle Systems (Rain)
	if rain_particles:
		if new_state == Weather.STORM:
			rain_particles.emitting = true
		elif new_state == Weather.CLEAR or new_state == Weather.CLOUDY:
			rain_particles.emitting = false # Let existing particles finish falling
			
	# Emit the signal so your Ants know to seek shelter, or UI updates!
	weather_changed.emit(Weather.keys()[new_state])

func _on_random_weather_trigger():
	# Picks a random weather state
	var random_state = Weather.values()[randi() % Weather.size()]
	transition_to_weather(random_state)
