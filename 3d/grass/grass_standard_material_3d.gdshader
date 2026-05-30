shader_type spatial;

// 1. 【Minecraft 经典草地调色盘】
uniform vec3 top_grass_bright : source_color = vec3(0.44, 0.72, 0.22); // 亮草绿（繁茂平原）
uniform vec3 top_grass_dark   : source_color = vec3(0.31, 0.58, 0.17); // 暗草绿（沼泽/丛林边缘）
uniform vec3 side_dirt_color  : source_color = vec3(0.53, 0.36, 0.24); // 侧面泥土本色

// 2. 【宏观阶梯与形态控制】
uniform float grass_scale = 0.05;       // 宏观草地群系色块大小
uniform float color_layers = 3.0;       // 色彩阶梯分层数
uniform sampler2D noise_large : hint_default_white, repeat_enable, filter_nearest;

// 3. 【侧面草皮下垂齿槽控制】
uniform float side_fringe_scale = 16.0; // 侧面像素格子的密度（对应 16x16 方块）
uniform float side_grass_depth = 0.2;   // 草皮往泥土下垂的深度控制 (0.0 - 1.0)

// 4. 【微观像素颗粒】
uniform float grain_scale = 256.0;      // 表面像素颗粒缩放
uniform float grain_depth = 0.2;        // 像素微弱光影凹凸
uniform float grain_roughness = 0.95;

varying vec3 world_pos;
varying vec3 model_pos; // 新增：传递模型空间坐标

void vertex() {
	// 传递绝对世界坐标，确保多块拼接完美无缝
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	model_pos = VERTEX; // VERTEX 就是模型空间的原始顶点位置
}

// 经典的像素分层随机函数
float pixel_rand(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// 【完美修复版】法线空间转换（解决转镜头变色问题）
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	
	// --- 1. 宏观草地色块计算（用于顶面和侧面草皮） ---
	vec2 large_uv = world_pos.xz * grass_scale;
	float noise_raw = texture(noise_large, large_uv).r;
	float quantized_noise = floor(noise_raw * color_layers) / (color_layers - 1.0);
	// 混合出当前位置的绝对“草皮颜色”
	vec3 current_grass_color = mix(top_grass_dark, top_grass_bright, quantized_noise);
	
	// --- 2. 微观像素噪点光影 ---
	float grain_val = pixel_rand(world_pos.xz * grain_scale);
	vec3 grain_normal = normalize(vec3((grain_val - 0.5) * grain_depth, 1.0, (grain_val - 0.5) * grain_depth));
	
	// --- 3. 顶面与侧面的严格判定 ---
	float top_face_mask = smoothstep(0.5, 0.6, world_normal.y);
	
	if (top_face_mask > 0.5) {
		// 【绝对顶面】：满铺草皮 + 像素光影
		ALBEDO = current_grass_color;
		NORMAL = grain_normal;
		ROUGHNESS = grain_roughness;
		SPECULAR = 0.0;
	} else {
		// 【侧面】：Minecraft 标志性的“泥土+下垂草皮齿”
		
		// 计算像素化的侧面垂直高度 (Y轴)
		float pixel_y = floor(world_pos.y * side_fringe_scale) / side_fringe_scale;
		// 利用侧面水平坐标制造上下交错的草皮“齿槽”
		float side_horizontal = (abs(world_normal.x) > 0.5) ? world_pos.z : world_pos.x;
		float fringe_noise = pixel_rand(vec2(side_horizontal * side_fringe_scale, 0.0));
		
		// 动态确定草皮下垂的截止高度
		float grass_hang_threshold = 1.0 - (side_grass_depth + fringe_noise * 0.25);
		// 关键点：每个方块的相对高度（让草皮只长在方块顶部边缘）
		float local_y_fraction = model_pos.y + 0.5;
		
		if (local_y_fraction > grass_hang_threshold) {
			// 侧面挂下来的草皮齿
			ALBEDO = current_grass_color * 0.85; // 稍稍暗一点点，模拟侧面阴影
		} else {
			// 侧面露出的泥土
			float dirt_grain = pixel_rand(model_pos.xy * grain_scale);
			ALBEDO = side_dirt_color * mix(0.9, 1.1, dirt_grain);
		}
		
		ROUGHNESS = 0.9;
		SPECULAR = 0.0;
	}
}