using UnityEngine;
using UnityEditor;
using System.Collections;

[CustomEditor(typeof(MatrixRotator))]
class MatrixRotatorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        if (GUILayout.Button("Set Rotation"))
		{
			((MonoBehaviour)target).gameObject.GetComponent<MatrixRotator>().Update();
		}
	}
}