// Toony Colors Pro 2 - Hybrid Shader 3 (Built-in RP)
// Shared forward lighting code for the ForwardBase and ForwardAdd passes.
// Define TCP2_FORWARD_ADD before including this file to compile the additive variant.
//
// All optional features are driven by uniform float toggles (branching), NOT by
// shader keywords, so this shader produces only the handful of built-in lighting
// variants instead of thousands — which is what previously caused the shader
// compiler to time out at the preprocess stage.

#ifndef TCP2_HYBRID_SHADER3_INCLUDED
#define TCP2_HYBRID_SHADER3_INCLUDED

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

#ifndef UNITY_SPECCUBE_LOD_STEPS
	#define UNITY_SPECCUBE_LOD_STEPS 6
#endif

//================================================================
// UNIFORMS

sampler2D _BaseMap;     float4 _BaseMap_ST;
fixed4 _BaseColor;
fixed4 _HColor;
fixed4 _SColor;
half _Cutoff;
float _UseAlphaTest;

float _ShadowColorLightAtten;
float _UseShadowTexture;
sampler2D _ShadowBaseMap;

float _RampType;        // 0=Default 1=Crisp 2=Bands 3=BandsCrisp 4=Texture
sampler2D _Ramp;
half _RampScale, _RampOffset, _RampThreshold, _RampSmoothing, _RampBands, _RampBandsSmoothing;

float _UseNormalMap;
sampler2D _BumpMap;     half _BumpScale;

float _UseSpecular;
float _SpecularType;    // 0=GGX 1=Stylized 2=Crisp
fixed4 _SpecularColor;
half _SpecularToonSize, _SpecularToonSmoothness, _SpecularRoughness;
float _SpecularMapType; // 0=Disabled 1=AlbedoAlpha 2=R 3=G 4=B 5=A
sampler2D _SpecGlossMap;

float _UseEmission;
sampler2D _EmissionMap; fixed4 _EmissionColor;
float _EmissionChannel; // 0=NoTexture 1=RGB 2=R 3=G 4=B 5=A

float _UseRim;
fixed4 _RimColor;       half _RimMin, _RimMax;
float _UseRimLightMask;

float _UseMatCap;
sampler2D _MatCapTex;   fixed4 _MatCapColor;
float _MatCapType;      // 0=Additive 1=Replace
float _UseMatCapMask;
sampler2D _MatCapMask;
float _MatCapMaskChannel; // 0=R 1=G 2=B 3=A

float _UseOcclusion;
sampler2D _OcclusionMap; half _OcclusionStrength;
float _OcclusionChannel;  // 0=AlbedoAlpha 1=R 2=G 3=B 4=A

half _IndirectIntensity;
float _SingleIndirectColor;

float _UseReflections;
fixed4 _ReflectionColor;
half _ReflectionSmoothness;
float _ReflectionMapType;  // 0=Disabled 1=AlbedoAlpha 2=R 3=G 4=B 5=A
sampler2D _ReflectionTex;
float _UseFresnelReflections;
half _FresnelMin, _FresnelMax;

//================================================================
// HELPERS

// Picks one channel from a packed texture. ch: 0=R 1=G 2=B 3=A.
inline half ChannelRGBA(half4 t, float ch)
{
	if (ch < 0.5) return t.r;
	if (ch < 1.5) return t.g;
	if (ch < 2.5) return t.b;
	return t.a;
}

// Safe normalize (from UnityStandardBRDF) — used for the specular half vector, same as SG2.
inline half3 SafeNormalize(half3 v)
{
	return v * rsqrt(max(0.001, dot(v, v)));
}

