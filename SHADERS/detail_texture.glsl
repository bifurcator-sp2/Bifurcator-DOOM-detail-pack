vec3 overlay(vec3 c, vec3 b)         
{
    if(c.x < 0.5f && c.y < 0.5f && c.z < 0.5f) return 2.0f * c * b;
    return (1.0f - 2.0f * (1.0f - c) * (1.0f - b));
}

vec4 ApplyOverlayToColor(vec2 texcoord, vec2 txDetail, float blendAmount)
{
    vec4 baseColor = getTexel(texcoord);
    vec4 overlayColor = texture(tex_overlay, txDetail);
    
    vec3 overlayResult = overlay(baseColor.xyz, overlayColor.xyz);
    vec3 base = mix(baseColor.xyz, overlayResult, blendAmount);
    base = clamp(base, 0.0f, 1.0f);
    
    return vec4(base, baseColor.a);
}

vec2 getTexureRatio(sampler2D texture0, sampler2D texture1)
{
    vec2 result = vec2(textureSize(texture0, 0)) / vec2(textureSize(texture1, 0));
    return result;
} 

Material ProcessMaterial()
{
    vec2 texCoord = vTexCoord.st;
    
    float blendAmount = 1.25f; // more value less distance
    vec2 tiling = vec2(8.0f, 8.0f);

    vec3 worldNormal = normalize(vWorldNormal.xyz);
    vec3 viewDir = normalize(uCameraPos.xyz - pixelpos.xyz);

    float fresnel = max(dot(worldNormal, viewDir), 0.0f);
    fresnel = clamp(fresnel, 0.0f, 1.0f);
    fresnel = pow(fresnel, blendAmount);
        
    vec2 textureRatio = getTexureRatio(tex, tex_overlay);
    vec2 tiledDetailTx = textureRatio * texCoord * tiling;
    vec4 baseColor = ApplyOverlayToColor(texCoord, tiledDetailTx, fresnel);
	Material material;  
	material.Base = baseColor;

#if defined(BRIGHTMAP)
	material.Bright = texture(brighttexture, texCoord);
#endif
	return material;    
}