#ifndef SEA_PARALLAX
#define SEA_PARALLAX

float CalculateUVHeight(float2 uv)
{
    float height = 0;
    height += WaveHeightFunction(_WaveA, uv);
    height += WaveHeightFunction(_WaveB, uv);
    height += WaveHeightFunction(_WaveC, uv);
    height += WaveHeightFunction(_WaveD, uv);
    height += WaveHeightFunction(_WaveE, uv);
    height /= (_MaxHeightWave);
    return height;
}

float2 ParallaxOffset(float3 p, float2 viewDir)
{
    float height = CalculateUVHeight(p.xz);

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

        height = CalculateUVHeight(p.xz);
        uvOffset -= uvDelta;
        stepHeight -= stepSize;
    } 

    float prevDifference = prevStepHeight - prevHeight;
	float difference = height - stepHeight;
	float t = prevDifference / (prevDifference + difference);
    uvOffset = prevUVOffset - uvDelta * t;

    return uvOffset;
}


#endif