// Maps NdotL through the selected ramp style (branch on _RampType).
inline fixed3 ComputeRamp(half ndl)
{
	if (_RampType >= 3.5)        // Texture
	{
		half uv = saturate(ndl * _RampScale + _RampOffset);
		return tex2D(_Ramp, uv.xx).rgb;
	}
	else if (_RampType >= 1.5)   // Bands (2) or Bands Crisp (3)
	{
		half bands = max(1, _RampBands);
		half scaled = ndl * bands;
		half stepped = floor(scaled);
		half fracPart = scaled - stepped;
		half halfW = (_RampType >= 2.5) ? 1e-4 : (_RampBandsSmoothing * 0.5 + 1e-4);
		half band = stepped + smoothstep(0.5 - halfW, 0.5 + halfW, fracPart);
		return saturate(band / bands).xxx;
	}
	else if (_RampType >= 0.5)   // Crisp
	{
		return smoothstep(_RampThreshold - 0.001, _RampThreshold + 0.001, ndl).xxx;
	}
	// Default (smooth)
	return smoothstep(_RampThreshold - _RampSmoothing * 0.5, _RampThreshold + _RampSmoothing * 0.5, ndl).xxx;
}

//================================================================
// VERTEX / FRAGMENT

struct appdata
{
	float4 vertex  : POSITION;
	float3 normal  : NORMAL;
	float4 tangent : TANGENT;
	float2 uv      : TEXCOORD0;
	float2 uv1     : TEXCOORD1;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	float4 pos          : SV_POSITION;
	float2 uv           : TEXCOORD0;
	float3 worldPos     : TEXCOORD1;
	float3 worldNormal  : TEXCOORD2;
	float4 worldTangent : TEXCOORD3;   // xyz = tangent, w = sign
	UNITY_LIGHTING_COORDS(4, 5)         // light cookie coord + shadow coord
#ifdef LIGHTMAP_ON
	float2 lmuv         : TEXCOORD6;
#endif
	UNITY_FOG_COORDS(7)
	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

v2f vert(appdata v)
{
	v2f o;
	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_INITIALIZE_OUTPUT(v2f, o);
	UNITY_TRANSFER_INSTANCE_ID(v, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
	o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
	o.worldNormal = UnityObjectToWorldNormal(v.normal);
	float3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
	o.worldTangent = float4(wTangent, v.tangent.w * unity_WorldTransformParams.w);

#ifdef LIGHTMAP_ON
	o.lmuv = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
#endif

	UNITY_TRANSFER_LIGHTING(o, v.uv1);
	UNITY_TRANSFER_FOG(o, o.pos);
	return o;
}

fixed4 frag(v2f i) : SV_Target
{
	UNITY_SETUP_INSTANCE_ID(i);
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

	// ---- Albedo / alpha ----
	fixed4 baseTex = tex2D(_BaseMap, i.uv) * _BaseColor;
	if (_UseAlphaTest > 0.5)
		clip(baseTex.a - _Cutoff);

	fixed3 albedo = baseTex.rgb;
	fixed3 shadowAlbedo = albedo;
	if (_UseShadowTexture > 0.5)
		shadowAlbedo = tex2D(_ShadowBaseMap, i.uv).rgb * _BaseColor.rgb;

	// ---- Normal (with optional normal map) ----
	float3 worldN = normalize(i.worldNormal);
	if (_UseNormalMap > 0.5)
	{
		fixed3 nTS = UnpackScaleNormal(tex2D(_BumpMap, i.uv), _BumpScale);
		float3 wt = normalize(i.worldTangent.xyz);
		float3 wb = cross(worldN, wt) * i.worldTangent.w;
		worldN = normalize(wt * nTS.x + wb * nTS.y + worldN * nTS.z);
	}

	float3 worldV = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

	// ---- Occlusion (channel-selectable) ----
	if (_UseOcclusion > 0.5)
	{
		half occRaw;
		if (_OcclusionChannel < 0.5) occRaw = baseTex.a;                                  // Albedo Alpha
		else                         occRaw = ChannelRGBA(tex2D(_OcclusionMap, i.uv), _OcclusionChannel - 1);
		half occ = lerp(1.0, occRaw, _OcclusionStrength);
		albedo *= occ;
		shadowAlbedo *= occ;
	}

	// ---- Direct light (current pass light) ----
	UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
	// Safe-normalize: avoids NaN when there is no active light (zero light vector).
	float3 lightDir = UnityWorldSpaceLightDir(i.worldPos);
	lightDir /= max(length(lightDir), 1e-4);
	half3 lightColor = _LightColor0.rgb;

	half ndl = max(0, dot(worldN, lightDir));
	fixed3 ramp = ComputeRamp(ndl) * atten;

	// Additive passes must not re-introduce the ambient shadow tint.
	fixed4 shadowColor = _SColor;
#if defined(TCP2_FORWARD_ADD)
	shadowColor = fixed4(0, 0, 0, 1);
#endif
	shadowColor.rgb = lerp(_HColor.rgb, shadowColor.rgb, shadowColor.a);

	fixed3 diffuse = lerp(shadowAlbedo * shadowColor.rgb, albedo * _HColor.rgb, ramp);

	fixed3 col;
	if (_ShadowColorLightAtten > 0.5)
		col = diffuse * lightColor;
	else
		col = diffuse * lerp(fixed3(1, 1, 1), lightColor, ramp);

	// ---- Specular (with channel-selectable specular map) ----
	if (_UseSpecular > 0.5)
	{
		half3 halfDir = SafeNormalize(lightDir + worldV);
		half nh = saturate(dot(worldN, halfDir));
		half spec;
		if (_SpecularType >= 0.5) // Stylized (1) or Crisp (2) — toon specular
		{
			half specSize = 1 - _SpecularToonSize;
			half specSmooth = (_SpecularType >= 1.5) ? 0 : _SpecularToonSmoothness;
			spec = smoothstep(specSize - specSmooth - 1e-4, specSize + specSmooth + 1e-4, nh);
			spec *= ndl * atten;
		}
		else // GGX — identical math to Hybrid Shader 2 (SG2). roughness = _SpecularRoughness^2
		{
			half roughness = _SpecularRoughness * _SpecularRoughness;
			half a2 = roughness * roughness;
			half d  = (nh * a2 - nh) * nh + 1.0;
			// SG2: GGX() returns INV_PI*a2/d^2, then *= UNITY_PI*0.05 → the PI terms cancel.
			spec = (a2 / (d * d + 1e-7)) * 0.05;
		#ifdef UNITY_COLORSPACE_GAMMA
			spec = sqrt(max(1e-4, spec));
			half surfaceReduction = 1.0 - 0.28 * roughness * _SpecularRoughness;
		#else
			half surfaceReduction = 1.0 / (roughness * roughness + 1.0);
		#endif
			spec = max(0, spec * ndl) * surfaceReduction * atten;
		}

		// Specular intensity mask from a packed texture (or albedo alpha).
		if (_SpecularMapType > 0.5)
		{
			half sm;
			if (_SpecularMapType < 1.5) sm = baseTex.a;                                   // Albedo Alpha
			else                        sm = ChannelRGBA(tex2D(_SpecGlossMap, i.uv), _SpecularMapType - 2);
			spec *= sm;
		}

		col += lightColor * _SpecularColor.rgb * spec;
	}

#if !defined(TCP2_FORWARD_ADD)
	// ---- Indirect diffuse (base pass only): baked lightmap or SH probes/ambient ----
	fixed3 indirect;
	#ifdef LIGHTMAP_ON
		indirect = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lmuv));
	#else
		// Single Indirect Color uses only the SH DC term → flat ambient (toon look).
		if (_SingleIndirectColor > 0.5) indirect = ShadeSH9(float4(0, 0, 0, 1));
		else                            indirect = ShadeSH9(float4(worldN, 1));
	#endif
	col += albedo * indirect * _IndirectIntensity;

