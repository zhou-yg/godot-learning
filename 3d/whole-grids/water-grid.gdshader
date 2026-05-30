shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.02, 0.15, 0.45); // 深邃的池水底色
uniform vec3 ripple_color : source_color = vec3(0.7, 0.9, 1.0);    // 清澈透亮的波光颜色

uniform float ripple_speed : hint_range(0.0, 1.0) = 0.15;       // 水流整体速度（调慢才自然）
uniform float ripple_scale : hint_range(0.005, 0.2) = 0.04;     // 波纹在场景中的宏观比例
uniform float ripple_sharpness : hint_range(1.0, 10.0) = 4.0;   // 决定水波是肥厚还是纤细清脆

uniform sampler2D noise_texture : repeat_enable; // 开启重复平铺

varying vec3 world_position;
varying vec3 world_normal; // 【新增】用来把世界法线从 vertex 传到 fragment

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 【核心修复 1】在顶点着色器中，利用模型矩阵将法线转换到世界空间
	// 使用做过正交化和逆矩阵转置处理的 MODEL_NORMAL_MATRIX 确保缩放时法线不失真
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	// 基础材质：极低粗糙度 + 稍高镜面反射 = 镜面水感
	ALBEDO = water_color;
	METALLIC = 0.0;
	ROUGHNESS = 0.02; 
	SPECULAR = 0.8;

	// 计算基础世界坐标 UV
	vec2 uv = world_position.xz * ripple_scale;

	// 【双重噪点交叉运动】
	vec2 motion1 = uv + vec2(TIME * ripple_speed * 0.3, TIME * ripple_speed * 0.2);
	vec2 motion2 = uv * 1.2 - vec2(TIME * ripple_speed * 0.25, TIME * ripple_speed * 0.35);

	// 采样两个点的噪点值
	float noise1 = texture(noise_texture, motion1).r;
	float noise2 = texture(noise_texture, motion2).r;

	// 【把“云雾”变成“水网”】
	float wave1 = 1.0 - abs(noise1 - 0.5) * 2.0;
	float wave2 = 1.0 - abs(noise2 - 0.5) * 2.0;

	// 将两路交叉的波纹相乘叠合
	float combined_wave = wave1 * wave2;

	// 使用 power 函数增强对比度
	combined_wave = pow(combined_wave, ripple_sharpness);

	// 【核心修复 2】标准化传入的 Varying 世界法线，并基于世界法线判断是否是“朝上的面”
	vec3 norm = normalize(world_normal);
	
	// 使用世界坐标的 norm.y 进行过滤。
	// 只要世界法线向上（norm.y 接近 1），无论是俯视、仰视还是侧视，top_face 永远等于 1。
	// 这里用 0.7 保证即使表面有微弱弧度（比如球体顶部）也能识别，如果是纯方块顶面，norm.y 会是绝对的 1.0
	float top_face = smoothstep(0.7, 0.95, norm.y); 
	float final_mask = combined_wave * top_face;

	// 颜色混合
	ALBEDO = mix(water_color, ripple_color, final_mask);
	
	// 给水波纹追加微弱的自发光
	EMISSION = ripple_color * final_mask * 0.4;
}