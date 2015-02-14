using System;
using UnityEngine;
using UnityEditor;
using System.Collections;
using System.Collections.Generic;
using System.Threading;
using System.Net;
using System.Net.Sockets;
using System.IO;

public class CameraMotion : MonoBehaviour {
	#region Animation Clip Record
	public float rotationSensitivity = 0.1f; //the smaller the smoother
	public float moveSpeed = 10f;
	private bool recording;
    private float startTime;
	private List<float> data = new List<float>();
	//TODO add more curve...
	private string[] curveNames = new[] { "localRotation.x", "localRotation.y", "localRotation.z", "localRotation.w", "localPosition.x", "localPosition.y", "localPosition.z", "field of view" };
	private Type[] types = new[] { typeof(Transform), typeof(Transform), typeof(Transform), typeof(Transform), typeof(Transform), typeof(Transform), typeof(Transform), typeof(Camera)};

	void WriteToData() {
		data.Add(Time.realtimeSinceStartup - startTime);
		data.Add(transform.localRotation.x);
		data.Add(transform.localRotation.y);
		data.Add(transform.localRotation.z);
		data.Add(transform.localRotation.w);
		data.Add(transform.localPosition.x);
		data.Add(transform.localPosition.y);
		data.Add(transform.localPosition.z);
		data.Add(Camera.main.fieldOfView);
	}

	void WriteRecordedFile() {
        AnimationClip animationClip = new AnimationClip();

        DateTime now = DateTime.Now;
        string timestamp = now.Year.ToString() + now.Month + now.Day + now.Hour + now.Minute + now.Second;

        // create key frames for all our components
		int curveCount = curveNames.Length;
		int propertyCount = curveCount + 1;
		int frameCount = data.Count / propertyCount;

		Keyframe[][] keyFrames = new Keyframe[curveCount][];
		for (int i = 0; i < curveCount; i++) {
            keyFrames[i] = new Keyframe[frameCount];
        }

		for (int i = 0; i < frameCount; i++) {
			for (int k = 0; k < curveCount; k++) {
				keyFrames[k][i] = new Keyframe(data[propertyCount*i], data[propertyCount*i+k+1]);
            }
        }

        // set the animation curves
		for (int i = 0; i < curveCount; i++) {
            AnimationCurve curve = new AnimationCurve(keyFrames[i]);
			animationClip.SetCurve("", types[i], curveNames[i], curve);
        }

        // make the anim file
        AssetDatabase.CreateAsset(animationClip, "Assets/" + gameObject.name + "_" + timestamp + ".anim");
    }
	#endregion

	#region Server Variables
	// tcp server port
	public int port = 8009;
	private Thread _thread;
	private TcpListener _tcpListener = null;
	private TcpClient _client = null;
	private NetworkStream _stream = null;
	// Buffer for reading data
	private byte[] bytes = new byte[256];

	//6 floats in this order
	//rotation data
//	private	float roll;
//	private float pitch;
//	private float yaw;
	//acceleration data
//	private float acceX;
//	private float acceY;
//	private float acceZ;
	private float[] fromAppData = new float[6];
	private Vector3 speed = new Vector3(0,0,0);

	//TODO add more

	void ServerRunning()
	{
		try{
			_tcpListener = new TcpListener(IPAddress.Any, port);
			_tcpListener.Start();
			Debug.Log("Server Start, listening on port: " + port);
			while (true)
			{
				// check if new connections are pending, if not, be nice and sleep 100ms
				if (!_tcpListener.Pending()){
					Thread.Sleep(100);
				}
				else {
					_client = _tcpListener.AcceptTcpClient();
					_stream = _client.GetStream();
					
					int length;
					int i = 0;
					// Loop to receive all the data sent by the client.
					while((length = _stream.Read(bytes, 0, bytes.Length))!=0)
					{
						int n = length/24;
						int startIndex = (n>0?n-1:0)*24;
						length = length - startIndex;
						int num = length/4;
						while(num != 0)
						{
							fromAppData[i] = System.BitConverter.ToSingle(bytes, startIndex);
							startIndex+=sizeof(float);
							++i;
							if(i == fromAppData.Length) i = 0;
							--num;
						}
					}
					_stream.Close();
					// Shutdown and end connection
					_client.Close();
				}
			}
		}
		catch(SocketException e)
		{
			Debug.LogException(e, this);
		}
		finally
		{
			stopListening();
		}
	}

	void stopListening() {
		if(_tcpListener!=null) _tcpListener.Stop();
		if(_client!=null) _client.Close();
		if(_stream!=null) _stream.Close();
		Debug.Log("Tcp listener stopped.");
	}

	#endregion

	#region Main
	void Start() {
		data.Clear();
		ThreadStart ts = new ThreadStart(ServerRunning);
		_thread = new Thread(ts);
		_thread.Start();
		Debug.Log("Thread begin.");
	}
	
	void OnApplicationQuit() {
		if (recording) {
			WriteRecordedFile();
		}
		stopListening();
		// wait fpr listening thread to terminate
		if(_thread != null) _thread.Join();
		Debug.Log("Thead end.");
	}

	private AnimationCurve _curveSpeedX = new AnimationCurve();
	private AnimationCurve _curveSpeedY = new AnimationCurve();
	private AnimationCurve _curveSpeedZ = new AnimationCurve();
	
	void OnGUI() {
		if (recording) {
			if (GUI.Button(new Rect(20, 20, 200, 40), "STOP")) {
				recording = false;
				WriteRecordedFile();
			}
		} else {
			if (GUI.Button(new Rect(20, 20, 200, 40), "START RECORDING")) {
				recording = true;
				startTime = Time.realtimeSinceStartup;
			}
		}

		EditorGUI.CurveField(new Rect(20, 70, 200, 20), "Speed X", _curveSpeedX);
		EditorGUI.CurveField(new Rect(20, 90, 200, 20), "Speed Y", _curveSpeedY);
		EditorGUI.CurveField(new Rect(20, 110, 200, 20), "Speed Z", _curveSpeedZ);
	}

	void Update() {
		if(_stream!=null)
		{
			transform.Translate(speed * Time.deltaTime * moveSpeed);
			//update the speed
			speed.x = fromAppData[3];
			speed.y = fromAppData[4];
			speed.z = fromAppData[5];
//			_curveSpeedX.AddKey(new Keyframe(Time.time, speed.x));
//			_curveSpeedY.AddKey(new Keyframe(Time.time, speed.y));
//			_curveSpeedZ.AddKey(new Keyframe(Time.time, speed.z));
			Debug.Log("x, y, z:" + speed.x+", " + speed.y+", " + speed.z);

			transform.localRotation = Quaternion.Lerp(transform.localRotation, Quaternion.Euler(new Vector3(fromAppData[0], fromAppData[1], fromAppData[2])), rotationSensitivity*0.5f);
			if (recording) {
				WriteToData();
			}
		}
	}
	#endregion
}