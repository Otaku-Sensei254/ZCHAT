// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import data from "@emoji-mart/data"
import { Picker } from "emoji-mart"
//import './user_socket.js'
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

import userSocket from "./user_socket";

// Define Hooks object
let Hooks = {};

const BROWSER_NOTIFICATIONS_KEY = "vibeflow_browser_notifications_enabled";

function browserNotificationsEnabled() {
  return localStorage.getItem(BROWSER_NOTIFICATIONS_KEY) !== "false";
}

function setBrowserNotificationsEnabled(enabled) {
  localStorage.setItem(BROWSER_NOTIFICATIONS_KEY, enabled ? "true" : "false");
  window.dispatchEvent(new CustomEvent("vibeflow:notification-setting-changed"));
}

Hooks.ChatInput = {
  mounted() {
    // Handle Enter key to submit
    this.el.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault(); 
        // Use LiveView's pushEvent instead of form submit to avoid double submission
        const form = this.el.closest("form");
        const submitButton = form.querySelector('button[type="submit"]');
        if (submitButton && !submitButton.disabled) {
          submitButton.click();
        }
      } else if (e.key === "Escape") {
        this.hideEmojiPicker();
      }
      this.pushTyping();
    });
    this.el.addEventListener("input", () => this.autoGrow());

    this.bindEmojiUI();

    this.handleEvent("clear-input", () => {
      this.el.value = "";
      this.autoGrow();
    });
    this.autoGrow();
  },
  updated() {
    this.bindEmojiUI();
    this.autoGrow();
  },

  typingTimer: null,
  bindEmojiUI() {
    const form = this.el.closest("form");
    const emojiToggle = form?.querySelector("[data-emoji-toggle]");
    const emojiPanel = form?.querySelector("[data-emoji-picker]");
    const emojiPickerContainer = form?.querySelector("[data-emoji-picker-container]");

    const sameNodes =
      this.emojiToggle === emojiToggle &&
      this.emojiPanel === emojiPanel &&
      this.emojiPickerContainer === emojiPickerContainer;

    if (sameNodes && this.emojiToggleClick && this.outsideClick) return;

    if (this.emojiToggle && this.emojiToggleClick) {
      this.emojiToggle.removeEventListener("click", this.emojiToggleClick);
    }
    if (this.outsideClick) {
      document.removeEventListener("click", this.outsideClick);
    }
    if (this.fallbackEmojiWrap && this.fallbackEmojiClick) {
      this.fallbackEmojiWrap.removeEventListener("click", this.fallbackEmojiClick);
    }

    this.form = form;
    this.emojiToggle = emojiToggle;
    this.emojiPanel = emojiPanel;
    this.emojiPickerContainer = emojiPickerContainer;

    if (!(this.emojiToggle && this.emojiPanel && this.emojiPickerContainer)) return;

    if (!this.emojiPickerContainer.firstChild) {
      try {
        this.emojiPickerInstance = new Picker({
          data,
          theme: document.documentElement.classList.contains("dark") ? "dark" : "light",
          previewPosition: "none",
          navPosition: "top",
          maxFrequentRows: 2,
          perLine: 8,
          set: "native",
          onEmojiSelect: (emoji) => this.insertEmoji(emoji.native)
        });
        this.emojiPickerContainer.appendChild(this.emojiPickerInstance);
      } catch (_err) {
        this.renderEmojiFallback();
      }
    }

    this.emojiToggleClick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.toggleEmojiPicker();
    };

    this.outsideClick = (e) => {
      if (!this.emojiPanel.classList.contains("hidden")) {
        const clickedInsidePicker = this.emojiPanel.contains(e.target);
        const clickedToggle = this.emojiToggle.contains(e.target);
        if (!clickedInsidePicker && !clickedToggle) {
          this.hideEmojiPicker();
        }
      }
    };

    this.emojiToggle.addEventListener("click", this.emojiToggleClick);
    document.addEventListener("click", this.outsideClick);
  },
  autoGrow() {
    this.el.style.height = "auto";
    const nextHeight = Math.min(this.el.scrollHeight, 144);
    this.el.style.height = `${nextHeight}px`;
  },
  renderEmojiFallback() {
    const emojis = ["😊","😀","😂","😍","😉","🤔","👍","👏","🔥","🎉","❤️","🙏","😎","😭","😅","😡","🤝","✅"];
    const wrap = document.createElement("div");
    wrap.className = "w-56 rounded-xl border border-gray-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 shadow-lg p-2";
    wrap.innerHTML = emojis.map((emoji) =>
      `<button type="button" data-fallback-emoji="${emoji}" class="p-1 text-xl rounded hover:bg-gray-100 dark:hover:bg-zinc-700">${emoji}</button>`
    ).join("");
    wrap.classList.add("grid", "grid-cols-6", "gap-1");
    this.fallbackEmojiClick = (e) => {
      const btn = e.target.closest("[data-fallback-emoji]");
      if (!btn) return;
      this.insertEmoji(btn.getAttribute("data-fallback-emoji"));
    };
    wrap.addEventListener("click", this.fallbackEmojiClick);
    this.fallbackEmojiWrap = wrap;
    this.emojiPickerContainer.appendChild(wrap);
  },
  toggleEmojiPicker() {
    this.emojiPanel.classList.toggle("hidden");
  },
  hideEmojiPicker() {
    if (this.emojiPanel) this.emojiPanel.classList.add("hidden");
  },
  insertEmoji(emoji) {
    const start = this.el.selectionStart ?? this.el.value.length;
    const end = this.el.selectionEnd ?? this.el.value.length;
    const nextValue = this.el.value.slice(0, start) + emoji + this.el.value.slice(end);
    this.el.value = nextValue;
    const cursor = start + emoji.length;
    this.el.setSelectionRange(cursor, cursor);
    this.el.dispatchEvent(new Event("input", { bubbles: true }));
    this.el.focus();
    this.hideEmojiPicker();
    this.pushTyping();
  },
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
  },
  destroyed() {
    if (this.emojiToggle && this.emojiToggleClick) {
      this.emojiToggle.removeEventListener("click", this.emojiToggleClick);
    }
    if (this.fallbackEmojiWrap && this.fallbackEmojiClick) {
      this.fallbackEmojiWrap.removeEventListener("click", this.fallbackEmojiClick);
    }
    if (this.outsideClick) {
      document.removeEventListener("click", this.outsideClick);
    }
  }
}

