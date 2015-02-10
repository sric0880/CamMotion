using UnityEngine;
using UnityEditor;
using System.Collections;
using System.Threading;
using System.Net;
using System.Net.Sockets;
using System.IO;

public class MainWindow : EditorWindow {

	[MenuItem("Window/Camera Motion Capture")]
	static void Init () {
		EditorWindow.GetWindow (typeof (MainWindow));
	}

	private int _port = 8009;

	// Buffer for reading data
	byte[] bytes = new byte[256];

	private Thread _thread;
	private TcpListener _tcpListener = null;
	private TcpClient _client = null;
	private NetworkStream _stream = null;
	
	public void stopListening() {
		if(_tcpListener!=null) _tcpListener.Stop();
		if(_client!=null) _client.Close();
		if(_stream!=null) _stream.Close();
		Debug.Log("Tcp listener stopped.");
	}

	void OnEnable()
	{
		this.title = "Camera Capture";
		this.minSize = new Vector2(400f,280f);
		ThreadStart ts = new ThreadStart(TCPServer);
		_thread = new Thread(ts);
		_thread.Start();
		Debug.Log("Thread begin.");
	}

	void OnDestroy()
	{
		stopListening();
		// wait fpr listening thread to terminate
		_thread.Join();
		Debug.Log("Thead end.");
	}

	void OnGUI()
	{

	}

	void TCPServer()
	{
		try{
			_tcpListener = new TcpListener(IPAddress.Any, _port);
			_tcpListener.Start();
			Debug.Log("Server Start, listening on port: " + _port);
			while (true)
			{
				// check if new connections are pending, if not, be nice and sleep 100ms
				if (!_tcpListener.Pending()){
					Thread.Sleep(100);
				}
				else {
					_client = _tcpListener.AcceptTcpClient();
					_stream = _client.GetStream();

					int i;
					// Loop to receive all the data sent by the client.
					while((i = _stream.Read(bytes, 0, bytes.Length))!=0)
					{
						string data = System.Text.Encoding.ASCII.GetString(bytes, 0, i);
						Debug.Log("Received:" + data);
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
}
