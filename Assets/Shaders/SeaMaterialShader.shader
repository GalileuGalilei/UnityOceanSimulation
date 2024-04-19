//adaptação do shader de água do unity para o projeto
Shader "Custom/OceanWaterShader" 
{
	Properties 
	{
		_SmallWavesNormal ("small waves normals", 2D) = "bump" {}
		_DetailedWaterNormals ("stationary water normals", 2D) = "bump" {}
		_WaterFlowMap ("flowMap - (RG) = vector field, (B) = noise, (A) = flowSpeed", 2D) = "black" {}
	
		_UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
		_VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
		_Shininess ("Shininess", Range (2.0, 500.0)) = 200.0
		_FresnelScale ("FresnelScale", Range (0.15, 4.0)) = 0.75
		_NormalScale ("NormalScale", Range (0.0, 1.0)) = 0.5
	
		_DistortParams ("Distortions (Bump waves, Reflection, Fresnel power, Fresnel bias)", Vector) = (1.0 ,1.0, 2.0, 1.15)
		_InvFadeParemeter ("Auto blend parameter (Edge, Shore, Distance scale)", Vector) = (0.15 ,0.15, 0.5, 1.0)
		_WorldLightDir ("Specular light direction", Vector) = (0.0, 0.1, -0.5, 0.0)
	
		_BaseColor ("Base color", COLOR)  = ( .54, .95, .99, 0.5)
		_ReflectionColor ("Reflection color", COLOR)  = ( .54, .95, .99, 0.5)
		_SpecularColor ("Specular color", COLOR)  = ( .72, .72, .72, 1)
		
		_WaterDistortionSpeed ("stationary water speed", Float) = 1
		_WaterTiling ("Water Tiling", Float) = 1
    
		_WavesTiling ("Waves Tiling", Float) = 1
		_SmallWavesSpeed ("small waves speed", Float) = 1
		_SmallWavesStrength ("small waves strength", Float) = 1
		_SmallWavesTiling ("small waves tiling", Float) = 1

		_WaveA ("Wave A (dir, steepness, wavelength)", Vector) = (1,0,0.5,10)
		_WaveB ("Wave B", Vector) = (0,1,0.25,20)
		_WaveC ("Wave C", Vector) = (1,1,0.15,10)
		_WaveD ("Wave D", Vector) = (0.5,0.5,0.15,15)
		_WaveE ("Wave E", Vector) = (0.5,0.5,0.15,15)
	}


CGINCLUDE

	#include "UnityCG.cginc"

	struct appdata
	{
		float4 vertex : POSITION;
		float3 normal : NORMAL;
	};

	// interpolator structs
	
	struct v2f
	{
		float4 pos : SV_POSITION;
		float3 worldPos : TEXCOORD0;
		float4 viewInterpolator : TEXCOORD1;
		UNITY_FOG_COORDS(2)
		float4 screenPos : TEXCOORD3;
		float4 grabPassPos : TEXCOORD4;
	};
	
	// textures for reflection & refraction
	sampler2D _RefractionTex;
	sampler2D _CameraDepthTexture;

	// textures for distorting the normals
	sampler2D _WaterFlowMap, _DetailedWaterNormals;
	
	// stationary water
	float _UJump, _VJump;

	// specularity
	float4 _WorldLightDir;

	/////// UNIFORMS DO OCEANO ////////

	// edge & shore fading
	float4 _InvFadeParemeter;
	
	// colors in use
	float4 _RefrColorDepth;
	float4 _SpecularColor;
	float4 _BaseColor;
	float4 _ReflectionColor;
	
	// specularity
	float _Shininess;

	// fresnel, vertex & bump displacements & strength
	float4 _DistortParams;
	float _FresnelScale;
	float _NormalScale;
	
	// stationary water
	float _WaterDistortionSpeed, _WaterTiling;

	// waves
	float4 _WaveA, _WaveB, _WaveC, _WaveD, _WaveE;
	float _WavesTiling;

	// small waves
	float _SmallWavesSpeed, _SmallWavesTiling, _SmallWavesStrength;
	sampler2D _SmallWavesNormal;

	//shortcut.
	#define WAVES_PARAM _WaveA, _WaveB, _WaveC, _WaveD, _WaveE
	
	//aux functions
	#include "WaterFlow.cginc"
	#include "WaterLighting.cginc"

	v2f vert(appdata_full v)
	{
		half3 worldSpaceVertex = mul(unity_ObjectToWorld,(v.vertex)).xyz;

		v2f o;
		o.worldPos = worldSpaceVertex;
		o.viewInterpolator.xyz = worldSpaceVertex - _WorldSpaceCameraPos;
		o.pos = UnityObjectToClipPos(v.vertex);
		
		ComputeScreenAndGrabPassPos(o.pos, o.screenPos, o.grabPassPos);
		UNITY_TRANSFER_FOG(o,o.pos);
		
		return o;
	}
	
	
	half4 frag( v2f i ) : SV_Target
	{		
		const float maxLodDistance = 10.0; // max distance for the LOD to kick in
		float lodLevel = clamp(length(i.viewInterpolator.xyz) / maxLodDistance, 1.5, maxLodDistance); 
		
		
		half3 worldNormal = CalculateOceanWaterNormal(
			i.worldPos,
			float2(_UJump, _VJump),
			_WavesTiling,
			_SmallWavesTiling,
			_SmallWavesSpeed,
			_SmallWavesStrength,
			_WaterTiling,
			_WaterDistortionSpeed,
			_NormalScale,
			lodLevel).xzy;

		half3 viewVector = normalize(i.viewInterpolator.xyz);
		half4 baseColor = ExtinctColor (_BaseColor, i.viewInterpolator.w * _InvFadeParemeter.w);

		half4 edgeBlendFactor = CalculateEdgeBlendFactors(i.screenPos, _InvFadeParemeter);
		float darkFactor = saturate(dot(float3(0, -1, 0), _WorldLightDir.xyz) - 0.25); //night color
		
		CalculateRefractionColor(baseColor, worldNormal, i.screenPos, i.grabPassPos, _DistortParams.y);
		CalculateReflectionColor(baseColor, _ReflectionColor, worldNormal, viewVector, _DistortParams.w, _DistortParams.z, _FresnelScale);
		
		half4 specularColor = CalculateSpecularColor(worldNormal, viewVector, _SpecularColor, _Shininess);
		baseColor = saturate(baseColor + specularColor);
		//baseColor.rgb *= darkFactor;
		baseColor.a *= edgeBlendFactor.x;
		
		UNITY_APPLY_FOG(i.fogCoord, baseColor);
		return baseColor;
	}
	
	
ENDCG

Subshader
{
	Tags {"RenderType"="Transparent"}
	
	Lod 500
	ColorMask RGBA
	
	GrabPass { "_RefractionTex" }
	
	Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite true
			Cull Off
		
			CGPROGRAM
		
			#pragma target 4.6
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
		
			#pragma multi_compile WATER_VERTEX_DISPLACEMENT_OFF
			#pragma multi_compile WATER_EDGEBLEND_ON 
			#pragma multi_compile WATER_REFLECTIVE WATER_SIMPLE
		
			ENDCG
	}
}

Fallback "Transparent/Diffuse"
}