Hooks.NotificationsHook = {
  mounted() {
    this.requestPermission = () => {
      if (!browserNotificationsEnabled()) return;
      if (!("Notification" in window)) return;
      if (Notification.permission === "default") {
        Notification.requestPermission().catch(() => {});
      }
    };

    this.maybeShowBrowserNotification = (notification) => {
      if (!notification) return;
      if (!browserNotificationsEnabled()) return;
      if (!("Notification" in window)) return;
      if (Notification.permission !== "granted") return;
      if (document.visibilityState === "visible") return;

      const browserNotification = new Notification(
        notification.title || "Vibeflow",
        {
          body: notification.body || "You have a new notification",
          icon: notification.icon || undefined,
          tag: notification.tag || undefined
        }
      );

      browserNotification.onclick = () => {
        window.focus();
        if (notification.url) {
          window.location.href = notification.url;
        }
        browserNotification.close();
      };
    };

    this.showBottleSplash = ({ url }) => {
      const existing = document.getElementById("bottle-arrival-overlay");
      if (existing) existing.remove();

      const overlay = document.createElement("button");
      overlay.id = "bottle-arrival-overlay";
      overlay.type = "button";
      overlay.className = "fixed inset-0 z-[120] flex items-center justify-center bg-sky-950/55 backdrop-blur-sm";
      overlay.innerHTML = `
        <div class="relative flex h-full w-full items-center justify-center overflow-hidden">
          <div class="absolute inset-0 bg-[radial-gradient(circle_at_center,_rgba(125,211,252,0.16),_transparent_55%)]"></div>
          <div class="absolute bottom-[-8rem] left-1/2 h-80 w-80 -translate-x-1/2 rounded-full border border-sky-200/30 bg-sky-300/12 animate-ping"></div>
          <div class="absolute bottom-[-5rem] left-1/2 h-56 w-[28rem] -translate-x-1/2 rounded-[100%] border-2 border-cyan-200/35"></div>
          <div class="absolute bottom-[-3rem] left-1/2 h-40 w-[22rem] -translate-x-1/2 rounded-[100%] border border-cyan-100/30"></div>
          <div class="relative flex flex-col items-center gap-4 px-6 text-center text-white">
            <div class="flex h-24 w-24 items-center justify-center rounded-full border border-emerald-200/50 bg-emerald-300/15 shadow-[0_0_40px_rgba(110,231,183,0.28)]">
              <span class="text-5xl">🍾</span>
            </div>
            <div class="space-y-2">
              <p class="text-xs font-semibold uppercase tracking-[0.28em] text-cyan-100/75">Ocean Delivery</p>
              <p class="text-2xl font-semibold text-white">A message in a bottle found you</p>
              <p class="text-sm text-cyan-100/80">Tap anywhere to open it.</p>
            </div>
          </div>
        </div>
      `;

      const close = () => {
        overlay.remove();
      };

      overlay.addEventListener("click", () => {
        close();
        if (url) {
          window.location.href = url;
        }
      });

      document.body.appendChild(overlay);
      window.setTimeout(close, 5000);
    };

    window.addEventListener("click", this.requestPermission, { once: true });
    this.onSettingsChanged = () => {
      if (browserNotificationsEnabled()) {
        this.requestPermission();
      }
    };
    window.addEventListener("vibeflow:notification-setting-changed", this.onSettingsChanged);

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

      this.maybeShowBrowserNotification(notification);
    });

    this.handleEvent("refresh_notifications", () => {
      // If modal is open, refresh notifications
      const modal = document.querySelector("#notifications-modal");
      if (modal && !modal.classList.contains("hidden")) {
        this.pushEvent("load_notifications", {});
      }
    });

    this.handleEvent("bottle_arrived", (payload) => {
      this.showBottleSplash(payload || {});
    });
  },

  destroyed() {
    window.removeEventListener("click", this.requestPermission);
    window.removeEventListener("vibeflow:notification-setting-changed", this.onSettingsChanged);
  }
};

