
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

// 1. Add this NEW Hook for playing back the video immediately
Hooks.LocalVideoPreview = {
  mounted() {
    // Check if we just recorded something
    if (window.recordedVideoBlobURL) {
      this.el.src = window.recordedVideoBlobURL;
    } 
    // Otherwise, check if it was uploaded from gallery
    else {
      const input = document.getElementById("gallery-input");
      if (input && input.files && input.files[0]) {
        this.el.src = URL.createObjectURL(input.files[0]);
      }
    }
    // Mute the video's own audio if a music preview is present
    try { this.el.muted = !!window.musicSelected; } catch(e){}
    // Observe DOM to toggle mute when music preview is added/removed
    try {
      const toggleMute = () => { try { this.el.muted = !!document.getElementById('music-preview-player'); } catch(e){} };
      this.__musicObserver = new MutationObserver(() => toggleMute());
      this.__musicObserver.observe(document.body, { childList: true, subtree: true });
    } catch(e) {}
  }
  ,
  destroyed() {
    try { if (this.__musicObserver) this.__musicObserver.disconnect(); } catch(e){}
  }
};

// Hook used by the Waves LiveView video preview element
Hooks.VideoPreview = {
  mounted() {
    try {
      // If we just recorded a video, use that blob URL
      if (window.recordedVideoBlobURL) {
        this.el.src = window.recordedVideoBlobURL;
      } else {
        // Fallback: if user picked from gallery input
        const input = document.getElementById("gallery-input");
        if (input && input.files && input.files[0]) {
          this.el.src = URL.createObjectURL(input.files[0]);
        }
      }
      // Mute the video's own audio if a music preview is present
      try { this.el.muted = !!window.musicSelected; } catch(e){}

      // Observe DOM so we can toggle muting when the music preview is added/removed
      const toggleMute = () => { try { this.el.muted = !!document.getElementById('music-preview-player'); } catch(e){} };
      this.__musicObserver = new MutationObserver(() => toggleMute());
      this.__musicObserver.observe(document.body, { childList: true, subtree: true });

      // Try to play (user gesture from button may allow autoplay)
      this.el.play().catch(() => {});
    } catch (e) { /* noop */ }
  }
  ,
  destroyed() {
    try {
      if (this.__musicObserver) this.__musicObserver.disconnect();
    } catch(e){}
  }
};

// Hook used by the Waves LiveView image preview element
Hooks.ImagePreview = {
  mounted() {
    try {
      // If we just snapped a photo, show that immediately
      if (window.lastCapturedPhotoURL) {
        this.el.src = window.lastCapturedPhotoURL;
      } else {
        // Fallback to gallery input
        const input = document.getElementById("gallery-input");
        if (input && input.files && input.files[0]) {
          this.el.src = URL.createObjectURL(input.files[0]);
        }
      }
    } catch (e) { /* noop */ }
  },
  destroyed() {
    // Revoke the temp URL when the image element is removed to free memory
    try {
      if (window.lastCapturedPhotoURL) {
        URL.revokeObjectURL(window.lastCapturedPhotoURL);
        window.lastCapturedPhotoURL = null;
      }
    } catch (e) { /* noop */ }
  }
};

