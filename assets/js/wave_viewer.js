// Wave Viewer JavaScript Hooks
export const WaveVideo = {
  mounted() {
    this.el.addEventListener('play', () => {
      this.pushEvent("video_playing", {});
    });
    
    this.el.addEventListener('pause', () => {
      this.pushEvent("video_paused", {});
    });
  },
  
  updated() {
    // Handle video updates when switching waves
  }
};

export const WaveAudio = {
  mounted() {
    this.el.addEventListener('play', () => {
      this.pushEvent("audio_playing", {});
    });
    
    this.el.addEventListener('pause', () => {
      this.pushEvent("audio_paused", {});
    });
  }
};

// Media control hook for toggle events
export const MediaControl = {
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