Hooks.NotificationSettings = {
  mounted() {
    this.toggle = this.el.querySelector("[data-notifications-toggle]");
    this.status = this.el.querySelector("[data-notifications-status]");

    if (!(this.toggle && this.status)) return;

    this.renderState = () => {
      const enabled = browserNotificationsEnabled();
      const permission = "Notification" in window ? Notification.permission : "unsupported";
      const statusText =
        permission === "unsupported"
          ? "This browser does not support notifications."
          : `Status: ${enabled ? "Enabled" : "Disabled"} (${permission})`;

      this.status.textContent = statusText;
      this.toggle.textContent = enabled ? "Disable" : "Enable";
    };

    this.onToggle = () => {
      const nextEnabled = !browserNotificationsEnabled();
      setBrowserNotificationsEnabled(nextEnabled);

      if (nextEnabled && "Notification" in window && Notification.permission === "default") {
        Notification.requestPermission()
          .catch(() => {})
          .finally(() => this.renderState());
        return;
      }

      this.renderState();
    };

    this.toggle.addEventListener("click", this.onToggle);
    this.renderState();
  },

  destroyed() {
    if (this.toggle && this.onToggle) {
      this.toggle.removeEventListener("click", this.onToggle);
    }
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
          try {
            this.el.play().catch((error) => {
              // Autoplay was prevented (browser restrictions)
              // We catch this separately because it's a promise rejection
              if (error.name !== "AbortError") {
                console.log("Autoplay prevented: ", error);
              }
            });
          } catch (error) {
            // Catches other errors, like the one from the original report
            if (error.name !== "AbortError") {
              console.error("Error playing video:", error);
            }
          }
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

Hooks.ShareHook = {
  mounted() {
    this.handleEvent("share_post", ({title, text, url}) => {
      if (navigator.share) {
        // Use native Web Share API on mobile
        navigator.share({
          title: title,
          text: text,
          url: url
        }).catch((error) => {
          console.log("Share cancelled or failed:", error);
          // Fallback to copying to clipboard
          this.copyToClipboard(url);
        });
      } else {
        // Fallback for desktop - copy to clipboard
        this.copyToClipboard(url);
      }
    });
  },
  
  copyToClipboard(text) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text).then(() => {
        // Show success message (you could emit an event back to LiveView)
        console.log("Link copied to clipboard!");
      }).catch((error) => {
        console.error("Failed to copy:", error);
        // Fallback method
        this.fallbackCopy(text);
      });
    } else {
      this.fallbackCopy(text);
    }
  },
  
  fallbackCopy(text) {
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = "fixed";
    textArea.style.left = "-999999px";
    textArea.style.top = "-999999px";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    
    try {
      document.execCommand('copy');
      console.log("Link copied to clipboard!");
    } catch (error) {
      console.error("Failed to copy:", error);
    }
    
    document.body.removeChild(textArea);
  }
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

