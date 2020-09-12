mat3 GetTBN()
{
    vec3 n = normalize(vWorldNormal.xyz);
    vec3 p = pixelpos.xyz;
    vec2 uv = vTexCoord.st;

    // get edge vectors of the pixel triangle
    vec3 dp1 = dFdx(p);
    vec3 dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = dFdy(uv);

    // solve the linear system
    vec3 dp2perp = cross(n, dp2); // cross(dp2, n);
    vec3 dp1perp = cross(dp1, n); // cross(n, dp1);
    vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;

    // construct a scale-invariant frame
    float invmax = inversesqrt(max(dot(t,t), dot(b,b)));
    return mat3(t * invmax, b * invmax, n);
}

vec2 matcap(vec3 eye, vec3 normal, float border) {
  vec3 r = reflect(eye, normal);
  float rz = r.z + 1.0f;
  float m = 2.8284271247461903f * 
  pow(
    (r.x * r.x) +
    (r.y * r.y) +
    (rz  * rz), 0.5f
  );
  vec2 result = r.xy / m;
  return result * border + 0.5f;
}

vec2 rotateUV(vec2 uv, vec2 pivot, float angle)
{
    float rad = radians(angle);
    mat2 rotation_matrix=mat2
    (
        vec2(sin(rad),-cos(rad)),
        vec2(cos(rad), sin(rad))
    );
    
    uv -= pivot;
    uv= uv*rotation_matrix;
    uv += pivot;
    return uv; 
}


#if defined(NORMALMAP)
mat3 cotangentFrame(vec3 n, vec3 p, vec2 uv)
{
	// get edge vectors of the pixel triangle
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);

	// solve the linear system
	vec3 dp2perp = cross(n, dp2); // cross(dp2, n);
	vec3 dp1perp = cross(dp1, n); // cross(n, dp1);
	vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
	vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;

	// construct a scale-invariant frame
	float invmax = inversesqrt(max(dot(t,t), dot(b,b)));
	return mat3(t * invmax, b * invmax, n);
}

vec3 blend_rnm(vec3 n1, vec3 n2)
{
    vec3 t = n1*vec3( 2.0f,  2.0f, 2.0f) + vec3(-1.0f, -1.0f,  0.0f);
    vec3 u = n2*vec3(-2.0f, -2.0f, 2.0f) + vec3( 1.0f,  1.0f, -1.0f);
    vec3 r = t*dot(t, u) - u*t.z;
    return r;
}

vec3 ApplyNormalMapWithRNM(vec2 texcoord, vec2 txDetail)
{
	vec3 interpolatedNormal = normalize(vWorldNormal.xyz);

    vec3 normalColor = texture(normaltexture, texcoord).xyz;
    vec3 detailColor = texture(normaltexture, txDetail).xyz;

	vec3 map = blend_rnm(normalColor, detailColor);
	map = map * 255.0f/127.0f - 128.0f/127.0f; // Math so "odd" because 0.5 cannot be precisely described in an unsigned format

	map.y = -map.y;

	mat3 tbn = cotangentFrame(interpolatedNormal, pixelpos.xyz, vTexCoord.st);
	vec3 bumpedNormal = normalize(tbn * map);
	return bumpedNormal;
}
#endif

void SetupMaterial(inout Material material)
{
    vec2 uvScrollingSpeed = vec2(0.05f, 0.0f);
    vec2 uvRotatedScrollingSpeed = vec2(0.1f, 0.0f);
    
	vec3 fresnelColor = vec3(0.04f, 0.04f, 0.04f);
    float fresnelExponent = 5.0f;   
    
    float normalPowerMult = 0.05f;
    float borderExponent = 0.00f;
    
    mat3 tbn = GetTBN();
    mat3 invTBN = transpose(tbn);
    vec2 texCoord = vTexCoord.st;

    vec3 EyeDir = invTBN * (uCameraPos.xyz - pixelpos.xyz);
    vec3 eyeDirNormalized = normalize(uCameraPos.xyz - pixelpos.xyz);
    
    vec3 worldNormal = normalize(vWorldNormal.xyz);

    //inv fresnel
    float NdotE = max(dot(worldNormal, eyeDirNormalized), 0.0f);
    
    float border = NdotE;
    border = clamp(border, 0.0f, 1.0f);
    border = pow(border, borderExponent);
        
    vec2 matCapTexCoord = matcap(EyeDir, worldNormal, border);
    
    vec2 UVRotated = rotateUV(texCoord, vec2(0.5f), 45.0f);
    UVRotated += timer * uvRotatedScrollingSpeed;
    vec2 normalTexcoords = texCoord + timer * uvScrollingSpeed;    
    
#if defined(NORMALMAP)
    vec3 normal = ApplyNormalMapWithRNM(normalTexcoords, UVRotated);
    vec3 matCapColor = texture(matCapTex, matCapTexCoord + (normal.xy * normalPowerMult)).xyz;
#else
    vec3 normal = ApplyNormalMap(texCoord);
    vec3 matCapColor = texture(matCapTex, matCapTexCoord).xyz;
#endif    
    
    matCapColor *= texture(matCapMaskTex, texCoord).xyz;
  
  
    float fresnel = NdotE;
    
    float AirIOR = 1.0;
    float WaterIOR = 1.33;
    float R_0 = (AirIOR - WaterIOR) / (AirIOR + WaterIOR);
    R_0 *= R_0;    
    
    vec3 fresnelFinalColor = fresnelColor * (R_0 + (1.0f - R_0) * pow(1.0f - fresnel, fresnelExponent));
  
  
    vec4 ambient = getTexel(texCoord); //vec4(0.03f, 0.03f, 0.03f, 1.0f) * 
    vec3 color = ambient.xyz + fresnelFinalColor + matCapColor;
    color = clamp(color, 0.0f, 1.0f);
   
	material.Base = vec4(color, ambient.a);
    
    //normal = clamp(normal, 0.0f, 1.0f);
	material.Normal = normal;

#if defined(SPECULAR)
	material.Specular = texture(speculartexture, texCoord).rgb;
#endif
	material.Glossiness = uSpecularMaterial.x;
	material.SpecularLevel = uSpecularMaterial.y;

#ifndef NO_LAYERS
	if ((uTextureMode & TEXF_Brightmap) != 0)
		material.Bright = texture(brighttexture, texCoord);
		
	if ((uTextureMode & TEXF_Detailmap) != 0)
	{
		vec4 Detail = texture(detailtexture, texCoord.st * uDetailParms.xy) * uDetailParms.z;
		material.Base *= Detail;
	}
	
	if ((uTextureMode & TEXF_Glowmap) != 0)
		material.Glow = texture(glowtexture, texCoord.st);
#endif  
}