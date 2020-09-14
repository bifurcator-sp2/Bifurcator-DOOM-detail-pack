/*
Some parts taken from
Procedural Stochastic Textures
by Tiling and Blending
Thomas Deliot and Eric Heitz
*/

vec3 overlay(vec3 c, vec3 b)         
{
    if(c.x < 0.5f && c.y < 0.5f && c.z < 0.5f) return 2.0f * c * b;
    return (1.0f - 2.0f * (1.0f - c) * (1.0f - b));
}

vec2 hash ( vec2 p)
{
	return fract(sin((p) * mat2 (127.1 , 311.7 , 269.5 , 183.3) ) *43758.5453);
}

void TriangleGrid(vec2 uv,
	out float w1, out float w2, out float w3,
	out ivec2 vertex1, out ivec2 vertex2, out ivec2 vertex3)
{
	// Scaling of the input
	uv *= 3.464; // 2 * sqrt(3)

	// Skew input space into simplex triangle grid
	const mat2 gridToSkewedGrid = mat2(1.0, 0.0, -0.57735027, 1.15470054);
	vec2 skewedCoord = gridToSkewedGrid * uv;

	// Compute local triangle vertex IDs and local barycentric coordinates
	ivec2 baseId = ivec2(floor(skewedCoord));
	vec3 temp = vec3(fract(skewedCoord), 0);
	temp.z = 1.0 - temp.x - temp.y;
	if (temp.z > 0.0)
	{
		w1 = temp.z;
		w2 = temp.y;
		w3 = temp.x;
		vertex1 = baseId;
		vertex2 = baseId + ivec2(0, 1);
		vertex3 = baseId + ivec2(1, 0);
	}
	else
	{
		w1 = -temp.z;
		w2 = 1.0 - temp.y;
		w3 = 1.0 - temp.x;
		vertex1 = baseId + ivec2(1, 1);
		vertex2 = baseId + ivec2(1, 0);
		vertex3 = baseId + ivec2(0, 1);
	}
}

vec3 ProceduralNoise(sampler2D texture0, vec2 uv)
{
	// Get triangle info
	float w1, w2, w3;
	ivec2 vertex1, vertex2, vertex3;
	TriangleGrid(uv, w1, w2, w3, vertex1, vertex2, vertex3);
		
	// Assign random offset to each triangle vertex
	vec2 uv1 = uv + hash(vec2(vertex1));
	vec2 uv2 = uv + hash(vec2(vertex2));
	vec2 uv3 = uv + hash(vec2(vertex3));

	// Precompute UV derivatives 
	vec2 duvdx = dFdx(uv);
	vec2 duvdy = dFdy(uv);

	// Fetch Gaussian input
	vec3 G1 = textureGrad(texture0, uv1, duvdx, duvdy).rgb;
	vec3 G2 = textureGrad(texture0, uv2, duvdx, duvdy).rgb;
	vec3 G3 = textureGrad(texture0, uv3, duvdx, duvdy).rgb;

	// Variance-preserving blending
	vec3 G = w1*G1 + w2*G2 + w3*G3;
	G -= vec3(0.5);
	G *= inversesqrt(w1*w1 + w2*w2 + w3*w3);
	G += vec3(0.5);
    
	return G;
}


vec4 ApplyOverlayToColor(vec2 texcoord, vec2 txDetail, float blendAmount)
{
    vec4 baseColor = getTexel(texcoord);
    vec3 overlayColor = ProceduralNoise(tex_overlay, txDetail); //
    
    vec3 overlayResult = overlay(baseColor.xyz, overlayColor);
    vec3 base = mix(baseColor.xyz, overlayResult, blendAmount);
    base = clamp(base, 0.0f, 1.0f);
    
    return vec4(base, baseColor.a);
}

vec2 getTexureRatio(sampler2D texture0, sampler2D texture1)
{
    vec2 result = vec2(textureSize(texture0, 0)) / vec2(textureSize(texture1, 0));
    return result;
}

// linstep:  
//  
// Returns a linear interpolation between 0 and 1 if t is in the range [min, max]   
// if "v" is <= min, the output is 0  
// if "v" i >= max, the output is 1  

float linstep( float min, float max, float v )  
{  
return clamp( (v - min) / (max - min), 0.0f, 1.0f );  
}

Material ProcessMaterial()
{
    vec2 texCoord = vTexCoord.st;
    
    float blendAmount = 1.25f; // more value less distance
    vec2 tiling = vec2(2.0f, 2.0f);
        
    vec2 textureRatio = getTexureRatio(tex, tex_overlay);
    vec2 tiledDetailTx = textureRatio * texCoord * tiling;
    float pixelDepth = pixelpos.w;
    vec4 baseColor = ApplyOverlayToColor(texCoord, tiledDetailTx, linstep(256.0f, 0.0f,pixelDepth) );
	Material material;  
	material.Base = baseColor;

#if defined(BRIGHTMAP)
	material.Bright = texture(brighttexture, texCoord);
#endif
	return material;    
}