// Post card hook (no-op for now, keeps console clean if attribute is present)
Hooks.PostComponent = {
  mounted() {},
  updated() {},
  destroyed() {}
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
    
    // Initial State
    this.facingMode = "user"; 
    this.recording = false;
    this.mediaRecorder = null;
    this.recordingChunks = [];
    this.timerInterval = null;
    this.secondsRecorded = 0;
    this.timerStartMs = null;
    this.videoReady = false;
    this.stream = null;

    this.startCamera();
    this.setupButtons();

    this.handleEvent("switch-camera-mode", () => {
      this.facingMode = this.facingMode === "selfie" ? "environment" : "selfie";
      this.startCamera();
      console.log("Switched camera to", this.facingMode); 
    });
  },

  updated() {
    const newVideo = this.el.querySelector("#camera-feed");
    if (newVideo && newVideo !== this.video) {
      this.video = newVideo;
      if (this.stream) {
        this.video.srcObject = this.stream;
        this.video.play().catch(e => console.log("Autoplay blocked on update", e));
      }
    }
    this.timerEl = this.el.querySelector("#recording-timer");
    this.setupButtons();
  },

  destroyed() {
    this.stopCamera();
    this.stopTimer();
  },

  setupButtons() {
    const snapBtn = this.el.querySelector("#btn-snap");
    if (snapBtn && snapBtn.dataset.listenerAttached !== "true") {
      let holdTimeout;
      let isHolding = false;
      let recordingStarted = false;

      const handlePointerDown = (e) => {
        if (e.button && e.button !== 0) return; 
        e.preventDefault();
        isHolding = false;
        recordingStarted = false;

        holdTimeout = setTimeout(async () => {
          isHolding = true;
          recordingStarted = true;
          console.log("Snap button held - starting recording");
          if (!this.videoReady) await this.forceVideoPlay();
          if (!this.recording) await this.startRecording(snapBtn);
        }, 400); 
      };

      const handlePointerUpOrLeave = (e) => {
        e.preventDefault();
        clearTimeout(holdTimeout);

        if (recordingStarted) {
          // We were recording, so stop and ensure we don't trigger a tap
          if (this.recording) {
            this.stopRecording(snapBtn);
            console.log("Snap button released - stopped recording");
          }
          recordingStarted = false;
          isHolding = false;
        } else if (!isHolding && (e.type === "pointerup" || e.type === "mouseup" || e.type === "touchend")) {
          // Pure tap (didn't reach the hold threshold)
          console.log("Snap button tapped - capturing image");
          if (!this.videoReady) {
            this.forceVideoPlay().then(() => this.captureImage());
          } else {
            this.captureImage(); 
          }
        }
        
        isHolding = false;
      };

      // Consolidate to pointer events (modern standard for touch/mouse)
      snapBtn.addEventListener("pointerdown", handlePointerDown);
      snapBtn.addEventListener("pointerup", handlePointerUpOrLeave);
      snapBtn.addEventListener("pointerleave", handlePointerUpOrLeave);
      
      // Prevent default click and context menu to avoid interference on mobile
      snapBtn.addEventListener("click", (e) => e.preventDefault());
      snapBtn.addEventListener("contextmenu", (e) => e.preventDefault());
      
      snapBtn.dataset.listenerAttached = "true";
    }
    
    console.log("Camera buttons setup complete");
  },

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
        if (this.video) {
          this.video.srcObject = stream;
          this.video.muted = true;
          this.video.play().then(() => {
            this.videoReady = true;
            this.video.style.transform = this.facingMode === "user" ? "scaleX(-1)" : "scaleX(1)";
          }).catch(err => console.warn("Waiting for interaction", err));
        }
      })
      .catch(err => console.error("Camera Error:", err));
  },

  forceVideoPlay() {
    return this.video.play().then(() => {
      this.videoReady = true;
    }).catch(err => console.warn("Still blocked", err));
  },

  async ensureAudioForRecording() {
    try {
      const audioStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      if (this.stream) {
        audioStream.getAudioTracks().forEach(track => this.stream.addTrack(track));
      }
    } catch (err) {
      console.warn("Mic access denied", err);
    }
  },

  async startRecording(btn) {
    if (!this.stream) return;
    this.recordingChunks = [];
    await this.ensureAudioForRecording();

    let options = { mimeType: 'video/webm' };
    if (MediaRecorder.isTypeSupported('video/webm; codecs=vp9')) {
      options = { mimeType: 'video/webm; codecs=vp9' };
    } else if (MediaRecorder.isTypeSupported('video/mp4')) {
      options = { mimeType: 'video/mp4' };
    }

    try {
      this.mediaRecorder = new MediaRecorder(this.stream, options);
    } catch (err) {
      console.error("Failed to create MediaRecorder", err);
      return;
    }

    this.mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) this.recordingChunks.push(e.data);
    };

    this.mediaRecorder.onstop = () => {
      const blob = new Blob(this.recordingChunks, { type: this.recordingChunks[0]?.type || 'video/webm' });
      
      if (window.recordedVideoBlobURL) URL.revokeObjectURL(window.recordedVideoBlobURL);
      window.recordedVideoBlobURL = URL.createObjectURL(blob);

      const mime = blob.type || 'video/webm';
      const ext = mime.includes('mp4') ? 'mp4' : 'webm';
      const filename = `recording_${Date.now()}.${ext}`;
      const file = new File([blob], filename, { type: mime });

      this.upload("media", [file]);
      
      this.recording = false;
      this.stopTimer();
      this.stopMusicPreview();
      if (btn) {
        btn.classList.remove('animate-pulse', 'bg-red-700', 'scale-110');
        btn.innerHTML = `<div class="w-4 h-4 bg-white rounded-sm"></div>`;
      }
    };

    this.mediaRecorder.start();
    this.recording = true;
    this.startTimer();
    this.playMusicPreview();

    if (btn) {
      btn.classList.add('animate-pulse', 'bg-red-700', 'scale-110');
      btn.innerHTML = `<div class="w-3 h-3 bg-white rounded-sm"></div>`;
    }
  },

  stopRecording(btn) {
    this.stopMusicPreview();
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop();
    }
  },

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
      const filename = `photo_${Date.now()}.jpg`;
      const file = new File([blob], filename, { type: "image/jpeg" });

      if (window.recordedVideoBlobURL) URL.revokeObjectURL(window.recordedVideoBlobURL);
      window.recordedVideoBlobURL = URL.createObjectURL(file); 

      this.upload("media", [file]);
    }, "image/jpeg", 0.9);
  },

  startTimer() {
    this.secondsRecorded = 0;
    this.timerStartMs = Date.now();
    if (this.timerEl) {
      this.timerEl.classList.remove("hidden");
      this.timerEl.innerText = "00:00";
    }
    this.timerInterval = setInterval(() => {
      const elapsedMs = Date.now() - this.timerStartMs;
      const totalSeconds = Math.floor(elapsedMs / 1000);
      const m = Math.floor(totalSeconds / 60).toString().padStart(2, '0');
      const s = (totalSeconds % 60).toString().padStart(2, '0');
      if (this.timerEl) this.timerEl.innerText = `${m}:${s}`;
    }, 200);
  },

  stopTimer() {
    clearInterval(this.timerInterval);
    this.timerStartMs = null;
    if (this.timerEl) {
      this.timerEl.classList.add("hidden");
    }
  },

  getMusicPreviewEl() {
    return document.getElementById("music-preview-player");
  },

  playMusicPreview() {
    const audio = this.getMusicPreviewEl();
    if (!audio) return;
    try {
      audio.currentTime = 0;
      audio.loop = true;
      audio.play().catch(() => {});
    } catch (e) { /* noop */ }
  },

  stopMusicPreview() {
    const audio = this.getMusicPreviewEl();
    if (!audio) return;
    try {
      audio.pause();
      audio.currentTime = 0;
    } catch (e) { /* noop */ }
  }
};

