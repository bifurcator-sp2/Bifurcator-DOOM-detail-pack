void SetupMaterial(inout Material material)
{
	const float fTileFactor = 3.0;
	const float fAspectRatio = 0.5;
	const vec2 vTexOffsetScale = vec2(0.5, 0.5);
	const float fTexOffsetHeight = 0.07;
	const float fTexOffsetTimeScale = 0.05;
	const float fSineTimeScale = 2.0; 
	const vec2 vSineOffsetScale = vec2(0.4, 0.4);
	const float fSineWaveSize = 0.08;
	
	vec2 uv = vTexCoord.st;
	vec4 vShadowColor = getTexel(uv);
	vec2 vBaseUvOffset = uv * vTexOffsetScale;
	vBaseUvOffset += timer * fTexOffsetTimeScale;

	vec2 offsetTextureUV = texture(offsetTexture, vBaseUvOffset).rg;
	vec2 offsetTexUvHeight = offsetTextureUV * fTexOffsetHeight;
	vec2 textureBasedOffset = offsetTexUvHeight * 2.0 - 1.0; //
	
	vec2 adjustedUV = uv * fTileFactor;
	adjustedUV.y *= fAspectRatio;
	adjustedUV += textureBasedOffset;

	adjustedUV.x += sin(timer * fSineTimeScale + (adjustedUV.x + adjustedUV.y)) * fSineWaveSize;
	adjustedUV.y += cos(timer * fSineTimeScale + (adjustedUV.x + adjustedUV.y)) * fSineWaveSize;

	float fSineWaveHeight = sin(timer * fSineTimeScale + (adjustedUV.x + adjustedUV.y) * vSineOffsetScale.y);
	float fWaterHeight = (fSineWaveHeight + offsetTextureUV.g) * 0.5;
	
	material.Base = mix(getTexel(adjustedUV), vShadowColor, fWaterHeight * 0.4);
	
	material.Normal = ApplyNormalMap(adjustedUV).xyz;
	material.Specular = texture(speculartexture, adjustedUV).rgb;
	material.Glossiness = uSpecularMaterial.x;
	material.SpecularLevel = uSpecularMaterial.y;
#ifndef NO_LAYERS
	if ((uTextureMode & TEXF_Brightmap) != 0)
		material.Bright = texture(brighttexture, uv.st);
		
	if ((uTextureMode & TEXF_Detailmap) != 0)
	{
		vec4 Detail = texture(detailtexture, uv.st * uDetailParms.xy) * uDetailParms.z;
		material.Base *= Detail;
	}
	
	if ((uTextureMode & TEXF_Glowmap) != 0)
		material.Glow = texture(glowtexture, uv.st);
#endif
}