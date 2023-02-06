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
    }

    void LateUpdate()
    {
       // seaMaterial.SetFloat("time", Time.timeSinceLevelLoad);
    }
}
