Shader "Shader Graphs/ArnoldStandardSurfaceTransparent" {
	Properties {
		_BASE_COLOR ("BaseColor", Vector) = (0,0,0,0)
		[NoScaleOffset] _BASE_COLOR_MAP ("BaseColorMap", 2D) = "white" {}
		_METALNESS ("Metalness", Float) = 0
		[NoScaleOffset] _METALNESS_MAP ("MetalnessMap", 2D) = "white" {}
		_SPECULAR_COLOR ("SpecularColor", Vector) = (1,1,1,0)
		[NoScaleOffset] _SPECULAR_COLOR_MAP ("SpecularColorMap", 2D) = "white" {}
		_SPECULAR_ROUGHNESS ("SpecularRoughness", Float) = 0
		[NoScaleOffset] _SPECULAR_ROUGHNESS_MAP ("SpecularRoughnessMap", 2D) = "white" {}
		_SPECULAR_IOR ("SpecularIOR", Float) = 1.5
		[NoScaleOffset] _SPECULAR_IOR_MAP ("SpecularIORMap", 2D) = "white" {}
		_EMISSION_COLOR ("EmissionColor", Vector) = (0,0,0,0)
		[NoScaleOffset] _EMISSION_COLOR_MAP ("EmissionColorMap", 2D) = "white" {}
		[NoScaleOffset] [Normal] _NORMAL_MAP ("NormalMap", 2D) = "bump" {}
		_OPACITY ("Opacity", Range(0, 1)) = 1
		[NoScaleOffset] _OPACITY_MAP ("OpacityMap", 2D) = "white" {}
		[HideInInspector] _QueueOffset ("_QueueOffset", Float) = 0
		[HideInInspector] _QueueControl ("_QueueControl", Float) = -1
		[HideInInspector] [NoScaleOffset] unity_Lightmaps ("unity_Lightmaps", 2DArray) = "" {}
		[HideInInspector] [NoScaleOffset] unity_LightmapsInd ("unity_LightmapsInd", 2DArray) = "" {}
		[HideInInspector] [NoScaleOffset] unity_ShadowMasks ("unity_ShadowMasks", 2DArray) = "" {}
	}
	//DummyShaderTextExporter
	SubShader{
		Tags { "RenderType" = "Opaque" }
		LOD 200

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			float4x4 unity_ObjectToWorld;
			float4x4 unity_MatrixVP;

			struct Vertex_Stage_Input
			{
				float4 pos : POSITION;
			};

			struct Vertex_Stage_Output
			{
				float4 pos : SV_POSITION;
			};

			Vertex_Stage_Output vert(Vertex_Stage_Input input)
			{
				Vertex_Stage_Output output;
				output.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, input.pos));
				return output;
			}

			float4 frag(Vertex_Stage_Output input) : SV_TARGET
			{
				return float4(1.0, 1.0, 1.0, 1.0); // RGBA
			}

			ENDHLSL
		}
	}
	Fallback "Hidden/Shader Graph/FallbackError"
	//CustomEditor "UnityEditor.ShaderGraph.GenericShaderGraphMaterialGUI"
}