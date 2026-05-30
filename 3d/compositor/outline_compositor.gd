@tool
extends CompositorEffect
class_name RedScreenEffect

const RED_SHADER = """#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(push_constant, std430) uniform Params {
    vec2 raster_size;
    vec2 reserved;
} params;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(params.raster_size);
    
    if (uv.x >= size.x || uv.y >= size.y) {
        return;
    }
    
    // 直接把屏幕变成红色
    vec4 red_color = vec4(uv.x, uv.y, 0.0, 1.0);
    imageStore(color_image, uv, red_color);
}"""

var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID

func _init():
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

func _compile_shader() -> bool:
	if not rd:
		return false
	
	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = RED_SHADER
	
	var shader_spirv := rd.shader_compile_spirv_from_source(shader_source)
	
	if shader_spirv.compile_error_compute != "":
		push_error("Shader compile error: ", shader_spirv.compile_error_compute)
		return false
	
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if not shader_rid.is_valid():
		push_error("Failed to create shader")
		return false
	
	pipeline_rid = rd.compute_pipeline_create(shader_rid)
	if not pipeline_rid.is_valid():
		push_error("Failed to create pipeline")
		return false
	
	return true

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData):
	if not rd or p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	
	if not shader_rid.is_valid():
		if not _compile_shader():
			return
	
	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if not render_scene_buffers:
		return
	
	var size = render_scene_buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	
	var view_count = render_scene_buffers.get_view_count()
	
	for view in range(view_count):
		var color_image = render_scene_buffers.get_color_layer(view)
		
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(color_image)
		
		var uniform_set = UniformSetCacheRD.get_cache(shader_rid, 0, [uniform])
		
		var push_constant := PackedFloat32Array([float(size.x), float(size.y), 0.0, 0.0])
		
		var x_groups = (size.x - 1) / 8 + 1
		var y_groups = (size.y - 1) / 8 + 1
		
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if rd:
			if shader_rid.is_valid():
				rd.free_rid(shader_rid)
				shader_rid = RID()
				pipeline_rid = RID()
