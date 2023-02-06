#ifndef SEA_FLOW
#define SEA_FLOW

float3 SeaFlowUVW (float2 uv, float2 flowVector, float2 jump, float tiling, float time, bool flowB) 
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

//versão simplificada da função que calcula as ondas(todo: verificar a possibilidade da utilização de todos os eixos)
inline float WaveHeightFunction(float4 wave, float2 p)
{
	float steepness = wave.z;
	float wavelength = wave.w;
	float k = 2 * UNITY_PI / wavelength;
	float c = sqrt(9.8 / k);
	float2 d = normalize(wave.xy);

	//p.xz !!
	float f = k * (dot(d, p.xy) - c * _Time.y);
	float a = steepness / k;

    return (sin(f) * a + a);
}

inline float3 waveFunction(float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
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

#endif