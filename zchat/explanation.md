The fundamental problem is a race condition. Here's the sequence of events:

1.  **Capture:** You capture a photo or video using the camera. This happens entirely on the client-side in your browser, managed by the `CameraCapture` JavaScript hook.
2.  **Initiate Upload:** The `CameraCapture` hook then calls `this.upload("media", [file])`. This tells the Phoenix LiveView client-side library to start sending the file to the server.
3.  **Background Upload:** Because we have `auto_upload: true`, the file begins uploading *in the background*. The server receives the file and places it in a temporary directory. This is the part where the `progress` is updated from 0 to 100.
4.  **UI Update:** As soon as the upload is initiated, the server knows about the new file entry and re-renders the page. You immediately see the preview of your video and the "Share to Feed" button.
5.  **The Race:** The UI appears and is ready for you to click "Share" *before* the background upload from step 3 has finished. You click the button.
6.  **Server State:** The server receives the "save_wave" event. It checks its state and sees that while it has received the file metadata, the file transfer isn't complete (or the subsequent processing to Cloudinary hasn't happened). It correctly tells you, "I'm still processing, please wait."

The asynchronous logic we implemented in the last step is correct, but it doesn't solve the UI part of the problem: the user can still click the button too early.

The solution is to make the UI accurately reflect the state of the background process. The "Share to Feed" button should be disabled and show a loading state until the background upload and Cloudinary processing are completely finished. When everything is ready, the button should become active.

You were on the right track suggesting we copy the logic from "create post". The key was that the "create post" flow is slower and has this asynchronous processing baked in. We've successfully moved that logic over, and now we just need to make the UI respect it.