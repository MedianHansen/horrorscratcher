shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D main_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D main_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D main_orm : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 main_tint = vec3(1.0, 1.0, 1.0);
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

uniform sampler2D mask1 : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint_r1 = vec3(1.0, 1.0, 1.0);
uniform vec3 tint_g1 = vec3(1.0, 1.0, 1.0);
uniform vec3 tint_b1 = vec3(1.0, 1.0, 1.0);
uniform vec3 inten1 = vec3(1.0, 1.0, 1.0);

uniform sampler2D mask2 : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint_r2 = vec3(1.0, 1.0, 1.0);
uniform vec3 tint_g2 = vec3(1.0, 1.0, 1.0);
uniform vec3 tint_b2 = vec3(1.0, 1.0, 1.0);
uniform vec3 inten2 = vec3(1.0, 1.0, 1.0);

uniform sampler2D tm1 : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tmask_r1 = vec3(1.0, 1.0, 1.0);
uniform vec3 tmask_g1 = vec3(1.0, 1.0, 1.0);
uniform vec3 tmask_b1 = vec3(1.0, 1.0, 1.0);
uniform float tintmask_inten1 = 1.0;

uniform sampler2D tm2 : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tmask_r2 = vec3(1.0, 1.0, 1.0);
uniform vec3 tmask_g2 = vec3(1.0, 1.0, 1.0);
uniform vec3 tmask_b2 = vec3(1.0, 1.0, 1.0);
uniform float tintmask_inten2 = 1.0;

uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform float mask_lod : hint_range(0.0, 6.0) = 0.0;

void fragment() {
	vec2 uv = UV;

	vec3 albedo = texture(main_albedo, uv).rgb * main_tint;

	vec3 a = texture(tm1, uv).rgb;
	albedo = mix(albedo, tmask_r1, clamp(a.r * tintmask_inten1, 0.0, 1.0));
	albedo = mix(albedo, tmask_g1, clamp(a.g * tintmask_inten1, 0.0, 1.0));
	albedo = mix(albedo, tmask_b1, clamp(a.b * tintmask_inten1, 0.0, 1.0));

	vec3 c = texture(tm2, uv).rgb;
	albedo = mix(albedo, tmask_r2, clamp(c.r * tintmask_inten2, 0.0, 1.0));
	albedo = mix(albedo, tmask_g2, clamp(c.g * tintmask_inten2, 0.0, 1.0));
	albedo = mix(albedo, tmask_b2, clamp(c.b * tintmask_inten2, 0.0, 1.0));

	vec3 m1 = textureLod(mask1, uv, mask_lod).rgb;
	albedo = mix(albedo, tint_r1, clamp(m1.r * inten1.r, 0.0, 1.0));
	albedo = mix(albedo, tint_g1, clamp(m1.g * inten1.g, 0.0, 1.0));
	albedo = mix(albedo, tint_b1, clamp(m1.b * inten1.b, 0.0, 1.0));

	vec3 m2 = textureLod(mask2, uv, mask_lod).rgb;
	albedo = mix(albedo, tint_r2, clamp(m2.r * inten2.r, 0.0, 1.0));
	albedo = mix(albedo, tint_g2, clamp(m2.g * inten2.g, 0.0, 1.0));
	albedo = mix(albedo, tint_b2, clamp(m2.b * inten2.b, 0.0, 1.0));

	ALBEDO = albedo;

	if (has_normal) {
		vec3 n = texture(main_normal, uv).rgb * 2.0 - 1.0;
		NORMAL_MAP = normalize(vec3(n.xy * normal_strength, n.z));
	}

	if (has_orm) {
		vec3 orm = texture(main_orm, uv).rgb;
		ROUGHNESS = clamp(orm.g, 0.05, 1.0);
		METALLIC = clamp(orm.b, 0.0, 1.0);
	} else {
		ROUGHNESS = 0.8;
		METALLIC = 0.0;
	}
	SPECULAR = specular_amount;
}
