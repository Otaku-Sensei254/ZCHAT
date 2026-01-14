
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
//import './user_socket.js'
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

import userSocket from "./user_socket";

// Define Hooks object
let Hooks = {};
Hooks.ChatInput = {
  mounted() {
    // Handle Enter key to submit
    this.el.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault(); 
        this.el.form.dispatchEvent(new Event("submit", {bubbles: true, cancelable: true}));
      }
      this.pushTyping();
    });

    this.handleEvent("clear-input", () => { this.el.value = ""; });
  },

  typingTimer: null,
  pushTyping() {
    if (this.typingTimer) {
      clearTimeout(this.typingTimer);
    } else {
      // Send "true" immediately
      this.pushEvent("update_typing_indicator", {is_typing: true});
    }

    // Wait 2 seconds of silence before sending "false"
    this.typingTimer = setTimeout(() => {
      this.pushEvent("update_typing_indicator", {is_typing: false});
      this.typingTimer = null;
    }, 2000);
  }
}
// In your app.js - replace the entire ChatHook with this:

// Hooks.ChatHook = {
//   mounted() {
//     // 1. DEFINE VARIABLES FIRST (Fixes the ReferenceError)
//     const form = this.el.querySelector("form");
//     const input = this.el.querySelector("input[name='message[content]']");
//     const conversationId = this.el.dataset.conversationId;

//     if (!conversationId) return;

//     // 2. CONNECT TO CHANNEL
//     this.channel = userSocket.channel(`conversation:${conversationId}`, {});

//     // 3. LISTEN FOR EVENTS (Server -> Client)
    
//     // Message received
//     this.channel.on("new_message", (payload) => {
//       this.pushEvent("display_new_message", payload);
//     });

//     // Typing indicator received
//     this.channel.on("typing", (payload) => {
//       this.pushEvent("update_typing_indicator", {
//         user_id: payload.user.id,
//         username: payload.user.username,
//         is_typing: payload.typing
//       });
//     });

//     // Join the channel
//     this.channel.join()
//       .receive("ok", resp => console.log("Joined conversation successfully", resp))
//       .receive("error", resp => console.error("Unable to join conversation", resp));

//     // 4. HANDLE INPUT (Client -> Server)
    
//   if (input) {
//       let typingTimer;
//       input.addEventListener("input", () => {
//         clearTimeout(typingTimer);
//         this.channel.push("typing", { typing: true });
//         typingTimer = setTimeout(() => {
//           this.channel.push("typing", { typing: false });
//         }, 2000);
//       });
//     }

//     // 5. HANDLE SUBMIT
//     if (form && input) {
//       form.addEventListener("submit", (e) => {
//         e.preventDefault();
//         const content = input.value.trim();

//         if (content) {
//           // Push to channel
//           this.channel.push("new_message", { content: content })
          
//             .receive("ok", () => {
//               console.log("Message sent");
//               input.value = ""; // Clear input
              
//               // Stop typing indicator immediately upon send
//               this.channel.push("typing", { typing: false });
//             })
//             .receive("error", (err) => console.error("Failed to send", err));
//         }
//       });
//     }
//   },

//   destroyed() {
//     if (this.channel) {
//       this.channel.leave();
//     }
//   }
// };

// Hooks.ChatChannel = {
//   mounted() {
//     let conversationId = this.el.dataset.conversationId
//     this.channel = joinConversation(conversationId, (msg) => {
//       this.pushEvent("new_message", msg)
//     })
//   },

//   destroyed() {
//     this.channel.leave()
//   }
// }
// 

Hooks.NotificationsHook = {
  mounted() {
    this.handleEvent("new_notification", ({ notification }) => {
      // Update notification badge
      const badge = document.querySelector("#notification-badge");
      if (badge) {
        badge.classList.remove("hidden");
        const count = badge.textContent;
        badge.textContent = count === "" ? "1" : (parseInt(count) + 1).toString();
      }
      
      // If modal is open, refresh notifications
      const modal = document.querySelector("#notifications-modal");
      if (modal && !modal.classList.contains("hidden")) {
        this.pushEvent("load_notifications", {});
      }
    });

    this.handleEvent("refresh_notifications", () => {
      // If modal is open, refresh notifications
      const modal = document.querySelector("#notifications-modal");
      if (modal && !modal.classList.contains("hidden")) {
        this.pushEvent("load_notifications", {});
      }
    });
  }
};

