// Toony Colors Pro 2 - Hybrid Shader 3
// Built-in Render Pipeline version — hand-written vertex/fragment (NOT a surface shader).
//
// Why vertex/fragment: the previous surface-shader version exposed every feature as a
// shader keyword (~7,680 combinations), which made Unity's shader compiler time out at
// the "Preprocess" stage (600s) and pile up multi-GB compiler processes. Here every
// optional feature is a uniform-float branch, so the only variants are the necessary
// built-in lighting/shadow/fog ones. Forward lighting lives in TCP2_HybridShader3.cginc
// and is shared by the ForwardBase and ForwardAdd passes.
//
// Features: toon ramp (smooth / crisp / bands / bands-crisp / ramp texture), highlight &
// shadow colors, shadow albedo texture, normal mapping, toon specular (GGX / stylized /
// crisp) with channel-selectable specular map, emission (channel-selectable), rim lighting,
// matcap (additive / replace) with channel-selectable mask, occlusion (channel-selectable),
// indirect intensity / single indirect color, environment reflections (+ fresnel), alpha
// clipping, advanced inverted-hull outline (textured / pixel-size / normals source /
// lighting), plus correct shadows (cast & receive), baked lightmaps/probes and fog.

Shader "Toony Colors Pro 2/Hybrid Shader 3"
{
	Properties
	{
		[Enum(Front, 2, Back, 1, Both, 0)] _Cull ("Render Face", Float) = 2
		[Enum(Off, 0, On, 1)] _ZWrite ("Depth Write", Float) = 1
		[ToggleUI] _UseAlphaTest ("Alpha Clipping", Float) = 0
		_Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5

		// Base
		_BaseColor ("Color", Color) = (1,1,1,1)
		_BaseMap ("Albedo (RGB) Mask (A)", 2D) = "white" {}
		_HColor ("Highlight Color", Color) = (1,1,1,1)
		_SColor ("Shadow Color", Color) = (0.2,0.2,0.2,1)
		[ToggleUI] _ShadowColorLightAtten ("Main Light affects Shadow Color", Float) = 1
		[ToggleUI] _UseShadowTexture ("Enable Shadow Albedo Texture", Float) = 0
		[NoScaleOffset] _ShadowBaseMap ("Shadow Albedo", 2D) = "gray" {}

		// Ramp Shading
		[Enum(Default,0,Crisp,1,Bands,2,Bands Crisp,3,Texture,4)] _RampType ("Ramp Type", Float) = 0
		[NoScaleOffset] _Ramp ("Ramp Texture (RGB)", 2D) = "gray" {}
		_RampScale ("Ramp Scale", Float) = 1
		_RampOffset ("Ramp Offset", Float) = 0
		[PowerSlider(0.415)] _RampThreshold ("Threshold", Range(0.01, 1)) = 0.75
		_RampSmoothing ("Smoothing", Range(0, 1)) = 0.1
		[IntRange] _RampBands ("Bands Count", Range(1, 20)) = 4
		_RampBandsSmoothing ("Bands Smoothing", Range(0, 1)) = 0.1

		// Normal Mapping
		[ToggleUI] _UseNormalMap ("Normal Mapping", Float) = 0
		_BumpMap ("Normal Map", 2D) = "bump" {}
		_BumpScale ("Scale", Range(-1, 1)) = 1

		// Specular
		[ToggleUI] _UseSpecular ("Specular", Float) = 0
		[Enum(GGX,0,Stylized,1,Crisp,2)] _SpecularType ("Type", Float) = 0
		[HDR] _SpecularColor ("Specular Color", Color) = (0.75,0.75,0.75,1)
		[PowerSlider(5.0)] _SpecularToonSize ("Size", Range(0.001, 1)) = 0.25
		_SpecularToonSmoothness ("Smoothing", Range(0, 1)) = 0.05
		_SpecularRoughness ("Roughness", Range(0, 1)) = 0.5
		[Enum(Disabled,0,Albedo Alpha,1,Custom R,2,Custom G,3,Custom B,4,Custom A,5)] _SpecularMapType ("Specular Map", Float) = 0
		[NoScaleOffset] _SpecGlossMap ("Specular Texture", 2D) = "white" {}

		// Emission
		[ToggleUI] _UseEmission ("Emission", Float) = 0
		[Enum(R,0,G,1,B,2,A,3,RGB,4,No Texture,5)] _EmissionChannel ("Texture Channel", Float) = 4
		_EmissionMap ("Emission Texture", 2D) = "white" {}
		[HDR] _EmissionColor ("Emission Color", Color) = (0,0,0,1)

		// Rim Lighting
		[ToggleUI] _UseRim ("Rim Lighting", Float) = 0
		[HDR] _RimColor ("Rim Color", Color) = (0.8,0.8,0.8,0.5)
		_RimMin ("Min", Range(0, 2)) = 0.5
		_RimMax ("Max", Range(0, 2)) = 1
		[ToggleUI] _UseRimLightMask ("Light-based Mask", Float) = 1

		// MatCap
		[ToggleUI] _UseMatCap ("MatCap", Float) = 0
		[Enum(Additive,0,Replace,1)] _MatCapType ("MatCap Blending", Float) = 0
		[NoScaleOffset] _MatCapTex ("MatCap Texture", 2D) = "black" {}
		[HDR] _MatCapColor ("MatCap Color (RGB) Strength (A)", Color) = (1,1,1,1)
		[ToggleUI] _UseMatCapMask ("Enable Mask", Float) = 0
		[NoScaleOffset] _MatCapMask ("Mask Texture", 2D) = "black" {}
		[Enum(R,0,G,1,B,2,A,3)] _MatCapMaskChannel ("Mask Channel", Float) = 0

		// Occlusion
		[ToggleUI] _UseOcclusion ("Occlusion", Float) = 0
		_OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1
		[NoScaleOffset] _OcclusionMap ("Occlusion Texture", 2D) = "white" {}
		[Enum(Albedo Alpha,0,Custom R,1,Custom G,2,Custom B,3,Custom A,4)] _OcclusionChannel ("Texture Channel", Float) = 0

		// Indirect (ambient / GI)
		_IndirectIntensity ("Indirect Strength", Range(0, 1)) = 1
		[ToggleUI] _SingleIndirectColor ("Single Indirect Color", Float) = 0

		// Environment Reflections
		[ToggleUI] _UseReflections ("Indirect Specular (Reflections)", Float) = 0
		_ReflectionColor ("Reflection Color", Color) = (1,1,1,1)
		_ReflectionSmoothness ("Smoothness", Range(0, 1)) = 0.5
		[Enum(Disabled,0,Albedo Alpha,1,Custom R,2,Custom G,3,Custom B,4,Custom A,5)] _ReflectionMapType ("Reflection Mask", Float) = 0
		[NoScaleOffset] _ReflectionTex ("Reflection Mask Texture", 2D) = "white" {}
		[ToggleUI] _UseFresnelReflections ("Fresnel Reflections", Float) = 1
		_FresnelMin ("Fresnel Min", Range(0, 2)) = 0
		_FresnelMax ("Fresnel Max", Range(0, 2)) = 1.5

		// Outline
		[ToggleUI] _UseOutline ("Outline", Float) = 0
		[HDR] _OutlineColor ("Outline Color", Color) = (0,0,0,1)
		_OutlineWidth ("Outline Width", Range(0, 10)) = 1
		[Enum(Disabled,0,Vertex Shader,1,Pixel Shader,2)] _OutlineTextureType ("Textured", Float) = 0
		_OutlineTextureLOD ("Texture LOD", Range(0, 8)) = 5
		[Enum(Disabled,0,Constant,1,Minimum,2,Min Max,3)] _OutlinePixelSizeType ("Pixel Size", Float) = 0
		_OutlineMinWidth ("Minimum Width (Pixels)", Float) = 1
		_OutlineMaxWidth ("Maximum Width (Pixels)", Float) = 4
		[Enum(Normal,0,Vertex Colors,1,Tangents,2,UV1,3,UV2,4,UV3,5,UV4,6)] _NormalsSource ("Outline Normals Source", Float) = 0
		[Enum(Full XYZ,0,Compressed XY,1,Compressed ZW,2)] _NormalsUVType ("UV Normals Data", Float) = 0
		[Enum(Disabled,0,Main Directional Light,1,Indirect Only,2)] _OutlineLightingType ("Outline Lighting", Float) = 0
		_DirectIntensityOutline ("Direct Strength", Range(0, 1)) = 1
		_IndirectIntensityOutline ("Indirect Strength", Range(0, 1)) = 0
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="Geometry" }
		LOD 200

		//================================================================
		// OUTLINE PASS (inverted hull) — drawn in the base lighting pass.
		Pass
		{
			Name "OUTLINE"
			Tags { "LightMode"="ForwardBase" }
			Cull Front

			CGPROGRAM
			#pragma vertex vertOutline
			#pragma fragment fragOutline
			#pragma target 3.0
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			sampler2D _BaseMap; float4 _BaseMap_ST;
			half4 _OutlineColor;
			half _OutlineWidth;
			float _UseOutline;
			float _OutlineTextureType, _OutlineTextureLOD;
			float _OutlinePixelSizeType, _OutlineMinWidth, _OutlineMaxWidth;
			float _NormalsSource, _NormalsUVType;
			float _OutlineLightingType, _DirectIntensityOutline, _IndirectIntensityOutline;

			struct appdataO
			{
				float4 vertex    : POSITION;
				float3 normal    : NORMAL;
				float4 tangent   : TANGENT;
				float4 color     : COLOR;
				float4 texcoord0 : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				float4 texcoord3 : TEXCOORD3;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2fO
			{
				float4 pos  : SV_POSITION;
				float2 uv   : TEXCOORD0;
				fixed3 tint : TEXCOORD1;
				UNITY_FOG_COORDS(2)
				UNITY_VERTEX_OUTPUT_STEREO
			};

			// Object-space normal used to extrude the hull (supports smoothed normals
			// baked into vertex colors / tangents / UVs for hard-edged meshes).
			float3 GetOutlineNormal(appdataO v)
			{
				if (_NormalsSource < 0.5) return v.normal;                  // Normal
				if (_NormalsSource < 1.5) return v.color.xyz * 2.0 - 1.0;   // Vertex Colors
				if (_NormalsSource < 2.5) return v.tangent.xyz;             // Tangents

				// UV-based (UV1=texcoord0 ... UV4=texcoord3)
				float4 uvN;
				if (_NormalsSource < 3.5)      uvN = v.texcoord0;
				else if (_NormalsSource < 4.5) uvN = v.texcoord1;
				else if (_NormalsSource < 5.5) uvN = v.texcoord2;
				else                           uvN = v.texcoord3;

				if (_NormalsUVType < 0.5) return uvN.xyz;                   // Full XYZ

				// Octahedron-compressed (standard encoding; bake must match).
				float2 oct = (_NormalsUVType < 1.5) ? uvN.xy : uvN.zw;
				float2 f = oct * 2.0 - 1.0;
				float3 n = float3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
				float t = saturate(-n.z);
				n.x += n.x >= 0.0 ? -t : t;
				n.y += n.y >= 0.0 ? -t : t;
				return n;
			}

			// Optional tint of the outline by scene lighting.
			fixed3 OutlineLighting(float3 worldNormal)
			{
				if (_OutlineLightingType < 0.5) return fixed3(1, 1, 1);     // Disabled
				if (_OutlineLightingType > 1.5)                            // Indirect Only
					return ShadeSH9(float4(worldNormal, 1)) * _IndirectIntensityOutline;

				// Main Directional Light (+ indirect)
				half ndl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
				fixed3 direct   = _LightColor0.rgb * ndl * _DirectIntensityOutline;
				fixed3 indirect = ShadeSH9(float4(worldNormal, 1)) * _IndirectIntensityOutline;
				return direct + indirect;
			}

			v2fO vertOutline(appdataO v)
			{
				v2fO o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2fO, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				if (_UseOutline < 0.5)
				{
					o.pos = float4(2, 2, 2, 1); // collapse — nothing drawn
					UNITY_TRANSFER_FOG(o, o.pos);
					return o;
				}

				float3 n = normalize(GetOutlineNormal(v));

				if (_OutlinePixelSizeType < 0.5)
				{
					// Object-space width (~0.01 unit per step) — shrinks with distance.
					o.pos = UnityObjectToClipPos(v.vertex + float4(n * (_OutlineWidth * 0.01), 0));
				}
				else
				{
					// Screen-space width: keep a constant/clamped pixel thickness.
					float4 clipBase = UnityObjectToClipPos(v.vertex);
					float3 viewN = mul((float3x3)UNITY_MATRIX_IT_MV, n);
					float2 clipDir = TransformViewToProjection(viewN.xy);
					float clipLen = length(clipDir);
					clipDir = clipLen > 1e-5 ? clipDir / clipLen : float2(0, 0);

					float pixels;
					if (_OutlinePixelSizeType < 1.5)        // Constant
					{
						pixels = _OutlineMinWidth;
					}
					else                                    // Minimum / Min Max
					{
						float4 clipObj = UnityObjectToClipPos(v.vertex + float4(n * (_OutlineWidth * 0.01), 0));
						float2 ndcOffset = (clipObj.xy / clipObj.w) - (clipBase.xy / clipBase.w);
						float objPixels = length(ndcOffset) * _ScreenParams.y * 0.5;
						pixels = max(objPixels, _OutlineMinWidth);
						if (_OutlinePixelSizeType > 2.5) pixels = min(pixels, _OutlineMaxWidth); // Min Max
					}

					clipBase.xy += clipDir * (pixels / _ScreenParams.y) * clipBase.w * 2.0;
					o.pos = clipBase;
				}

				// Textured outline (Vertex mode samples albedo here; Pixel mode in fragment).
				o.uv = TRANSFORM_TEX(v.texcoord0.xy, _BaseMap);
				fixed3 texTint = fixed3(1, 1, 1);
				if (_OutlineTextureType > 0.5 && _OutlineTextureType < 1.5)
					texTint = tex2Dlod(_BaseMap, float4(o.uv, 0, _OutlineTextureLOD)).rgb;

				fixed3 lightTint = OutlineLighting(UnityObjectToWorldNormal(v.normal));
				o.tint = texTint * lightTint;

				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			half4 fragOutline(v2fO i) : SV_Target
			{
				fixed4 col = _OutlineColor;
				col.rgb *= i.tint;
				if (_OutlineTextureType > 1.5) // Pixel mode
					col.rgb *= tex2D(_BaseMap, i.uv).rgb;
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}

		//================================================================
		// FORWARD BASE — main directional light + ambient/lightmaps.
		Pass
		{
			Name "FORWARD"
			Tags { "LightMode"="ForwardBase" }
			Cull [_Cull]
			ZWrite [_ZWrite]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#pragma multi_compile_instancing
			#pragma skip_variants DYNAMICLIGHTMAP_ON DIRECTIONAL_COOKIE POINT_COOKIE VERTEXLIGHT_ON
			#include "TCP2_HybridShader3.cginc"
			ENDCG
		}

		//================================================================
		// FORWARD ADD — one additive pass per extra point/spot/directional light.
		Pass
		{
			Name "FORWARD_ADD"
			Tags { "LightMode"="ForwardAdd" }
			Cull [_Cull]
			ZWrite Off
			Blend One One

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#define TCP2_FORWARD_ADD
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#pragma multi_compile_instancing
			#pragma skip_variants DIRECTIONAL_COOKIE POINT_COOKIE
			#include "TCP2_HybridShader3.cginc"
			ENDCG
		}

		//================================================================
		// SHADOW CASTER — casts shadows, with alpha clipping support.
		Pass
		{
			Name "SHADOWCASTER"
			Tags { "LightMode"="ShadowCaster" }
			Cull [_Cull]

			CGPROGRAM
			#pragma vertex vertShadow
			#pragma fragment fragShadow
			#pragma target 3.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			sampler2D _BaseMap; float4 _BaseMap_ST;
			fixed4 _BaseColor;
			half _Cutoff;
			float _UseAlphaTest;

			struct appdataS
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2fS
			{
				V2F_SHADOW_CASTER;
				float2 uv : TEXCOORD1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2fS vertShadow(appdataS v)
			{
				v2fS o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				return o;
			}

			fixed4 fragShadow(v2fS i) : SV_Target
			{
				if (_UseAlphaTest > 0.5)
				{
					fixed a = tex2D(_BaseMap, i.uv).a * _BaseColor.a;
					clip(a - _Cutoff);
				}
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}

		//================================================================
		// META — albedo & emission for baked GI (lightmapping).
		Pass
		{
			Name "META"
			Tags { "LightMode"="Meta" }
			Cull Off

			CGPROGRAM
			#pragma vertex vertMeta
			#pragma fragment fragMeta
			#pragma shader_feature EDITOR_VISUALIZATION
			#include "UnityCG.cginc"
			#include "UnityMetaPass.cginc"

			sampler2D _BaseMap; float4 _BaseMap_ST;
			fixed4 _BaseColor;
			float _UseEmission;
			float _EmissionChannel;
			sampler2D _EmissionMap;
			fixed4 _EmissionColor;

			struct appdataM
			{
				float4 vertex : POSITION;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float2 uv2 : TEXCOORD2;
			};

			struct v2fM
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2fM vertMeta(appdataM v)
			{
				v2fM o;
				o.pos = UnityMetaVertexPosition(v.vertex, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST);
				o.uv = TRANSFORM_TEX(v.uv0, _BaseMap);
				return o;
			}

			fixed4 fragMeta(v2fM i) : SV_Target
			{
				UnityMetaInput o;
				UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);
				o.Albedo = tex2D(_BaseMap, i.uv).rgb * _BaseColor.rgb;
				o.Emission = 0;
				if (_UseEmission > 0.5)
				{
					fixed3 em;
					if (_EmissionChannel > 4.5) em = _EmissionColor.rgb;              // No Texture
					else
					{
						half4 et = tex2D(_EmissionMap, i.uv);
						if (_EmissionChannel > 3.5) em = et.rgb * _EmissionColor.rgb;  // RGB
						else if (_EmissionChannel < 0.5) em = et.r * _EmissionColor.rgb;
						else if (_EmissionChannel < 1.5) em = et.g * _EmissionColor.rgb;
						else if (_EmissionChannel < 2.5) em = et.b * _EmissionColor.rgb;
						else em = et.a * _EmissionColor.rgb;
					}
					o.Emission = em;
				}
				return UnityMetaFragment(o);
			}
			ENDCG
		}
	}

	Fallback "Diffuse"
}
