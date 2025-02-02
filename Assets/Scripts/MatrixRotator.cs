﻿using UnityEngine;

public class MatrixRotator : MonoBehaviour
{
    public float rotateSpeed = 30f;
    public Vector3 rotation;

    // Update is called once per frame
    public void Update()
    {
        // Construct a rotation matrix and set it for the shader
        //Quaternion rot = Quaternion.Euler(axis.x, axis.y, axis.z + Time.time * rotateSpeed);
        Quaternion rot = Quaternion.Euler(rotation.x, rotation.y, rotation.z);

        Matrix4x4 m = Matrix4x4.TRS(Vector3.zero, rot, Vector3.one);
        GetComponent<Controller>().SpatialMappingMaterial.SetMatrix("_Rotation", m);
    }
}
