using UnityEngine;
using UnityEditor;
using System.Collections;

[CustomEditor(typeof(Kontroller))]
class KontrollerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        if (GUILayout.Button("Assign Spatial Mapping Material to Debug"))
		{
			((MonoBehaviour)target).gameObject.GetComponent<Kontroller>().UpdateMeshRendererMaterial();
		}
	}
}