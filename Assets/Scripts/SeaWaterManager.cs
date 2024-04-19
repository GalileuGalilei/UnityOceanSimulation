using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class SeaWaterManager : MonoBehaviour
{
    private Material seaMaterial;

    void Start()
    {
        Renderer renderer = GetComponent<Renderer>();
        seaMaterial= renderer.sharedMaterial;

        Vector4 waveA = seaMaterial.GetVector("_WaveA");
        Vector4 waveB = seaMaterial.GetVector("_WaveB");
        Vector4 waveC = seaMaterial.GetVector("_WaveC");
        Vector4 waveD = seaMaterial.GetVector("_WaveD");
        Vector4 waveE = seaMaterial.GetVector("_WaveE");

        float maxHeight = MaxWaveHeightFunction(waveA);
        maxHeight += MaxWaveHeightFunction(waveB);
        maxHeight += MaxWaveHeightFunction(waveC);
        maxHeight += MaxWaveHeightFunction(waveD);
        maxHeight += MaxWaveHeightFunction(waveE);

        seaMaterial.SetFloat("_MaxHeightWave", maxHeight);
    }

    //calcula a maior altura possível de uma onda
    private float MaxWaveHeightFunction(Vector4 wave)
    {
        float steepness = wave.z;
        float wavelength = wave.w;
        float k = 2 * Mathf.PI / wavelength;
        float a = steepness / k;

        return (1 * a + a);
    }
}