	// ---- Environment reflections (base pass only) ----
	if (_UseReflections > 0.5)
	{
		half3 reflDir = reflect(-worldV, worldN);
		half perceptualRoughness = 1.0 - _ReflectionSmoothness;
		half mip = perceptualRoughness * UNITY_SPECCUBE_LOD_STEPS;
		half4 probe = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, mip);
		fixed3 refl = DecodeHDR(probe, unity_SpecCube0_HDR) * _ReflectionColor.rgb;

		if (_ReflectionMapType > 0.5)
		{
			half rm;
			if (_ReflectionMapType < 1.5) rm = baseTex.a;                                 // Albedo Alpha
			else                          rm = ChannelRGBA(tex2D(_ReflectionTex, i.uv), _ReflectionMapType - 2);
			refl *= rm;
		}

		if (_UseFresnelReflections > 0.5)
			refl *= smoothstep(_FresnelMin, _FresnelMax, 1 - saturate(dot(worldV, worldN)));

		col += refl;
	}

	// ---- MatCap (channel-selectable mask; Strength = MatCap Color alpha, TCP2 convention) ----
	if (_UseMatCap > 0.5)
	{
		half3 viewN = mul((float3x3)UNITY_MATRIX_V, worldN);
		half2 mcuv = viewN.xy * 0.5 + 0.5;
		fixed3 mc = tex2D(_MatCapTex, mcuv).rgb * _MatCapColor.rgb;

		half mcAmount = _MatCapColor.a;   // Strength (alpha of MatCap Color)
		if (_UseMatCapMask > 0.5)
			mcAmount *= ChannelRGBA(tex2D(_MatCapMask, i.uv), _MatCapMaskChannel);

		if (_MatCapType > 0.5) col = lerp(col, mc, mcAmount);  // Replace (strength × mask)
		else                   col += mc * mcAmount;           // Additive (strength × mask)
	}

	// ---- Rim (matches Hybrid Shader 2: rimColor.rgb only, no light-color tint, strength = 1) ----
	if (_UseRim > 0.5)
	{
		half rim = smoothstep(_RimMin, _RimMax, 1 - saturate(dot(worldV, worldN)));
		fixed3 rimC = rim * _RimColor.rgb;
		if (_UseRimLightMask > 0.5) col += ndl * atten * rimC;  // light-based mask: dimmed by NdotL & shadow
		else                        col += rimC;                 // constant rim: unaffected by shadow
	}

	// ---- Emission (channel-selectable; mapping matches Hybrid Shader 2: R0 G1 B2 A3 RGB4 NoTex5) ----
	if (_UseEmission > 0.5)
	{
		fixed3 em;
		if (_EmissionChannel > 4.5) em = _EmissionColor.rgb;                              // No Texture (color only)
		else
		{
			half4 et = tex2D(_EmissionMap, i.uv);
			if (_EmissionChannel > 3.5) em = et.rgb * _EmissionColor.rgb;                 // RGB
			else                        em = ChannelRGBA(et, _EmissionChannel) * _EmissionColor.rgb; // R/G/B/A
		}
		col += em;
	}
#else
	// Additive pass: only the light-masked rim accumulates per extra light (matches Hybrid Shader 2).
	if (_UseRim > 0.5 && _UseRimLightMask > 0.5)
	{
		half rim = smoothstep(_RimMin, _RimMax, 1 - saturate(dot(worldV, worldN)));
		col += ndl * atten * (rim * _RimColor.rgb);
	}
#endif

	fixed4 finalCol = fixed4(col, baseTex.a);
#if defined(TCP2_FORWARD_ADD)
	// Additive light must fade to black with fog, not toward the fog color.
	UNITY_APPLY_FOG_COLOR(i.fogCoord, finalCol, fixed4(0, 0, 0, 0));
#else
	UNITY_APPLY_FOG(i.fogCoord, finalCol);
#endif
	return finalCol;
}

#endif // TCP2_HYBRID_SHADER3_INCLUDED
