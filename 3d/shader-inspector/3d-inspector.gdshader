shader_type spatial;
render_mode cull_disabled; // 修复错误：移除了非法的 render_priority 关键字，保留关闭背面剔除

// --- 材质面板 Debug 模式控制开关 ---
uniform int debug_mode : hint_range(0, 10, 1) = 0;
/* 模式对照表：
 0 : 正常显示（默认白色）
 1 : 原始 UV 检查 (X->红, Y->绿)
 2 : UV2 检查 (主要用于烘焙光照或 Blender 第二套 UV)
 3 : 模型局部坐标 (VERTEX - Local Space)
 4 : 世界坐标位置 (World Space VERTEX)
 5 : 视图/相机空间法线 (View Space NORMAL - 随相机转动改变)
 6 : 世界坐标空间法线 (World Space NORMAL - 固定朝向)
 7 : 视线方向 (VIEW 向量)
 8 : 屏幕深度可视化 (DEPTH - 离镜头近黑远白)
 9 : UV 切片测试 (测试 UV.x >= 0.5 边界)
*/

// --- 附加辅助参数 ---
uniform float position_scale : hint_range(0.1, 10.0) = 1.0; // 用于缩放顶点坐标的检查周期
uniform float depth_range : hint_range(1.0, 100.0) = 10.0;  // 深度检查的最大可视距离

// --- 内部数据传输桥梁 ---
varying vec3 v_world_vertex;
varying vec3 v_world_normal;
varying vec3 v_local_vertex;

void vertex() {
    // 1. 缓存模型局部坐标
    v_local_vertex = VERTEX;
    
    // 2. 将顶点坐标转换到世界空间
    v_world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // 3. 将法线转换到世界空间 (防止受到相机绝对方向的干扰)
    v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // 预设默认输出颜色
    vec3 debug_color = vec3(1.0); 

    // --- 根据面板选择的开关，切入对应的内置变量可视化分支 ---
    if (debug_mode == 0) {
        // [0] 正常模式：不处理，纯白物体
        debug_color = vec3(1.0, 1.0, 1.0);
    }
    else if (debug_mode == 1) {
        // [1] 内置 UV 检查 
        debug_color = vec3(UV.x, UV.y, 0.0);
    }
    else if (debug_mode == 2) {
        // [2] 内置 UV2 检查
        debug_color = vec3(UV2.x, UV2.y, 0.0);
    }
    else if (debug_mode == 3) {
        // [3] 模型空间顶点位置 (Local VERTEX)
        debug_color = fract(v_local_vertex * position_scale);
    }
    else if (debug_mode == 4) {
        // [4] 世界空间顶点位置 (World VERTEX)
        debug_color = vec3(fract(v_world_vertex.x * position_scale), fract(v_world_vertex.z * position_scale), 0.0);
    }
    else if (debug_mode == 5) {
        // [5] 视图空间法线 (View Space NORMAL)
        debug_color = NORMAL * 0.5 + 0.5;
    }
    else if (debug_mode == 6) {
        // [6] 世界空间法线 (World Space NORMAL)
        debug_color = v_world_normal * 0.5 + 0.5;
    }
    else if (debug_mode == 7) {
        // [7] 视线方向向量 (VIEW 向量)
        debug_color = VIEW * 0.5 + 0.5;
    }
    else if (debug_mode == 8) {
        // [8] 像素级屏幕深度 (DEPTH 检查)
        float depth_eye = FRAGCOORD.z; 
        debug_color = vec3(depth_eye / depth_range);
    }
    else if (debug_mode == 9) {
        // [9] 阈值切片测试 (验证区间与边界)
        //float slice = step(0.5, UV.x);
        //debug_color = vec3(slice);
		float looped_uv_x = fract(UV.x); // 强制让 [1.2 -> 0.2], [-0.3 -> 0.7]
    	float slice = step(0.5, looped_uv_x);
    	debug_color = vec3(slice);

    } else if (debug_mode == 10) {
        // [9] 阈值切片测试 (验证区间与边界)
        //float slice = step(0.5, UV.y);
        //debug_color = vec3(slice);
		float looped_uv_x = fract(UV.y); // 强制让 [1.2 -> 0.2], [-0.3 -> 0.7]
    	float slice = step(0.5, looped_uv_x);
    	debug_color = vec3(slice);
    }

    // 将 Debug 处理完的颜色最终塞给输出
    ALBEDO = debug_color;
}