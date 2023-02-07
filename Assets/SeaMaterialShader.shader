Shader "Custom/SeaMaterialShader"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [NoScaleOffset] _SeaNoiseFlowTex ("FlowNoise(Alpha)", 2D) = "black" {}
        [NoScaleOffset] _WaterDistortionNormalMap ("Normals", 2D) = "bump" {}

		_ParallaxStrength ("Parallax Strength", Range(0, 0.4)) = 0
        _ParallaxRaymarchingSteps ("Parallax Raymarching Steps", float) = 10
        _MaxHeightWave ("Maximu Height of a Wave", float) = 4
        _ParallaxBias ("Parallax Bias", Range(0,1)) = 0.42

        _Color ("Color", Color) = (1,1,1,1)
        _WaterDistortionSpeed ("Speed", Float) = 1
        _UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
		_VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25

        _WaterTiling ("Water Tiling", Float) = 1
        _WavesTiling ("Waves Tiling", Float) = 1
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        _WaveA ("Wave A (dir, steepness, wavelength)", Vector) = (1,0,0.5,10)
        _WaveB ("Wave B", Vector) = (0,1,0.25,20)
        _WaveC ("Wave C", Vector) = (1,1,0.15,10)
        _WaveD ("Wave D", Vector) = (0.5,0.5,0.15,15)
        _WaveE ("Wave D", Vector) = (0.5,0.5,0.15,15)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        
        #pragma target 3.0
        #pragma surface surf Standard fullforwardshadows vertex:vert addshadow
        #pragma shader_feature _PARALLAX_MAP

        #include "seaMaterialFlow.cginc"
        #include "SeaMaterialParallax.cginc"

        sampler2D _MainTex, _SeaNoiseFlowTex, _WaterDistortionNormalMap;

        struct Input
        {
            float2 uv_MainTex;
            float3 v;

            #if defined(SEA_PARALLAX)
		        float3 tangentViewDir : TEXCOORD8;
	        #endif
        };

        half _Glossiness;
        half _Metallic;
        float _ParallaxStrength;
        float _ParallaxRaymarchingSteps;
        float _FlowScale;
        float _ParallaxBias;
        float _UJump;
        float _VJump;
        float _WaterTiling;
        float _WavesTiling;
        float _WaterDistortionSpeed;
        float _MaxHeightWave;
        fixed4 _Color;
        float4 _WaveA;
        float4 _WaveB;
        float4 _WaveC;
        float4 _WaveD;
        float4 _WaveE;
        

        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        float2 ParallaxOffset(float3 p, float2 viewDir)
        {
            float height = WaveHeightFunction(_WaveA, p.xz);
            height += WaveHeightFunction(_WaveB, p.xz);
            height += WaveHeightFunction(_WaveC, p.xz);
            height += WaveHeightFunction(_WaveD, p.xz);
            height += WaveHeightFunction(_WaveE, p.xz);

            height /= _MaxHeightWave;
            height -= 0.5;
            height *= _ParallaxStrength;
            return viewDir * height;
        }

        float2 ParallaxRaymarching(float3 p, float2 viewDir)
        {
	        const float stepSize = 1 / _ParallaxRaymarchingSteps;
            float2 uvDelta = viewDir * (stepSize * _ParallaxStrength);

            float2 uvOffset = 0;
            float stepHeight = 1;
            float height = 0;

            float2 prevUVOffset = uvOffset;
	        float prevStepHeight = stepHeight;
	        float prevHeight = height;


            while(stepHeight > height)
            {
                prevUVOffset = uvOffset;
	            prevStepHeight = stepHeight;
	            prevHeight = height;

                height = 0;
                height += WaveHeightFunction(_WaveA, p.xz + uvOffset);
                height += WaveHeightFunction(_WaveB, p.xz + uvOffset);
                height += WaveHeightFunction(_WaveC, p.xz + uvOffset);
                height += WaveHeightFunction(_WaveD, p.xz + uvOffset);
                height += WaveHeightFunction(_WaveE, p.xz + uvOffset);
                height /= (_MaxHeightWave);
                uvOffset -= uvDelta;
                stepHeight -= stepSize;
            } 

            float prevDifference = prevStepHeight - prevHeight;
	        float difference = height - stepHeight;
	        float t = prevDifference / (prevDifference + difference);
            uvOffset = prevUVOffset - uvDelta * t;

            return uvOffset;
        }

        void ApplyParallax(inout Input IN, float3 dv)
        {
            IN.tangentViewDir = normalize(IN.tangentViewDir);
            IN.tangentViewDir.xy /= (IN.tangentViewDir.z + _ParallaxBias);

		    #if !defined(PARALLAX_FUNCTION)
			    #define PARALLAX_FUNCTION ParallaxRaymarching
		    #endif


            float2 uvOffset = PARALLAX_FUNCTION(IN.v, IN.tangentViewDir.xy);
	        IN.uv_MainTex.xy += uvOffset;
        }

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            #if defined(SEA_PARALLAX)
            	v.tangent.xyz = normalize(v.tangent.xyz);
			    v.normal = normalize(v.normal);
		        float3x3 objectToTangent = float3x3(
			        v.tangent.xyz,
			        cross(v.normal, v.tangent.xyz) * v.tangent.w,
			        v.normal
		        );		        

                o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
	        #endif

            o.v = v.vertex.xyz * _WavesTiling;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float3 p = IN.v;
            float3 tangent = float3(1, 0, 0);
			float3 binormal = float3(0, 0, 1);
            float3 dv = waveFunction(_WaveA, p, tangent, binormal);
            dv += waveFunction(_WaveB, p, tangent, binormal);
            dv += waveFunction(_WaveC, p, tangent, binormal);
            dv += waveFunction(_WaveD, p, tangent, binormal);
            dv += waveFunction(_WaveE, p, tangent, binormal);
            half3 normal = normalize(cross(binormal, tangent));

            float foam = 0;
            foam = 1 - normal.y;
            foam *= foam;


            #if defined(SEA_PARALLAX)
                ApplyParallax(IN, dv);
	        #endif

            if(IN.uv_MainTex.x > 1 || IN.uv_MainTex.y > 1)
            {
                discard;
            }

            float2 flowVector = 0; 

            float noise = tex2D(_SeaNoiseFlowTex, IN.uv_MainTex).a;
            float noiseTime = noise + _Time.y * _WaterDistortionSpeed;
            float2 jump = float2(_UJump, _VJump);

            float3 uvwA = SeaFlowUVW(IN.uv_MainTex, flowVector, jump, _WaterTiling, noiseTime, false);
			float3 uvwB = SeaFlowUVW(IN.uv_MainTex, flowVector, jump, _WaterTiling, noiseTime, true);

            float3 normalA = UnpackNormal(tex2D(_WaterDistortionNormalMap, uvwA.xy)) * uvwA.z;
			float3 normalB = UnpackNormal(tex2D(_WaterDistortionNormalMap, uvwB.xy)) * uvwB.z;

            o.Normal = BlendNormals(normalA.xzy, normalB.xzy).xzy;
            o.Normal = BlendNormals(normal.xzy, o.Normal);

			fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
			fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;

			fixed4 c = (texA + texB) * _Color;

            o.Albedo = c.xyz + float3(foam, foam, foam);
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;

        }
        ENDCG
    }
    FallBack "Diffuse"
}