// Media control hook for toggle events
Hooks.MediaControl = {
  mounted() {
    this.handleEvent("toggle_media", ({ video_id, audio_id, muted }) => {
      const video = document.getElementById(video_id);
      const audio = document.getElementById(audio_id);
      
      if (video) video.muted = muted;
      if (audio) audio.muted = muted;
    });
    
    this.handleEvent("toggle_video", ({ video_id, paused }) => {
      const video = document.getElementById(video_id);
      if (video) {
        if (paused) {
          video.pause();
        } else {
          video.play();
        }
      }
    });
  }
};


Hooks.AudioRecorder = {
  mounted() {
    this.recorder = null;
    this.chunks = [];
    this.recording = false;
    this.stream = null;
    this.startTime = null;
    this.timerInterval = null;
    this.analyser = null;
    this.audioContext = null;
    this.animationId = null;

    const startRecording = async () => {
      if (this.recording) return;
      
      // 1. Immediate UI feedback
      this.pushEvent("start_recording", {});

      try {
        this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        
        // Setup Visualizer
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const source = this.audioContext.createMediaStreamSource(this.stream);
        this.analyser = this.audioContext.createAnalyser();
        this.analyser.fftSize = 64;
        source.connect(this.analyser);
        const dataArray = new Uint8Array(this.analyser.frequencyBinCount);

        const animate = () => {
          if (!this.recording) return;
          this.analyser.getByteFrequencyData(dataArray);
          
          const bars = this.el.querySelectorAll('[data-rec-visualizer] div');
          bars.forEach((bar, i) => {
            const val = dataArray[i % dataArray.length] || 0;
            const height = Math.max(4, (val / 255) * 24);
            bar.style.height = `${height}px`;
            const opacity = 0.4 + (val / 255) * 0.6;
            bar.style.opacity = opacity;
          });
          this.animationId = requestAnimationFrame(animate);
        };
        
        const mimeType = MediaRecorder.isTypeSupported('audio/ogg;codecs=opus') 
                         ? 'audio/ogg;codecs=opus' 
                         : 'audio/webm;codecs=opus';
                         
        this.recorder = new MediaRecorder(this.stream, { mimeType });
        this.chunks = [];
        this.recording = true;
        
        animate();

        this.startTime = Date.now();
        this.timerInterval = setInterval(() => {
          const elapsed = Math.floor((Date.now() - this.startTime) / 1000);
          const minutes = Math.floor(elapsed / 60);
          const seconds = elapsed % 60;
          const timerElement = document.getElementById('recording-timer');
          if (timerElement) {
            timerElement.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
          }
        }, 100);
        
        this.recorder.ondataavailable = e => {
          if (e.data.size > 0) this.chunks.push(e.data);
        };
        
        this.recorder.onstop = async () => {
          this.cleanup();
          
          if (this.chunks.length === 0) return;
          
          const blob = new Blob(this.chunks, { type: mimeType });
          const extension = mimeType.includes('webm') ? 'webm' : 'ogg';
          const file = new File([blob], `voice_note_${Date.now()}.${extension}`, { type: mimeType });
          
          this.chunks = [];
          this.uploadAudioFile(file);
          this.pushEvent("validate", {});
          setTimeout(() => { this.pushEvent("stop_recording", {}); }, 600);
        };

        this.recorder.start();
      } catch (err) {
        console.error("Mic error:", err);
        this.pushEvent("cancel_recording", {});
      }
    };

    const stopRecording = () => {
      if (!this.recording) return;
      if (this.recorder && this.recorder.state === "recording") this.recorder.stop();
      if (this.stream) this.stream.getTracks().forEach(track => track.stop());
      this.recording = false;
    };

    this.cleanup = () => {
      if (this.timerInterval) clearInterval(this.timerInterval);
      if (this.animationId) cancelAnimationFrame(this.animationId);
      if (this.audioContext) this.audioContext.close();
      if (this.stream) this.stream.getTracks().forEach(track => track.stop());
    };

    // Use event delegation on this.el to handle clicks even after re-renders
    this.el.addEventListener("click", e => {
      const startBtn = e.target.closest('[data-rec-action="start"]');
      const stopBtn = e.target.closest('[data-rec-action="stop"]');
      
      if (startBtn) {
        e.preventDefault();
        startRecording();
      } else if (stopBtn) {
        e.preventDefault();
        stopRecording();
      }
    });
  },
  
  destroyed() {
    if (this.cleanup) this.cleanup();
  },
  uploadAudioFile(file) {
    // Try the robust LiveView upload helper first
    try {
      if (typeof this.upload === "function") {
        this.upload("audio", [file]);
        return;
      }
    } catch (err) {
      console.warn("Direct this.upload failed:", err);
    }

    // Fallback to manual input triggering
    const audioInput = document.getElementById("chat-audio-upload");
    if (!audioInput) return;
    const transfer = new DataTransfer();
    transfer.items.add(file);
    audioInput.files = transfer.files;
    audioInput.dispatchEvent(new Event("input", { bubbles: true }));
    audioInput.dispatchEvent(new Event("change", { bubbles: true }));
  }
}