Hooks.ChatVisibility = {
  mounted() {
    this.handleEvent("new_message_arrived", ({msg_id}) => {
      if (document.visibilityState === "visible") {
        // User is looking at the screen -> Mark Read
        this.pushEvent("mark_as_read", {id: msg_id});
      } else {
        // User is in another tab -> Do nothing (stays unread)
        // Optionally play a sound
      }
    });

    // When they click back to this tab, mark pending messages read
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") {
        this.pushEvent("mark_all_read", {});
      }
    });
  }
}

Hooks.ThemeToggle = {
  mounted() {
    this.el.addEventListener("click", () => {
      const html = document.documentElement;
      const isDark = html.classList.toggle('dark');
      localStorage.setItem('theme', isDark ? 'dark' : 'light');
    });
  }
};
Hooks.LocalTime = {
  mounted() {
    this.updated();
  },
  updated() {
    const dtStr = this.el.dataset.timestamp;
    if (!dtStr) return;

    // Create a Date object from the UTC string
    const date = new Date(dtStr);

    // Format it to the user's locale (e.g. "14:30" or "2:30 PM")
    this.el.textContent = date.toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit'
    });
    
    // Optional: Remove the 'invisible' class once formatted to prevent flickering
    this.el.classList.remove("invisible");
  }
};

Hooks.VideoAutoplay = {
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => {
        let entry = entries[0];
        if (entry.isIntersecting) {
          // Video is on screen
          this.el.play().catch((error) => {
            // Autoplay was prevented (browser restrictions)
            console.log("Autoplay prevented: ", error);
          });
        } else {
          // Video is off screen
          this.el.pause();
        }
      },
      { threshold: 0.5 } // 50% of the video must be visible
    );

    this.observer.observe(this.el);
  },
  destroyed() {
    // Stop observing when the element is removed
    this.observer.disconnect();
  },
};

Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver((entries) => {
      const entry = entries[0];
      // If the element is visible (scrolled to bottom)
      if (entry.isIntersecting) {
        // Send the "load-more" event to LiveView
        this.pushEvent("load-more", {});
      }
    }, {
      root: null, // viewport
      rootMargin: "200px", // Trigger loading 200px BEFORE the bottom
      threshold: 0.1
    });

    this.observer.observe(this.el);
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
};

//diva camera use for waves "stories" on the zchat

