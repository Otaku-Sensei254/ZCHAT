
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

// In your app.js - replace the entire ChatHook with this:

Hooks.ChatHook = {
  mounted() {
    // 1. DEFINE VARIABLES FIRST (Fixes the ReferenceError)
    const form = this.el.querySelector("form");
    const input = this.el.querySelector("input[name='message[content]']");
    const conversationId = this.el.dataset.conversationId;

    if (!conversationId) return;

    // 2. CONNECT TO CHANNEL
    this.channel = userSocket.channel(`conversation:${conversationId}`, {});

    // 3. LISTEN FOR EVENTS (Server -> Client)
    
    // Message received
    this.channel.on("new_message", (payload) => {
      this.pushEvent("display_new_message", payload);
    });

    // Typing indicator received
    this.channel.on("typing", (payload) => {
      this.pushEvent("update_typing_indicator", {
        user_id: payload.user.id,
        username: payload.user.username,
        is_typing: payload.typing
      });
    });

    // Join the channel
    this.channel.join()
      .receive("ok", resp => console.log("Joined conversation successfully", resp))
      .receive("error", resp => console.error("Unable to join conversation", resp));

    // 4. HANDLE INPUT (Client -> Server)
    
  if (input) {
      let typingTimer;
      input.addEventListener("input", () => {
        clearTimeout(typingTimer);
        this.channel.push("typing", { typing: true });
        typingTimer = setTimeout(() => {
          this.channel.push("typing", { typing: false });
        }, 2000);
      });
    }

    // 5. HANDLE SUBMIT
    if (form && input) {
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        const content = input.value.trim();

        if (content) {
          // Push to channel
          this.channel.push("new_message", { content: content })
          
            .receive("ok", () => {
              console.log("Message sent");
              input.value = ""; // Clear input
              
              // Stop typing indicator immediately upon send
              this.channel.push("typing", { typing: false });
            })
            .receive("error", (err) => console.error("Failed to send", err));
        }
      });
    }
  },

  destroyed() {
    if (this.channel) {
      this.channel.leave();
    }
  }
};

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
// Create the LiveSocket ONCE, passing the Hooks
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks, 
});

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

window.liveSocket = liveSocket