Hooks.WaveVideo = {
  mounted() {
    this.el.addEventListener("ended", () => {
      // Only stop audio players that specifically belong to this wave's viewer
      const viewer = this.el.closest("#wave-viewer");
      if (viewer) {
        const audios = viewer.querySelectorAll("audio");
        audios.forEach(a => { a.pause(); a.currentTime = 0; });
      }
      this.pushEvent("video_ended", {})
    })
    // Attempt play, mute if blocked by browser policy
    this.el.play().catch(e => {
      this.el.muted = true
      this.el.play()
    })
  }
}

Hooks.WaveAudio = {
  mounted() {
    // Small delay to ensure any previous wave cleanup has finished
    setTimeout(() => {
      if (this.el) {
        this.el.play().catch(() => {
          console.log("Audio autoplay blocked, waiting for interaction");
        });
      }
    }, 50);
  },
  destroyed() {
    this.el.pause();
    this.el.currentTime = 0;
  }
}

Hooks.WavePlayer = {
  mounted() {
    this.initPlayer();
    this._onFocus = () => this.initPlayer();
    window.addEventListener("focus", this._onFocus);
  },
  updated() {
    const newUrl = this.el.dataset.url;
    if (this.currentUrl !== newUrl) {
      this.initPlayer();
    }
  },
  initPlayer() {
    this.audio = this.el.querySelector("audio");
    this.playBtn = this.el.querySelector(".play-btn");
    this.iconPlay = this.el.querySelector(".play-icon");
    this.iconPause = this.el.querySelector(".pause-icon");
    this.progress = this.el.querySelector(".progress-bar");
    this.timerEl = this.el.querySelector(".timer");
    this.currentUrl = this.el.dataset.url;

    if (!this.audio || !this.currentUrl) return;

    const fmt = (sec) => {
      if (!Number.isFinite(sec) || sec <= 0) return "0:00";
      const m = Math.floor(sec / 60);
      const s = Math.floor(sec % 60);
      return `${m}:${s.toString().padStart(2, "0")}`;
    };

    const updateDurationText = () => {
      if (this.audio.duration && Number.isFinite(this.audio.duration) && this.audio.duration !== Infinity) {
        this.timerEl.textContent = fmt(this.audio.duration);
      }
    };

    const updateProgress = () => {
      if (!this.audio.duration || !Number.isFinite(this.audio.duration)) return;
      
      const pct = (this.audio.currentTime / this.audio.duration) * 100;
      if (this.progress) this.progress.style.width = `${pct}%`;

      // ONLY update the text to current time if we are playing or scrubbing
      if (!this.audio.paused || this.audio.currentTime > 0) {
        this.timerEl.textContent = fmt(this.audio.currentTime);
      } else {
        updateDurationText();
      }
    };

    const setPlaying = (playing) => {
      if (playing) {
        this.iconPlay?.classList.add("hidden");
        this.iconPause?.classList.remove("hidden");
        this.playBtn?.classList.add("playing");
      } else {
        this.iconPause?.classList.add("hidden");
        this.iconPlay?.classList.remove("hidden");
        this.playBtn?.classList.remove("playing");
      }
    };

    // Listeners
    if (this._onMetadata) this.audio.removeEventListener("loadedmetadata", this._onMetadata);
    if (this._onDuration) this.audio.removeEventListener("durationchange", this._onDuration);
    if (this._onTime) this.audio.removeEventListener("timeupdate", this._onTime);
    if (this._onEnded) this.audio.removeEventListener("ended", this._onEnded);

    this._onMetadata = () => {
      // Common hack for WebM/Opus duration: seek to end and back
      if (this.audio.duration === Infinity) {
        this.audio.currentTime = 1e101;
        this.audio.ontimeupdate = () => {
          this.audio.ontimeupdate = null;
          this.audio.currentTime = 0;
          updateDurationText();
        };
      } else {
        updateDurationText();
      }
    };
    this._onDuration = updateDurationText;
    this._onTime = updateProgress;
    this._onEnded = () => {
      setPlaying(false);
      if (this.progress) this.progress.style.width = "0%";
      updateDurationText();
    };

    this.audio.addEventListener("loadedmetadata", this._onMetadata);
    this.audio.addEventListener("durationchange", this._onDuration);
    this.audio.addEventListener("timeupdate", this._onTime);
    this.audio.addEventListener("ended", this._onEnded);

    // Initial setup
    if (this.audio.src !== this.currentUrl) {
      this.audio.src = this.currentUrl;
      this.audio.load();
    }

    // Polling fallback
    if (this.durationPoller) clearInterval(this.durationPoller);
    let pollCount = 0;
    this.durationPoller = setInterval(() => {
      if (this.audio && this.audio.duration && Number.isFinite(this.audio.duration) && this.audio.duration > 0 && this.audio.duration !== Infinity) {
        updateDurationText();
        clearInterval(this.durationPoller);
      } else if (this.audio && this.audio.duration === Infinity) {
         // Try the seek-to-end hack during polling too
         this.audio.currentTime = 1e101;
      }
      if (++pollCount > 50) clearInterval(this.durationPoller);
    }, 200);

    if (this.playBtn && !this.playBtn._listenerAttached) {
      this.playBtn.addEventListener("click", (e) => {
        e.preventDefault();
        if (this.audio.readyState === 0) this.audio.load();
        if (this.audio.paused) {
          this.audio.play().then(() => setPlaying(true)).catch(() => {
            this.audio.load();
            this.audio.play().then(() => setPlaying(true));
          });
        } else {
          this.audio.pause();
          setPlaying(false);
        }
      });
      this.playBtn._listenerAttached = true;
    }
  },
  destroyed() {
    if (this.audio) this.audio.pause();
    if (this.durationPoller) clearInterval(this.durationPoller);
    if (this._onFocus) window.removeEventListener("focus", this._onFocus);
  }
};

