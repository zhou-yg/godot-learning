shader_type spatial;

// 使用包裹光照，防止低模草片背光面死黑，保持像素风的明快感
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

// ==================== 完美复制地面的 Uniform 参数 ====================
uniform vec3 top_grass_bright : source_color = vec3(0.44, 0.72, 0.22); // 亮草绿
uniform vec3 top_grass_dark   : source_color = vec3(0.31, 0.58, 0.17); // 暗草绿

uniform float grass_scale = 0.05;       // 宏观草地群系色块大小（必须与地面一致）
uniform float color_layers = 3.0;       // 色彩阶梯分层数（必须与地面一致）
uniform sampler2D noise_large : hint_default_white, repeat_enable, filter_nearest;

uniform float grain_scale = 256.0;      // 表面像素颗粒缩放
uniform float grain_roughness = 0.95;

// ==================== 草体特有的动态控制参数 ====================
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.15;     // 像素风的摆动不宜过大，保持硬朗
uniform float wind_scale = 0.4;

varying vec3 v_world_pos;
varying vec3 v_instance_base_pos;       // 记录每棵草根部的世界坐标

void vertex() {
	// 1. 获取当前草顶点的绝对世界坐标
	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	v_world_pos = world_pos.xyz;
	
	// 2. 获取这棵草“根部”的绝对世界坐标（用于像素色块采样，防止整棵草在风中变色）
	vec4 instance_base = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	v_instance_base_pos = instance_base.xyz;
	
	// 3. 像素风摆动逻辑
	float wind_weight = 1.0 - UV.y; // 草尖晃动，草根固定
	
	// 制造随世界位置变化的波浪
	float wave = (v_instance_base_pos.x + v_instance_base_pos.z) * wind_scale;
	// 使用 floor 让风的动画带有一点点像素级的定格感（可选，若追求丝滑运动可去掉 floor）
	float time_snapped = floor(TIME * wind_speed * 12.0) / 12.0; 
	float wind_offset = sin(time_snapped + wave);
	
	VERTEX.x += wind_offset * wind_strength * wind_weight;
	VERTEX.z += wind_offset * (wind_strength * 0.4) * wind_weight;
	
	// 终极武器：将草的法线强制朝上，彻底抹平多面插片的局部光照黑块
	NORMAL = vec3(0.0, 1.0, 0.0);
}

// 完美复制地面的经典像素分层随机函数
float pixel_rand(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// --- 1. 复制地面：宏观草地色块计算 ---
	// 【核心修正】：使用草根部的位置 v_instance_base_pos 采样，确保单棵草不会因为风吹产生颜色撕裂
	vec2 large_uv = v_instance_base_pos.xz * grass_scale;
	float noise_raw = texture(noise_large, large_uv).r;
	float quantized_noise = floor(noise_raw * color_layers) / (color_layers - 1.0);
	
	// 混合出当前位置的绝对“草皮颜色”
	vec3 current_grass_color = mix(top_grass_dark, top_grass_bright, quantized_noise);
	
	// --- 2. 复制地面：微观像素噪点光影 ---
	// 草叶表面同样铺上像素微粒，由于草在动，用 v_world_pos 可以制造光影沙沙掠过的效果
	float grain_val = pixel_rand(v_world_pos.xz * grain_scale);
	
	// 纵向渐变：让草的底部稍微暗一点，增加草丛的层次感与厚重感
	float vertical_gradient = mix(0.75, 1.0, 1.0 - UV.y);
	
	// 结合像素噪点与渐变得到最终 ALBEDO
	vec3 final_color = current_grass_color * mix(0.92, 1.08, grain_val) * vertical_gradient;
	
	ALBEDO = final_color;
	
	// --- 3. 材质物理特性调优（杜绝黑面） ---
	ROUGHNESS = grain_roughness;
	SPECULAR = 0.0;
	
	// 借用 Backlight 把迎光面的绿意透射到背光面，使暗处依然保持明快的像素绿
	BACKLIGHT = final_color * 0.3;
}