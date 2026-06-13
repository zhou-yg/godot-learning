@tool
class_name PixelateCompositorEffect
extends CompositorEffect

# 定义一个 Shader 变量，用于存储并运行像素化代码
var shader: RID
var pipeline: RID

func _init() -> void:
	# 设置合成器效果的触发时机：在非透明物体和天空渲染完之后
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
	_init_shader()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			RenderingServer.free_rid(shader)

# 初始化底层 GPU 渲染计算着色器 (RD Shader)
# 初始化底层 GPU 渲染计算着色器 (RD Shader)
func _init_shader() -> void:
	var rd := RenderingServer.get_rendering_device()
	if not rd: return
	
	# 🔴 修正：删除了顶部的 #[compute] 标签，直接从 #version 450 开始
	var shader_source := """#version 450

	layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

	layout(rgba16f, binding = 0) uniform image2D screen_image;

	layout(push_constant) uniform Params {
		int pixel_size;
	} params;

	void main() {
		ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
		ivec2 size = imageSize(screen_image);
		if (uv.x >= size.x || uv.y >= size.y) return;

		// 核心逻辑：按 pixel_size 进行网格化采样
		ivec2 pixelated_uv = (uv / params.pixel_size) * params.pixel_size;
		vec4 color = imageLoad(screen_image, pixelated_uv);

		imageStore(screen_image, uv, color);
	}
	"""
	
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.set_stage_source(RenderingDevice.SHADER_STAGE_COMPUTE, shader_source)
	
	var spirv := rd.shader_compile_spirv_from_source(src)
	
	# 检查编译错误
	if spirv.compile_error_compute != "":
		push_error("Compositor Shader 编译失败: " + spirv.compile_error_compute)
		return
		
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
# 每帧执行的渲染逻辑
func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_OPAQUE: return
	
	var rd := RenderingServer.get_rendering_device()
	var scene_buffers := p_render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not scene_buffers: return
	
	# 获取当前视口（Viewport）的大小和颜色缓冲区
	var size := scene_buffers.get_internal_size()
	var texture := scene_buffers.get_color_layer(0)
	
	# 创建 Uniform 集供 GPU 读取
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture)
	
	var uniform_set := rd.uniform_set_create([uniform], shader, 0)
	
	# 像素大小：4 代表将画面缩放 4 倍颗粒感（你可以根据需要修改这里）
	var pixel_size: int = 10
# 🔴 修正：Vulkan 内存对齐要求 push_constant 至少为 16 字节 (4个 int)
	# 即使我们只用第一个参数 pixel_size，后面三个也要填 0 补齐空间
	var push_constant := PackedInt32Array([pixel_size, 0, 0, 0])
	
	# 启动计算管线
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	# 🔴 修正：大小传 push_constant.size() * 4，即 4 * 4 = 16 字节
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)

	# 线程组分发
	var x_groups = ceil(float(size.x) / 8.0)
	var y_groups = ceil(float(size.y) / 8.0)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