//auto scroll for chat messages
Hooks.ScrollToBottom = {
  mounted() {
    const scrollAfterPaint = () => requestAnimationFrame(() => this.scrollToBottom());
    requestAnimationFrame(scrollAfterPaint);
    this.handleEvent("scroll-to-bottom", scrollAfterPaint);
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
Hooks.MentionHook = {
  mounted() {
    // Find all text inputs in the post component
    const textInputs = this.el.querySelectorAll('input[type="text"], textarea');
    
    textInputs.forEach(input => {
      input.addEventListener('input', (e) => this.handleInput.call(this, e));
      input.addEventListener('keydown', (e) => this.handleKeyDown.call(this, e));
    });
  },

  destroyed() {
    const textInputs = this.el.querySelectorAll('input[type="text"], textarea');
    textInputs.forEach(input => {
      input.removeEventListener('input', this.handleInput.bind(this));
      input.removeEventListener('keydown', this.handleKeyDown.bind(this));
    });
  },

  handleInput(e) {
    const value = e.target.value;
    const cursorPos = e.target.selectionStart;
    
    // Check if @ was just typed
    const beforeCursor = value.substring(0, cursorPos);
    const atMatch = beforeCursor.match(/@(\w*)$/);
    
    if (atMatch) {
      const searchTerm = atMatch[1];
      if (searchTerm.length >= 2) {
        this.searchUsers(searchTerm);
        this.showModal();
      }
    } else {
      this.hideModal();
    }
  },

  handleKeyDown(e) {
    if (e.key === 'Escape') {
      this.hideModal();
    }
  },

  searchUsers(query) {
    this.pushEvent("search_mentions", { query: query });
  },

  showModal() {
    const modal = document.getElementById('mention-modal');
    if (modal) {
      modal.classList.remove('hidden');
    }
  },

  hideModal() {
    const modal = document.getElementById('mention-modal');
    if (modal) {
      modal.classList.add('hidden');
    }
  }
};


// Create the LiveSocket ONCE, passing the Hooks

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbacksMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks
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

// Password visibility toggle function
window.togglePasswordVisibility = function(inputId, button) {
  const input = document.getElementById(inputId);
  if (!input) return;
  
  const isPassword = input.type === 'password';
  input.type = isPassword ? 'text' : 'password';
  
  // Update the icon
  const icon = button.querySelector('svg');
  if (icon) {
    // Remove existing icon classes
    icon.className = icon.className.replace(/hero-eye[^"\s]*|hero-eye-slash[^"\s]*/g, '').trim();
    
    // Add the appropriate icon class
    if (isPassword) {
      icon.classList.add('hero-eye-slash');
    } else {
      icon.classList.add('hero-eye');
    }
  }
  
  // Update aria-label
  button.setAttribute('aria-label', isPassword ? 'Hide password' : 'Show password');
};

window.liveSocket = liveSocket
