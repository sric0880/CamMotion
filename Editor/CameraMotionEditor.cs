using UnityEngine;
using UnityEditor;
using System.Collections;

[CustomEditor(typeof(CameraMotion))]
public class CustomInsp : Editor {

	public override void OnInspectorGUI()
	{
		CameraMotion myTarget = (CameraMotion)target;
		myTarget.rotationSensitivity = EditorGUILayout.Slider("Rotation Sensitivity", myTarget.rotationSensitivity, 0, 1);

		myTarget.moveSpeed = EditorGUILayout.FloatField("Move Speed", myTarget.moveSpeed);
		myTarget.port = EditorGUILayout.IntField("Port", myTarget.port);
	}
}
