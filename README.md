# CamMotion
Use iPhone to control the `transform` of the Camera in Unity3D via TCP, as well as the `fieldOfView` when pinching on the screen.

You can record your own animation clip file, to record the motion track of the camera, generating an .anim file in the asset for reusing it later.

##Usage
1. Open `CameraControllerClient` and install the iOS app in your iPhone.
2. Open unity3d project and add the `Scripts` folder to the asset. Attach the `CameraMotion.cs` to main camera as a component.
3. Set proper port num in the filed than click `Play` in unity3d. It will start up a TCP server.
4. Start your app and input your pc's local IP and Port num, click `connect` button. Enjoy it!
