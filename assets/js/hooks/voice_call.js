
const VoiceCall = {
  mounted() {
    console.log("VoiceCall Hook Mounted");
    this.peerConnection = null;
    this.localStream = null;
    this.durationInterval = null;
    this.startTime = null;
    this.pendingSignals = [];
    this.wakeLock = null;

    // Ringtone elements
    this.outgoingRingtone = document.getElementById("outgoing-ringtone");
    this.incomingRingtone = document.getElementById("incoming-ringtone");

    // Listen for events from LiveView
    this.handleEvent("incoming_call", (payload) => this.onIncomingCall(payload));
    this.handleEvent("webrtc_signal", (payload) => this.onWebRTCSignal(payload));
    this.handleEvent("init_peer_connection", ({ is_initiator }) => {
      console.log("Initializing Peer Connection. Initiator:", is_initiator);
      this.stopRingtones();
      this.startPeerConnection(is_initiator);
      this.startTimer();
      this.acquireWakeLock();
    });
    this.handleEvent("call_accepted", () => {
        // This is a backup for the initiator who doesn't get init_peer_connection via event but via handle_info
        // Actually our current LiveView sends init_peer_connection to both, so this might be redundant but safe.
    });
    this.handleEvent("call_ended", () => {
      console.log("Call Ended Event Received");
      this.endCall();
    });

    // Re-acquire wake lock if page becomes visible again
    this._onVisibilityChange = () => {
      if (this.wakeLock !== null && document.visibilityState === 'visible') {
        this.acquireWakeLock();
      }
    };
    document.addEventListener('visibilitychange', this._onVisibilityChange);

    // Check initial state for ringtones
    this.checkRingtones();
  },

  async acquireWakeLock() {
    if ('wakeLock' in navigator) {
      try {
        this.wakeLock = await navigator.wakeLock.request('screen');
        console.log("Screen Wake Lock acquired!");
        this.wakeLock.addEventListener('release', () => {
          console.log('Screen Wake Lock released');
        });
      } catch (err) {
        console.error(`Wake Lock Error: ${err.name}, ${err.message}`);
      }
    }
  },

  releaseWakeLock() {
    if (this.wakeLock) {
      this.wakeLock.release().then(() => {
        this.wakeLock = null;
      });
    }
  },

  updated() {
    this.checkRingtones();
  },

  destroyed() {
    console.log("VoiceCall Hook Destroyed");
    document.removeEventListener('visibilitychange', this._onVisibilityChange);
    this.endCall();
  },

  checkRingtones() {
    const overlay = this.el;
    if (overlay) {
      const statusText = overlay.innerText;
      if (statusText.includes("Calling...") && !this.isRingtonePlaying("outgoing")) {
        this.playRingtone("outgoing");
      } else if (statusText.includes("Incoming Call...") && !this.isRingtonePlaying("incoming")) {
        this.playRingtone("incoming");
      }
    }
  },

  playRingtone(type) {
    this.stopRingtones();
    if (type === "outgoing" && this.outgoingRingtone) {
      this.outgoingRingtone.play().catch(e => console.log("Outgoing ringtone blocked", e));
    } else if (type === "incoming" && this.incomingRingtone) {
      this.incomingRingtone.play().catch(e => console.log("Incoming ringtone blocked", e));
    }
  },

  isRingtonePlaying(type) {
    const ringtone = type === "outgoing" ? this.outgoingRingtone : this.incomingRingtone;
    return ringtone && !ringtone.paused;
  },

  stopRingtones() {
    if (this.outgoingRingtone) {
      this.outgoingRingtone.pause();
      this.outgoingRingtone.currentTime = 0;
    }
    if (this.incomingRingtone) {
      this.incomingRingtone.pause();
      this.incomingRingtone.currentTime = 0;
    }
  },

  startTimer() {
    if (this.durationInterval) return;
    console.log("Starting Call Timer");
    this.startTime = Date.now();
    this.durationInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.startTime) / 1000);
      const minutes = Math.floor(elapsed / 60).toString().padStart(2, "0");
      const seconds = (elapsed % 60).toString().padStart(2, "0");
      const timerEl = document.getElementById("call-duration");
      if (timerEl) {
        timerEl.innerText = `${minutes}:${seconds}`;
      }
    }, 1000);
  },

  async onIncomingCall(payload) {
    console.log("Incoming call from:", payload.from_username);
    this.playRingtone("incoming");
  },

  async onWebRTCSignal({ from_user_id, signal }) {
    console.log("Received WebRTC Signal Type:", signal.type);
    if (!this.peerConnection) {
      console.log("Queuing signal as peerConnection is not ready.");
      this.pendingSignals.push(signal);
      return;
    }
    await this.processSignal(signal);
  },

  async processSignal(signal) {
    try {
      if (signal.type === "offer") {
        await this.peerConnection.setRemoteDescription(new RTCSessionDescription(signal.sdp));
        const answer = await this.peerConnection.createAnswer();
        await this.peerConnection.setLocalDescription(answer);
        this.pushEvent("signal", { type: "answer", sdp: answer });
      } else if (signal.type === "answer") {
        await this.peerConnection.setRemoteDescription(new RTCSessionDescription(signal.sdp));
      } else if (signal.type === "ice-candidate") {
        if (signal.candidate) {
          await this.peerConnection.addIceCandidate(new RTCIceCandidate(signal.candidate));
        }
      }
    } catch (err) {
      console.error("Error processing signal:", err, signal);
    }
  },

  async startPeerConnection(isInitiator) {
    if (this.peerConnection) {
      console.log("Closing existing peer connection before restart.");
      this.endCall();
    }

    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      
      this.peerConnection = new RTCPeerConnection({
        iceServers: [
          { urls: "stun:stun.l.google.com:19302" },
          { urls: "stun:stun1.l.google.com:19302" }
        ]
      });

      this.peerConnection.onconnectionstatechange = () => {
        console.log("Connection State Changed:", this.peerConnection.connectionState);
      };

      this.localStream.getTracks().forEach(track => {
        this.peerConnection.addTrack(track, this.localStream);
      });

      this.peerConnection.onicecandidate = ({ candidate }) => {
        if (candidate) {
          this.pushEvent("signal", { type: "ice-candidate", candidate });
        }
      };

      this.peerConnection.ontrack = (event) => {
        console.log(">>> SUCCESS: Received remote track!");
        let remoteAudio = document.getElementById("remote-audio-element");
        if (!remoteAudio) {
          remoteAudio = document.createElement("audio");
          remoteAudio.id = "remote-audio-element";
          remoteAudio.autoplay = true;
          document.body.appendChild(remoteAudio);
        }
        remoteAudio.srcObject = event.streams[0] || new MediaStream([event.track]);
        remoteAudio.play().catch(e => console.error("Remote audio play failed", e));
      };

      // Process any queued signals
      while (this.pendingSignals.length > 0) {
        const sig = this.pendingSignals.shift();
        await this.processSignal(sig);
      }

      if (isInitiator) {
        console.log("Creating offer...");
        const offer = await this.peerConnection.createOffer();
        await this.peerConnection.setLocalDescription(offer);
        this.pushEvent("signal", { type: "offer", sdp: offer });
      }

    } catch (err) {
      console.error("Peer connection initialization failed", err);
      this.pushEvent("call_error", { reason: "Device busy or access denied" });
    }
  },

  endCall() {
    console.log("Ending call and purging resources.");
    this.releaseWakeLock();
    this.stopRingtones();
    if (this.durationInterval) clearInterval(this.durationInterval);
    this.durationInterval = null;

    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
      this.localStream = null;
    }
    if (this.peerConnection) {
      this.peerConnection.close();
      this.peerConnection = null;
    }
    const remoteAudio = document.getElementById("remote-audio-element");
    if (remoteAudio) {
      remoteAudio.srcObject = null;
      remoteAudio.remove();
    }
    this.pendingSignals = [];
  }
};

export default VoiceCall;
