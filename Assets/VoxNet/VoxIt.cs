using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class VoxIt : MonoBehaviour
{

    public GameObject Go;

    public Vector3[] Filter(Vector3[] input)
    {
        List<Vector3> filtered = new List<Vector3>();

        foreach (Vector3 c in input)
        {
            // TODO make this function a passed in function
            // should take a vec3 and return T/F
            if (c.y > 0)
                filtered.Add(c);
        }

        return filtered.ToArray();
    }

    // Use this for initialization
    void Start()
    {
        Mesh mesh = Go.GetComponent<MeshFilter>().mesh;
        Vector3[] normals = mesh.normals;

        //for (var n in normals)
        //{
        //    for (var p in mesh.GetIndices)
        //    {
        //    }
        //}
        Debug.Log("# Normals=" + normals.Length);

        Vector3[] facingUp = Filter(normals);

        Debug.Log("# Normals(filtered)=" + facingUp.Length);
    }

    // Update is called once per frame
    void Update()
    {

    }
}
