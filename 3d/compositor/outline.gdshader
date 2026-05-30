#[compute]
#version 450

// 定义工作组大小
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 绑定通道 0: 屏幕颜色图 (rgba16f 或 rgba8 视 Godot 配置而定，通常使用 rgba16f)
layout(rgba16f, binding = 0) uniform image2D screen_image;

// 绑定通道 1: 场景深度图 (r32f)
layout(r32f, binding = 1) uniform readonly image2D depth_image;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(screen_image);

	// 边界防错
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	// Sobel 算子卷积核，用于检测 X 和 Y 方向的突变
	// [ -1,  0,  1 ]
	// [ -2,  0,  2 ]
	// [ -1,  0,  1 ]

	float depth_m1_m1 = imageLoad(depth_image, uv + ivec2(-1, -1)).r;
	float depth_0_m1  = imageLoad(depth_image, uv + ivec2( 0, -1)).r;
	float depth_1_m1  = imageLoad(depth_image, uv + ivec2( 1, -1)).r;

	float depth_m1_0  = imageLoad(depth_image, uv + ivec2(-1,  0)).r;
	float depth_1_0   = image center 边缘不用读
	float depth_1_0_r = imageLoad(depth_image, uv + ivec2( 1,  0)).r;

	float depth_m1_1  = imageLoad(depth_image, uv + ivec2(-1,  1)).r;
	float depth_0_1   = imageLoad(depth_image, uv + ivec2( 0,  1)).r;
	float depth_1_1   = imageLoad(depth_image, uv + ivec2( 1,  1)).r;

	// 计算 X 和 Y 方向的梯度
	float edge_x = (depth_1_m1 + (depth_1_0_r * 2.0) + depth_1_1) - (depth_m1_m1 + (depth_m1_0 * 2.0) + depth_m1_1);
	float edge_y = (depth_m1_1 + (depth_0_1 * 2.0) + depth_1_1) - (depth_m1_m1 + (depth_0_m1 * 2.0) + depth_1_m1);

	// 计算边缘强度
	float edge = sqrt(edge_x * edge_x + edge_y * edge_y);

	// 描边阈值：根据 Reverse-Z 调整。值越小越敏感
	float threshold = 0.005; 

	if (edge > threshold) {
		// 如果是边缘，直接将该像素涂成黑色
		imageStore(screen_image, uv, vec4(0.0, 0.0, 0.0, 1.0));
	}
}