// 2. Updated CameraCapture Hook
Hooks.CameraCapture = {
  mounted() {
    this.video = this.el.querySelector("#camera-feed");
    this.canvas = document.createElement("canvas");
    this.timerEl = this.el.querySelector("#recording-timer");
    this.facingMode = "user"; 
    this.recording = false;
    this.mediaRecorder = null;
    this.recordingChunks = [];
    this.timerInterval = null;
    this.secondsRecorded = 0;
    this.videoReady = false;

    this.startCamera();

    // -- BUTTON HANDLERS --
    const snapBtn = this.el.querySelector("#btn-snap");
    if (snapBtn) {
      snapBtn.addEventListener("click", (e) => { 
        e.preventDefault(); 
        if (!this.videoReady) {
          // Attempt to unlock audio/video if browser blocked autoplay
          this.video.play().then(() => {
            this.videoReady = true;
            this.captureImage();
          }).catch((err) => console.warn("Waiting for stream...", err));
          return;
        }
        this.captureImage(); 
      });
    }

    const recordBtn = this.el.querySelector("#btn-record");
    if (recordBtn) {
      recordBtn.addEventListener("click", async (e) => {
        e.preventDefault();
        if (!this.videoReady) {
          this.video.play().then(async () => {
            this.videoReady = true;
            if (!this.recording) await this.startRecording(recordBtn);
            else this.stopRecording(recordBtn);
          }).catch((err) => console.warn("Waiting for stream...", err));
          return;
        }
        if (!this.recording) await this.startRecording(recordBtn);
        else this.stopRecording(recordBtn);
      });
    }

    // -- SERVER EVENTS --
    this.handleEvent("switch-camera-mode", () => {
      this.facingMode = this.facingMode === "user" ? "environment" : "user";
      this.startCamera();
    });
  },

  // Re-run when LiveView patches the DOM (e.g. after retake cancels upload)
  updated() {
    try {
      // Re-acquire the video element if it was replaced by a DOM patch
      const newVideo = this.el.querySelector("#camera-feed");
      if (newVideo && newVideo !== this.video) {
        this.video = newVideo;
        // Re-attach stream to the new video element
        if (this.stream) {
          try {
            this.video.srcObject = this.stream;
            this.video.play().catch(() => {});
          } catch (e) { /* noop */ }
        }
      }

      // Re-bind timer element
      this.timerEl = this.el.querySelector("#recording-timer");

      // Re-bind snap button listener if needed
      const snapBtn = this.el.querySelector("#btn-snap");
      if (snapBtn && snapBtn.dataset.listenerAttached !== "1") {
        snapBtn.addEventListener("click", (e) => {
          e.preventDefault();
          if (!this.videoReady) {
            this.video.play().then(() => {
              this.videoReady = true;
              this.captureImage();
            }).catch((err) => console.warn("Waiting for stream...", err));
            return;
          }
          this.captureImage();
        });
        snapBtn.dataset.listenerAttached = "1";
      }

      // Re-bind record button listener if needed
      const recordBtn = this.el.querySelector("#btn-record");
      if (recordBtn && recordBtn.dataset.listenerAttached !== "1") {
        recordBtn.addEventListener("click", async (e) => {
          e.preventDefault();
          if (!this.videoReady) {
            this.video.play().then(async () => {
              this.videoReady = true;
              if (!this.recording) await this.startRecording(recordBtn);
              else this.stopRecording(recordBtn);
            }).catch((err) => console.warn("Waiting for stream...", err));
            return;
          }
          if (!this.recording) await this.startRecording(recordBtn);
          else this.stopRecording(recordBtn);
        });
        recordBtn.dataset.listenerAttached = "1";
      }
    } catch (e) { /* noop */ }
  },

  destroyed() {
    this.stopCamera();
    this.stopTimer();
  },

  // --- CAMERA LOGIC ---
  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
    }
  },

  startCamera() {
    this.stopCamera();
    
    const constraints = { 
      video: { facingMode: this.facingMode, width: { ideal: 1280 }, height: { ideal: 720 } }, 
      audio: false 
    };

    navigator.mediaDevices.getUserMedia(constraints)
      .then(stream => {
        this.stream = stream;
        this.videoReady = false;
        this.video.srcObject = stream;
        
        this.video.onloadedmetadata = () => {
          this.video.play().catch((err) => console.warn("Autoplay blocked", err));
        };

        const onPlaying = () => {
          this.videoReady = true;
          this.video.style.transform = this.facingMode === "user" ? "scaleX(-1)" : "scaleX(1)";
          this.video.removeEventListener('playing', onPlaying);
        };
        this.video.addEventListener('playing', onPlaying);
        // Fallback for some browsers
        this.video.addEventListener('canplay', () => this.videoReady = true);
      })
      .catch(err => console.error("Camera Error:", err));
  },

  // --- RECORDING LOGIC ---
  async ensureAudioForRecording() {
    try {
      const audioStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      if (this.stream) {
        audioStream.getAudioTracks().forEach(track => this.stream.addTrack(track));
      }
      return this.stream;
    } catch (err) {
      console.warn("Mic access denied", err);
      return this.stream; 
    }
  },

  async startRecording(btn) {
    if (!this.stream) return;
    this.recordingChunks = [];
    
    await this.ensureAudioForRecording();

    let options = { mimeType: 'video/webm' };
    if (MediaRecorder.isTypeSupported('video/mp4')) options.mimeType = 'video/mp4';

    try {
      this.mediaRecorder = new MediaRecorder(this.stream, options);
    } catch (err) {
      console.error("Recorder failed", err);
      return;
    }

    this.mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) this.recordingChunks.push(e.data);
    };

    this.mediaRecorder.onstop = () => {
      const blob = new Blob(this.recordingChunks, { type: this.recordingChunks[0]?.type || 'video/webm' });
      
      // *** CRITICAL UPDATE: Save Blob URL for the Preview Hook ***
      if (window.recordedVideoBlobURL) URL.revokeObjectURL(window.recordedVideoBlobURL);
      window.recordedVideoBlobURL = URL.createObjectURL(blob);
      // **********************************************************

      try {
        const mime = blob.type || 'video/webm';
        const ext = (mime.split('/').pop() || 'webm').split(';')[0];
        const filename = `recording_${Date.now()}.${ext}`;
        const file = new File([blob], filename, { type: mime });
        this.upload("media", [file]);
      } catch (err) {
        this.upload("media", [blob]);
      }
      
      this.recording = false;
      this.stopTimer();
      
      if (btn) {
        btn.classList.remove('animate-pulse', 'bg-red-700', 'scale-110');
        btn.innerHTML = `<div class="w-4 h-4 bg-white rounded-sm"></div>`;
      }
    };

    this.mediaRecorder.start();
    this.recording = true;
    this.startTimer();

    if (btn) {
      btn.classList.add('animate-pulse', 'bg-red-700', 'scale-110');
      btn.innerHTML = `<div class="w-3 h-3 bg-white rounded-sm"></div>`;
    }
  },

  stopRecording(btn) {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop();
    }
  },

  // --- PHOTO LOGIC ---
  captureImage() {
    if (!this.video || !this.video.videoWidth) return;

    this.canvas.width = this.video.videoWidth;
    this.canvas.height = this.video.videoHeight;
    const ctx = this.canvas.getContext("2d");

    if (this.facingMode === "user") {
      ctx.translate(this.canvas.width, 0);
      ctx.scale(-1, 1);
    }

    ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);

    this.canvas.toBlob((blob) => {
      const file = new File([blob], `photo_${Date.now()}.jpg`, { type: "image/jpeg" });

      // Expose a temporary object URL so the ImagePreview hook can show it immediately
      try {
        if (window.lastCapturedPhotoURL) URL.revokeObjectURL(window.lastCapturedPhotoURL);
      } catch (e) { /* noop */ }
      try {
        window.lastCapturedPhotoURL = URL.createObjectURL(file);
      } catch (e) {
        window.lastCapturedPhotoURL = null;
      }

      this.upload("media", [file]);
    }, "image/jpeg", 0.9);
  },

  startTimer() {
    this.secondsRecorded = 0;
    if (this.timerEl) {
      this.timerEl.classList.remove("hidden");
      this.timerEl.innerText = "00:00";
    }
    this.timerInterval = setInterval(() => {
      this.secondsRecorded++;
      const m = Math.floor(this.secondsRecorded / 60).toString().padStart(2, '0');
      const s = (this.secondsRecorded % 60).toString().padStart(2, '0');
      if (this.timerEl) this.timerEl.innerText = `${m}:${s}`;
    }, 1000);
  },

  stopTimer() {
    clearInterval(this.timerInterval);
    if (this.timerEl) this.timerEl.classList.add("hidden");
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
      // Also hide the top header so Waves is a full-bleed experience
      const header = document.querySelector('header');
      if (header) {
        header.classList.add('hidden');
        header.setAttribute('aria-hidden', 'true');
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
      const header = document.querySelector('header');
      if (header) {
        header.classList.remove('hidden');
        header.removeAttribute('aria-hidden');
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

// Attempt to autoplay music preview when the audio element is added to the DOM.
function tryPlayMusicPreview() {
  try {
    const audio = document.getElementById('music-preview-player');
    // Track whether music is present so previews can react
    window.musicSelected = !!audio;
    if (!audio) return;
    // If already playing, nothing to do
    if (!audio.paused) return;
    audio.play().then(() => {
      console.log('Music preview playing');
    }).catch((err) => {
      console.warn('Music preview autoplay blocked', err);
      // Reveal controls so user can start playback manually
      audio.controls = true;
      audio.classList.remove('hidden');
    });
  } catch(e) { /* noop */ }
}

// Observe DOM changes and try to play when the preview element appears
const musicObserver = new MutationObserver((mutations) => {
  for (const m of mutations) {
    if (m.addedNodes && m.addedNodes.length) {
      tryPlayMusicPreview();
      break;
    }
  }
});
musicObserver.observe(document.body, { childList: true, subtree: true });
// Also attempt once on navigation stop
window.addEventListener('phx:page-loading-stop', tryPlayMusicPreview);
// Try immediately on load
tryPlayMusicPreview();

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