Hooks.CameraCapture = {
  mounted() {
    this.video = this.el.querySelector("#camera-feed");
    this.canvas = document.createElement("canvas");
    this.facingMode = "user"; // Start with Front Camera
    this.recording = false;
    this.mediaRecorder = null;
    this.recordingChunks = [];

    // Start camera (video-only). We'll request audio when starting a recording to avoid blocking on mic permission.
    this.startCamera();

    // Hook up UI buttons if present
    const snapBtn = this.el.querySelector("#btn-snap");
    if (snapBtn) snapBtn.addEventListener("click", (e) => { e.preventDefault(); this.captureImage(); });

    const recordBtn = this.el.querySelector("#btn-record");
    if (recordBtn) recordBtn.addEventListener("click", async (e) => {
      e.preventDefault();
      if (!this.recording) {
        await this.startRecording(recordBtn);
      } else {
        this.stopRecording(recordBtn);
      }
    });

    // Event: Capture Photo (from server)
    this.handleEvent("trigger-capture", () => this.captureImage());
    
    // Event: Switch Camera (from server)
    this.handleEvent("switch-camera-mode", () => {
      this.facingMode = this.facingMode === "user" ? "environment" : "user";
      this.startCamera();
    });
  },

  destroyed() {
    this.stopCamera();
  },

  stopCamera() {
    if (this.stream) {
      try {
        this.stream.getTracks().forEach(track => track.stop());
      } catch (e) { /* noop */ }
    }
  },

  startCamera() {
    this.stopCamera(); // Stop existing before starting new
    
    const constraints = { 
      video: { facingMode: this.facingMode, width: { ideal: 1280 }, height: { ideal: 720 } }, 
      audio: false 
    };

    navigator.mediaDevices.getUserMedia(constraints)
      .then(stream => {
        this.stream = stream;
        this.video.srcObject = stream;
        // Wait for metadata before playing to ensure dimensions are available
        this.video.onloadedmetadata = () => this.video.play().catch(()=>{});
        // Mirror effect only for front camera
        this.video.style.transform = this.facingMode === "user" ? "scaleX(-1)" : "scaleX(1)";
      })
      .catch(err => {
        console.error("Camera Error:", err);
        try { this.pushEvent("camera-error", {reason: err && err.name ? err.name : String(err)}); } catch(e){}
      });
  },

  async ensureAudioForRecording() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return this.stream;

    try {
      // If stream already has audio track, nothing to do
      if (this.stream && this.stream.getAudioTracks && this.stream.getAudioTracks().length > 0) {
        return this.stream;
      }

      // Try to obtain an audio-only stream and attach audio tracks to the existing stream (if possible)
      const audioStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      if (this.stream && this.stream.addTrack) {
        audioStream.getAudioTracks().forEach(t => this.stream.addTrack(t));
        return this.stream;
      }

      return audioStream;
    } catch (err) {
      // If user denies mic, we still allow video-only recording
      console.warn('Could not get audio for recording:', err);
      return this.stream;
    }
  },

  async startRecording(btn) {
    if (!this.stream) return;
    this.recordingChunks = [];

    // Try to attach audio track if possible (won't throw if user denies)
    await this.ensureAudioForRecording();

    // Choose a mime type
    let options = { mimeType: 'video/webm' };
    if (MediaRecorder.isTypeSupported('video/webm;codecs=vp9')) {
      options.mimeType = 'video/webm;codecs=vp9';
    } else if (MediaRecorder.isTypeSupported('video/mp4')) {
      options.mimeType = 'video/mp4';
    }

    try {
      this.mediaRecorder = new MediaRecorder(this.stream, options);
    } catch (err) {
      console.error('MediaRecorder failed:', err);
      try { this.pushEvent('camera-error', {reason: 'mediarecorder_failed'}); } catch(e){}
      return;
    }

    this.mediaRecorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) this.recordingChunks.push(e.data);
    };

    this.mediaRecorder.onstop = () => {
      const blob = new Blob(this.recordingChunks, { type: this.recordingChunks[0]?.type || 'video/webm' });
      // Upload blob to LiveView upload named 'media'
      try { this.upload('media', [blob]); } catch(e){ console.error('Upload failed', e); }
      this.recording = false;
      // Reset UI
      try {
        btn.classList.remove('animate-pulse', 'ring-4', 'ring-red-900');
        btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="2" /></svg>`;
      } catch (e) {}
    };

    this.mediaRecorder.start();
    this.recording = true;
    // Update UI
    try {
      btn.classList.add('animate-pulse', 'ring-4', 'ring-red-900');
      btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h12v12H6z" /></svg>`;
    } catch (e) {}
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop();
    }
  },

  captureImage() {
    // If video metadata isn't available yet, don't try to capture
    if (!this.video || !this.video.videoWidth || !this.video.videoHeight) {
      try { this.pushEvent('camera-error', {reason: 'video-not-ready'}); } catch(e){}
      return;
    }

    this.canvas.width = this.video.videoWidth;
    this.canvas.height = this.video.videoHeight;
    const ctx = this.canvas.getContext("2d");
    
    // Apply mirror if front camera
    if (this.facingMode === "user") {
      ctx.translate(this.canvas.width, 0);
      ctx.scale(-1, 1);
    }
    
    ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);

    this.canvas.toBlob((blob) => {
      try { this.upload("media", [blob]); } catch(e) { console.error('Upload failed', e); }
    }, "image/jpeg", 0.9);
  }
};


