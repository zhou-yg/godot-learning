shader_type spatial;

// 1. 【Minecraft 经典沙漠调色盘】
uniform vec3 base_sand_color : source_color = vec3(0.89, 0.74, 0.47);  // 阳光正照的亮沙色
uniform vec3 mid_sand_color  : source_color = vec3(0.82, 0.65, 0.37);  // 阶梯过渡的中间沙色
uniform vec3 dark_sand_color : source_color = vec3(0.71, 0.53, 0.28);  // 阴影或沙丘底部的深沙色

// 2. 【宏观阶梯控制】
uniform float large_scale = 0.03;      // 沙丘色块的比例大小 (越小色块越大)
uniform float color_layers = 3.0;      // 强制色彩分层的数量 (3代表三档硬色块)
uniform sampler2D noise_large : hint_default_white, repeat_enable, filter_nearest; // 强烈建议把过滤改成 filter_nearest 获得像素感

// 3. 【微观像素颗粒】
uniform float grain_scale = 256.0;     // 模拟 16x16 像素方块网格
uniform float grain_depth = 0.3;       // 像素凹凸的生硬程度
uniform float grain_roughness = 0.95;  // 几乎不反光的粗糙度

varying vec3 world_pos;

void vertex() {
	// 传递世界坐标以确保多块无缝拼接
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// --- 像素化的 Worley 晶体噪点（用于生成硬边方块颗粒） ---
vec2 hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float pixel_worley(vec2 p) {
	// 【Minecraft 核心】：对采样坐标进行取整，强行制造格子感
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float min_dist = 1.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash(ip + g);
			vec2 r = g + o - fp;
			float d = dot(r, r);
			if (d < min_dist) {
				min_dist = d;
			}
		}
	}
	// 同样阶梯化返回值
	return floor(sqrt(min_dist) * 4.0) / 4.0;
}
// --------------------------------------------------

void fragment() {
	// 完美修复：基于世界坐标法线，转镜头绝不穿帮
	// 正确写法：先让 mat4 乘以 vec4，然后再切片取出其中的 .xyz
vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	
	// 判断是否为朝上的绝对顶面
	float top_face_mask = smoothstep(0.5, 0.6, world_normal.y);
	
	if (top_face_mask < 0.5) {
		// --- 侧面逻辑：直接渲染干净的深色方块面 ---
		ALBEDO = dark_sand_color;
		ROUGHNESS = 0.9;
		SPECULAR = 0.0;
	} else {
		// --- 顶面逻辑：Minecraft 阶梯色彩排布 ---
		
		// 1. 获取世界坐标下的基础噪点值
		vec2 large_uv = world_pos.xz * large_scale;
		float noise_raw = texture(noise_large, large_uv).r;
		
		// 2. 【核心改动】：通过 floor 强行将渐变噪点切削成“一阶一阶”的硬边色块
		float quantized_noise = floor(noise_raw * color_layers) / (color_layers - 1.0);
		
		// 3. 三档颜色硬核混合
		vec3 surf_color;
		if (quantized_noise < 0.34) {
			surf_color = dark_sand_color;  // 低洼暗色
		} else if (quantized_noise < 0.67) {
			surf_color = mid_sand_color;   // 阶梯过渡色
		} else {
			surf_color = base_sand_color;  // 高地亮沙色
		}
		
		// 4. 应用像素化的颗粒法线
		vec2 grain_uv = world_pos.xz * grain_scale;
		float grain_val = pixel_worley(grain_uv);
		
		// 制造微小的硬边结构光影
		vec3 grain_normal = normalize(vec3(
			(grain_val - 0.5) * grain_depth,
			1.0,
			(grain_val - 0.5) * grain_depth
		));
		
		// 最终通道输出
		NORMAL = grain_normal;
		ALBEDO = surf_color;
		SPECULAR = 0.0; // MC的沙子绝不反光
		ROUGHNESS = grain_roughness;
	}
}