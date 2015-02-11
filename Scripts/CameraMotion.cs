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
	//    public float moveSpeed;
	#region Animation Clip Record
	public float rotationSensitivity = 0.5f;
	public float MoveSensitivity = 2f;
	private bool recording;
    private float startTime;
	private List<float> data = new List<float>();
	private string[] curveNames = new[] { "localRotation.x", "localRotation.y", "localRotation.z", "localRotation.w", "localPosition.x", "localPosition.y", "localPosition.z" };

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
			animationClip.SetCurve("", typeof(Transform), curveNames[i], curve);
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
	private Vector3 speed = new Vector3();

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
					// Loop to receive all the data sent by the client.
					while((length = _stream.Read(bytes, 0, bytes.Length))!=0)
					{
						ParseFrom(bytes, 0, length);
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

	int ParseFrom(byte[] data, int startIndex, int length){
		if( fromAppData.Length * sizeof(float) > length) return 0;
		for(int i = 0; i < fromAppData.Length; ++i)
		{
			fromAppData[i] = System.BitConverter.ToSingle(data, startIndex);
			startIndex+=sizeof(float);
		}
		return startIndex;
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
	}
	
	void Update() {

		transform.Translate(speed * Time.deltaTime * MoveSensitivity);
		//update the speed
		speed.x += (fromAppData[3]*Time.deltaTime);
		speed.y += (fromAppData[4]*Time.deltaTime);
		speed.z += (fromAppData[5]*Time.deltaTime);

		transform.localRotation = Quaternion.Lerp(transform.localRotation, Quaternion.Euler(fromAppData[0] * 360f, fromAppData[1] * 360f, fromAppData[2] * 360f), rotationSensitivity);
		
		if (recording) {
			data.Add(Time.realtimeSinceStartup - startTime);
			data.Add(transform.localRotation.x);
			data.Add(transform.localRotation.y);
			data.Add(transform.localRotation.z);
			data.Add(transform.localRotation.w);
			data.Add(transform.localPosition.x);
			data.Add(transform.localPosition.y);
			data.Add(transform.localPosition.z);
		}
	}
	#endregion
}