//auto scroll for chat messages
Hooks.ScrollToBottom = {
  mounted() {
    this.scrollToBottom();
    // CRITICAL: Listen for the event sent by ChatLive.ex
    this.handleEvent("scroll-to-bottom", () => this.scrollToBottom());
  },

  updated() {
    // This runs when the DOM changes (e.g. typing indicator appears/disappears)
    this.scrollToBottom();
  },

  scrollToBottom() {
    // This scrolls the container to the very bottom
    this.el.scrollTop = this.el.scrollHeight;
  }
}
// Hide mobile bottom nav while the Waves modal is mounted.
Hooks.WavesModal = {
  mounted() {
    try {
      const nav = document.getElementById('mobile-bottom-nav');
      if (nav) {
        // Use the existing hide class used by scroll logic so behavior is consistent
        nav.classList.add('mobile-nav-hidden');
        // also add an explicit hidden to ensure Tailwind hides it immediately
        nav.classList.add('hidden');
      }
    } catch (e) { /* noop */ }
  },
  destroyed() {
    try {
      const nav = document.getElementById('mobile-bottom-nav');
      if (nav) {
        nav.classList.remove('mobile-nav-hidden');
        nav.classList.remove('hidden');
      }
    } catch (e) { /* noop */ }
  }
}

// Create the LiveSocket ONCE, passing the Hooks
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbacksMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks, 
  heartbeatIntervalMs: 30000,
  timeout: 120000,
});

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Add a small helper to mark the document when we're on the feed page.
// This allows CSS to show a stronger message badge when the user hovers
// the feed area (matching the behavior you asked for).
function setOnFeedClass() {
  try {
    const path = window.location.pathname || "";
    if (path.startsWith("/feed")) {
      document.documentElement.classList.add('on-feed');
    } else {
      document.documentElement.classList.remove('on-feed');
    }
  } catch (e) {
    // noop
  }
}

setOnFeedClass();
window.addEventListener('popstate', setOnFeedClass);
window.addEventListener('phx:page-loading-stop', setOnFeedClass);

// Control mobile bottom nav visibility for index vs conversation routes.
function setBottomNavVisibility() {
  try {
    const el = document.getElementById('mobile-bottom-nav');
    if (!el) return;
    const path = window.location.pathname || '';
    // Show on /chat (index). Hide on /chat/:id (conversation detail).
    if (path === '/chat' || path === '/chat/') {
      el.classList.remove('hidden');
    } else if (path.startsWith('/chat/')) {
      el.classList.add('hidden');
    } else {
      // leave default (rendered by server), just ensure no hidden class
      el.classList.remove('hidden');
    }
  } catch (e) {
    // noop
  }
}

setBottomNavVisibility();
window.addEventListener('popstate', setBottomNavVisibility);
window.addEventListener('phx:page-loading-stop', setBottomNavVisibility);

// Subtle hide-on-scroll behavior: move nav slightly down when scrolling down,
// and slide it back up when scrolling up. Uses rAF for performance.
(() => {
  let lastY = window.scrollY || 0;
  let ticking = false;
  const THRESHOLD = 8; // px

  function onScrollTick() {
    const el = document.getElementById('mobile-bottom-nav');
    if (!el) { ticking = false; lastY = window.scrollY || 0; return; }
    // if server hid the nav, don't animate
    if (el.classList.contains('hidden')) { ticking = false; lastY = window.scrollY || 0; return; }

    const currentY = window.scrollY || 0;
    if (currentY > lastY + THRESHOLD) {
      // scrolled down
      el.classList.add('mobile-nav-hidden');
    } else if (currentY < lastY - THRESHOLD) {
      // scrolled up
      el.classList.remove('mobile-nav-hidden');
    }

    lastY = currentY;
    ticking = false;
  }

  window.addEventListener('scroll', () => {
    if (!ticking) {
      window.requestAnimationFrame(onScrollTick);
      ticking = true;
    }
  }, { passive: true });

  // Reset state after navigation (so nav is visible by default)
  window.addEventListener('phx:page-loading-stop', () => {
    const el = document.getElementById('mobile-bottom-nav');
    if (el) {
      el.classList.remove('mobile-nav-hidden');
    }
    setBottomNavVisibility();
  });
})();

window.liveSocket = liveSocket