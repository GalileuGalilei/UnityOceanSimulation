#ifndef SEA_FLOW
#define SEA_FLOW

#include "WaterInclude.cginc"

////// PRIVATE //////

float3 WaveFunction(float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
{
	float steepness = wave.z;
	float wavelength = wave.w;
	float k = 2 * UNITY_PI / wavelength;
	float c = sqrt(9.8 / k);
	float2 d = normalize(wave.xy);
	float f = k * (dot(d, p.xz) - c * _Time.y);
	float a = steepness / k;

	tangent += float3(
		-d.x * d.x * (steepness * sin(f)),
		d.x * (steepness * cos(f)),
		-d.x * d.y * (steepness * sin(f))
	);
	binormal += float3(
		-d.x * d.y * (steepness * sin(f)),
		d.y * (steepness * cos(f)),
		-d.y * d.y * (steepness * sin(f))
	);
	float3 v = float3(
		d.x * (a * cos(f) + a),
		a * sin(f) + a,
		d.y * (a * cos(f))
	);
    return v;
}

float3 FlowUVW (float2 uv, float2 flowVector, float2 jump, float tiling, float time, bool flowB) 
{
	float phaseOffset = flowB ? 0.5 : 0;
	float progress = frac(time + phaseOffset);
	float3 uvw;

	uvw.xy = uv - flowVector * progress;
	uvw.xy *= tiling;
	uvw.xy += phaseOffset;
	uvw.xy += (time - progress) * jump;
	uvw.z = 1 - abs(1 - 2 * progress);

	return uvw;
}

float3 CalculateLargeWavesNormals(
								float4 waveA,
								float4 waveB,
								float4 waveC,
								float4 waveD,
								float4 waveE,
								float largeWavesTiling, inout float3 p)
{
    float3 tangent = float3(1, 0, 0);
	float3 binormal = float3(0, 0, 1);
    float3 dv = float3(0, 0, 0); //displaced vertice
	
	dv += WaveFunction(waveA, p * largeWavesTiling, tangent, binormal);
    dv += WaveFunction(waveB, p * largeWavesTiling, tangent, binormal);
    dv += WaveFunction(waveC, p * largeWavesTiling, tangent, binormal);
    dv += WaveFunction(waveD, p * largeWavesTiling, tangent, binormal);
    dv += WaveFunction(waveE, p * largeWavesTiling, tangent, binormal);
   
	p += dv;
	return normalize(cross(binormal, tangent));
}

float3 CalculateDetailedNormals(sampler2D flowMap, sampler2D normalMap, float2 uv, float2 jump, float tilling, float speed, float scale)
{
    float noise = tex2D(flowMap, uv * tilling).a;
	float3 flowVector = tex2D(flowMap, uv).rgb;
    float noiseTime = noise + _Time.y * speed;
	
	flowVector.xy = (flowVector.xy * 2 - 1) * flowVector.z; //multiplica pela velocidade do flowMap
    flowVector.xy += float2(1, 0) * speed;
	
	
    float3 uvwA = FlowUVW(uv, flowVector.xy, jump, tilling, noiseTime, false);
    float3 uvwB = FlowUVW(uv, flowVector.xy, jump, tilling, noiseTime, true);

    float3 normalA = UnpackNormalWithScale(tex2D(normalMap, uvwA.xy), scale) * uvwA.z;
	float3 normalB = UnpackNormalWithScale(tex2D(normalMap, uvwB.xy), scale) * uvwB.z;
    return (normalA + normalB) / 2;
}

float3 CalculateDetailedNormalsLod(sampler2D flowMap, sampler2D normalMap, float2 uv, float2 jump, float tilling, float speed, float scale, float lod)
{
    float noise = tex2D(flowMap, uv * tilling).a;
    float3 flowVector = tex2D(flowMap, uv).rgb;
    float noiseTime = noise + _Time.y * speed;
	
    flowVector.xy = (flowVector.xy * 2 - 1) * flowVector.z; //multiplica pela velocidade do flowMap
    flowVector.xy += float2(1, 0) * speed;
	
    float4 uvwA = float4(FlowUVW(uv, flowVector.xy, jump, tilling, noiseTime, false), lod);
    float4 uvwB = float4(FlowUVW(uv, flowVector.xy, jump, tilling, noiseTime, true), lod);

    float3 normalA = UnpackNormalWithScale(tex2Dlod(normalMap, uvwA), scale) * uvwA.z;
    float3 normalB = UnpackNormalWithScale(tex2Dlod(normalMap, uvwB), scale) * uvwB.z;
    return (normalA + normalB) / 2;
}

//////// PUBLIC ////////

//Ambas as funções assumem que as textures de flowMap e normalMap estão presentes no shader destino.

float3 CalculateOceanWaterNormal(
	float3 v,
	float2 jump,
	float wavesTillig,
	float smallWavesTiling,
	float smallWavesSpeed,
	float smallWavesStrength,
	float waterTilling,
	float waterSpeed,
	float waterStrength,
	float lod)
{
    float3 dv = v;
    float3 detailedWaterNormal = CalculateDetailedNormals(_WaterFlowMap, _DetailedWaterNormals, v.xz, jump, waterTilling, waterSpeed, waterStrength);
    float3 largeWavesNormal = CalculateLargeWavesNormals(WAVES_PARAM, wavesTillig, dv);
	largeWavesNormal.y *= lod;
	largeWavesNormal = normalize(largeWavesNormal);	

    float3 detailedSmallWavesNormal = CalculateDetailedNormalsLod(_WaterFlowMap, _SmallWavesNormal, v.xz, jump, smallWavesTiling, smallWavesSpeed, smallWavesStrength / lod,0);

    float3 normal = BlendNormals(largeWavesNormal, detailedSmallWavesNormal);
    normal = BlendNormals(normal.xzy, detailedWaterNormal);
	normal.z *= lod;

    return normalize(normal);
}

#endif