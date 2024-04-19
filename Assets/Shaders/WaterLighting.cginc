#ifndef WATER_LIGHTING
#define WATER_LIGHTING

// As funções auxiliares desse arquivo assumem as texturas _CameraDepthTexture e _RefractionTex já declaradas e preenchidas no shader destino,
//assim como o vetor _WorldLightDir.

void CalculateRefractionColor(inout half4 baseColor, half3 worldNormal, float4 screenPos, half4 grabPassPos, float distortionStrength)
{
    half4 distortOffset = half4(worldNormal.xz * distortionStrength * 10.0, 0, 0);
    half4 grabWithOffset = grabPassPos + distortOffset;
		
    half4 rtRefractionsNoDistort = tex2Dproj(_RefractionTex, UNITY_PROJ_COORD(grabPassPos));
    half refrFix = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(grabWithOffset));
    half4 rtRefractions = tex2Dproj(_RefractionTex, UNITY_PROJ_COORD(grabWithOffset));
		
    if (LinearEyeDepth(refrFix) < screenPos.z)
    {
        rtRefractions = rtRefractionsNoDistort;
    }

    baseColor = lerp(rtRefractions, baseColor, baseColor.a);
}

void CalculateReflectionColor(inout half4 baseColor, half4 reflectionColor, half3 worldNormal, half3 viewVector, float fresnelBias, float fresnelPower, float fresnelScale)
{
    worldNormal.xz *= fresnelScale;
    half refl2Refr = Fresnel(viewVector, worldNormal, fresnelBias, fresnelPower);
		
    baseColor = lerp(reflectionColor, baseColor, refl2Refr);
}

half4 CalculateDiffuseFactor(half3 worldNormal, half4 diffuseColor)
{
    return max(0.0, clamp(dot(worldNormal, -_WorldLightDir.xyz), 0, 1));
}
	
half4 CalculateSpecularColor(half3 worldNormal, half3 viewVector, half4 specularColor, float shininess)
{
    half3 reflectVector = normalize(reflect(viewVector, worldNormal));
    half3 h = normalize((_WorldLightDir.xyz) + viewVector.xyz);
    float nh = max(0, dot(worldNormal, -h));
    float spec = max(0.0, pow(nh, shininess));
		
    return spec * specularColor;
}
	
half4 CalculateEdgeBlendFactors(float4 screenPos, float4 invFadeParemeter)
{
    half4 edgeBlendFactors = half4(1.0, 0.0, 0.0, 0.0);
		
    float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(screenPos));
    depth = LinearEyeDepth(depth);
    edgeBlendFactors = saturate(invFadeParemeter * (depth - screenPos.w));
    edgeBlendFactors.y = 1.0 - edgeBlendFactors.y;

    return edgeBlendFactors;
}

#endif