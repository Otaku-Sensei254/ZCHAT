import { useState, useRef, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { FiCamera, FiUpload, FiMusic, FiX, FiArrowLeft, FiSend, FiRepeat, FiCheck } from "react-icons/fi";
import api from "../../utils/api";

export default function CreateWave() {
  const navigate = useNavigate();
  const fileInputRef = useRef(null);
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);

  const [step, setStep] = useState("choose");
  const [capturing, setCapturing] = useState(false);
  const [cameraFacing, setCameraFacing] = useState("user");
  const [previewUrl, setPreviewUrl] = useState(null);
  const [previewType, setPreviewType] = useState(null);
  const [caption, setCaption] = useState("");
  const [uploading, setUploading] = useState(false);

  // Music state
  const [musicQuery, setMusicQuery] = useState("");
  const [musicResults, setMusicResults] = useState([]);
  const [selectedMusic, setSelectedMusic] = useState(null);
  const [searchingMusic, setSearchingMusic] = useState(false);
  const [previewingTrackId, setPreviewingTrackId] = useState(null);
  const audioRef = useRef(null);
  const previewAudioRef = useRef(null);

  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((t) => t.stop());
      }
    };
  }, []);

  const startCamera = async () => {
    try {
      if (streamRef.current) streamRef.current.getTracks().forEach((t) => t.stop());
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: cameraFacing },
        audio: true,
      });
      streamRef.current = stream;
      if (videoRef.current) videoRef.current.srcObject = stream;
      setCapturing(true);
    } catch {
      alert("Camera access denied");
    }
  };

  const stopCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    }
    setCapturing(false);
  };

  const switchCamera = async () => {
    setCameraFacing((f) => (f === "user" ? "environment" : "user"));
    if (capturing) {
      stopCamera();
      setTimeout(startCamera, 100);
    }
  };

  const capturePhoto = () => {
    if (!videoRef.current) return;
    const canvas = document.createElement("canvas");
    canvas.width = videoRef.current.videoWidth;
    canvas.height = videoRef.current.videoHeight;
    canvas.getContext("2d").drawImage(videoRef.current, 0, 0);
    canvas.toBlob((blob) => {
      const url = URL.createObjectURL(blob);
      setPreviewUrl(url);
      setPreviewType("image");
      setStep("preview");
      stopCamera();
    }, "image/jpeg");
  };

  const startRecording = () => {
    if (!streamRef.current) return;
    chunksRef.current = [];
    const recorder = new MediaRecorder(streamRef.current, {
      mimeType: MediaRecorder.isTypeSupported("video/webm;codecs=vp9")
        ? "video/webm;codecs=vp9"
        : "video/webm",
    });
    recorder.ondataavailable = (e) => {
      if (e.data.size > 0) chunksRef.current.push(e.data);
    };
    recorder.onstop = () => {
      const blob = new Blob(chunksRef.current, { type: "video/webm" });
      const url = URL.createObjectURL(blob);
      setPreviewUrl(url);
      setPreviewType("video");
      setStep("preview");
      stopCamera();
    };
    recorder.start();
    mediaRecorderRef.current = recorder;
    // Auto-stop after 60s
    setTimeout(() => {
      if (mediaRecorderRef.current?.state === "recording") {
        mediaRecorderRef.current.stop();
      }
    }, 60000);
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current?.state === "recording") {
      mediaRecorderRef.current.stop();
    }
  };

  const handleGallerySelect = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    setPreviewType(file.type.startsWith("video/") ? "video" : "image");
    setStep("preview");
  };

  const uploadToR2 = async (blob, contentType) => {
    const res = await api.post("/uploads/media", blob, {
      headers: { "Content-Type": contentType },
      params: { content_type: contentType, upload_id: `wave-${Date.now()}` },
    });
    return res.data.data?.url;
  };

  const handleShare = async () => {
    if (!previewUrl) return;
    setUploading(true);

    try {
      const resp = await fetch(previewUrl);
      const blob = await resp.blob();
      const contentType = previewType === "video" ? "video/webm" : "image/jpeg";
      const finalMediaUrl = await uploadToR2(blob, contentType);

      let musicTrackId = null;
      if (selectedMusic) {
        const musicRes = await api.post("/music/tracks", {
          music_track: {
            title: selectedMusic.trackName,
            artist: selectedMusic.artistName,
            audio_url: selectedMusic.previewUrl,
            cover_art: selectedMusic.artworkUrl,
            itunes_track_id: String(selectedMusic.trackId),
            duration_ms: String(selectedMusic.durationMs || 0),
          },
        });
        musicTrackId = musicRes.data.data?.music_track?.id;
      }

      await api.post("/waves", {
        wave: {
          media_url: finalMediaUrl,
          media_type: previewType,
          caption,
          music_track_id: musicTrackId,
        },
      });

      navigate(-1);
    } catch {
      alert("Failed to upload wave");
    }
    setUploading(false);
  };

  // Music search
  const searchMusic = async (q) => {
    setMusicQuery(q);
    if (!q.trim()) { setMusicResults([]); return; }
    setSearchingMusic(true);
    try {
      const res = await fetch(
        `https://itunes.apple.com/search?term=${encodeURIComponent(q)}&media=music&limit=12&entity=song`
      );
      const data = await res.json();
      setMusicResults(
        (data.results || []).map((r) => ({
          trackId: String(r.trackId),
          trackName: r.trackName,
          artistName: r.artistName,
          artworkUrl: r.artworkUrl100?.replace("100x100", "300x300"),
          previewUrl: r.previewUrl,
          collectionName: r.collectionName,
          durationMs: r.trackTimeMillis,
        }))
      );
    } catch { setMusicResults([]); }
    setSearchingMusic(false);
  };

  const handleSelectMusic = (track) => {
    setSelectedMusic(track);
    setStep("preview");
    if (previewAudioRef.current) {
      previewAudioRef.current.pause();
      previewAudioRef.current.src = "";
    }
    setPreviewingTrackId(null);
    // Play preview
    if (audioRef.current) {
      audioRef.current.src = track.previewUrl;
      audioRef.current.loop = true;
      audioRef.current.play().catch(() => {});
    }
  };

  const handlePreviewMusic = (track) => {
    if (previewingTrackId === track.trackId) {
      previewAudioRef.current?.pause();
      setPreviewingTrackId(null);
    } else {
      if (previewAudioRef.current) {
        previewAudioRef.current.src = track.previewUrl;
        previewAudioRef.current.volume = 0.5;
        previewAudioRef.current.play().catch(() => {});
      }
      setPreviewingTrackId(track.trackId);
    }
  };

  const handleRemoveMusic = () => {
    setSelectedMusic(null);
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = "";
    }
  };

  const renderChooseStep = () => (
    <div className="flex-1 flex flex-col items-center justify-center gap-6 p-8">
      <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Create a Wave</h1>
      <p className="text-gray-500 dark:text-gray-400 text-center max-w-sm">
        Capture a moment, share music, or upload a video
      </p>
      <div className="flex flex-col gap-4 w-full max-w-xs">
        <button
          onClick={() => { setStep("capture"); setTimeout(startCamera, 200); }}
          className="flex items-center gap-3 px-6 py-4 rounded-xl bg-gradient-to-r from-flow-500 to-coral-500 text-white font-semibold hover:opacity-90 transition"
        >
          <FiCamera size={24} />
          Take photo or video
        </button>
        <button
          onClick={() => { fileInputRef.current?.click(); }}
          className="flex items-center gap-3 px-6 py-4 rounded-xl bg-gradient-to-r from-cyan-500 to-blue-500 text-white font-semibold hover:opacity-90 transition"
        >
          <FiUpload size={24} />
          Upload from gallery
        </button>
        <button
          onClick={() => { setStep("music"); setMusicQuery(""); searchMusic("trending"); }}
          className="flex items-center gap-3 px-6 py-4 rounded-xl border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 font-semibold hover:bg-gray-100 dark:hover:bg-gray-800 transition"
        >
          <FiMusic size={24} />
          {selectedMusic ? "Change music" : "Add sound"}
        </button>
      </div>
      {selectedMusic && (
        <div className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-flow-50 dark:bg-flow-900/20 border border-flow-200 dark:border-flow-800/40 w-full max-w-xs">
          <img src={selectedMusic.artworkUrl} alt="" className="w-11 h-11 rounded-xl object-cover shadow-sm" />
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-gray-900 dark:text-white truncate flex items-center gap-1.5">
              <FiMusic size={12} className="text-flow-500 shrink-0" />
              {selectedMusic.trackName}
            </p>
            <p className="text-xs text-gray-500 dark:text-gray-400 truncate">
              {selectedMusic.artistName}
            </p>
          </div>
          <button onClick={handleRemoveMusic} className="text-gray-400 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition">
            <FiX size={14} />
          </button>
        </div>
      )}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*,video/*"
        className="hidden"
        onChange={handleGallerySelect}
      />
      <audio ref={audioRef} />
    </div>
  );

  const renderCaptureStep = () => (
    <div className="flex-1 relative bg-black flex items-center justify-center">
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        className="w-full h-full object-cover"
      />
      {/* Top bar */}
      <div className="absolute top-0 left-0 right-0 flex items-center justify-between p-4">
        <button onClick={() => { stopCamera(); setStep("choose"); }} className="text-white/70 hover:text-white p-2">
          <FiArrowLeft size={24} />
        </button>
        <button onClick={switchCamera} className="text-white/70 hover:text-white p-2">
          <FiRepeat size={20} />
        </button>
      </div>
      {/* Capture button */}
      <div className="absolute bottom-12 left-0 right-0 flex items-center justify-center gap-8">
        <button
          onClick={capturePhoto}
          className="w-16 h-16 rounded-full border-4 border-white flex items-center justify-center hover:scale-105 transition"
        >
          <div className="w-12 h-12 rounded-full bg-white" />
        </button>
        <button
          onMouseDown={startRecording}
          onMouseUp={stopRecording}
          onTouchStart={startRecording}
          onTouchEnd={stopRecording}
          className="w-16 h-16 rounded-full border-4 border-red-500 flex items-center justify-center hover:scale-105 transition"
        >
          <div className="w-8 h-8 rounded-full bg-red-500" />
        </button>
      </div>
    </div>
  );

  const renderPreviewStep = () => (
    <div className="flex-1 flex flex-col">
      <div className="flex-1 relative bg-black flex items-center justify-center">
        {previewType === "video" ? (
          <video src={previewUrl} controls autoPlay muted playsInline className="max-h-full max-w-full object-contain" />
        ) : (
          <img src={previewUrl} alt="" className="max-h-full max-w-full object-contain" />
        )}
      </div>
      <div className="p-4 space-y-3">
        <input
          type="text"
          value={caption}
          onChange={(e) => setCaption(e.target.value)}
          placeholder="Write a caption..."
          className="w-full bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white rounded-xl px-4 py-3 outline-none"
        />
        <div className="flex items-center gap-3">
          {selectedMusic && (
            <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-flow-50 dark:bg-flow-900/20 border border-flow-200 dark:border-flow-800/40 text-xs">
              <FiMusic size={13} className="text-flow-500 shrink-0" />
              <span className="truncate max-w-[130px] font-medium text-gray-900 dark:text-white">{selectedMusic.trackName}</span>
              <span className="text-gray-400 dark:text-gray-500">•</span>
              <span className="text-gray-500 dark:text-gray-400 truncate max-w-[80px]">{selectedMusic.artistName}</span>
              <button onClick={handleRemoveMusic} className="ml-1 text-gray-400 hover:text-red-400 p-0.5 rounded"><FiX size={12} /></button>
            </div>
          )}
          <button
            onClick={() => { setStep("music"); searchMusic("trending"); }}
            className="text-sm text-flow-500 hover:text-flow-400 font-medium"
          >
            {selectedMusic ? "Change" : "Add sound"}
          </button>
        </div>
        <button
          onClick={handleShare}
          disabled={uploading}
          className="w-full py-3 rounded-xl bg-gradient-to-r from-flow-500 to-coral-500 text-white font-semibold flex items-center justify-center gap-2 disabled:opacity-50"
        >
          {uploading ? (
            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <>
              <FiSend size={18} />
              Share Wave
            </>
          )}
        </button>
      </div>
    </div>
  );

  const renderMusicStep = () => (
    <div className="flex-1 flex flex-col">
      <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-200 dark:border-gray-700">
        <button onClick={() => { setStep("preview"); setMusicQuery(""); }} className="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 p-1">
          <FiArrowLeft size={22} />
        </button>
        <h2 className="text-lg font-semibold text-gray-900 dark:text-white">Add Sound</h2>
      </div>
      <div className="p-4">
        <div className="relative">
          <FiMusic size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={musicQuery}
            onChange={(e) => searchMusic(e.target.value)}
            placeholder="Search songs..."
            className="w-full bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white rounded-xl pl-10 pr-4 py-3 outline-none focus:ring-2 focus:ring-flow-500/50 transition"
            autoFocus
          />
        </div>
      </div>
      <div className="flex-1 overflow-y-auto px-4 space-y-1 pb-4">
        {searchingMusic ? (
          <div className="flex flex-col items-center justify-center py-12 gap-3">
            <div className="w-8 h-8 border-[3px] border-flow-500/30 border-t-flow-500 rounded-full animate-spin" />
            <p className="text-sm text-gray-400">Searching...</p>
          </div>
        ) : musicResults.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 gap-2">
            <FiMusic size={32} className="text-gray-300 dark:text-gray-600" />
            <p className="text-sm text-gray-400">
              {musicQuery ? "No songs found" : "Type to search for songs"}
            </p>
          </div>
        ) : (
          musicResults.map((track) => (
            <div
              key={track.trackId}
              className={`flex items-center gap-3 p-2 rounded-2xl transition-all duration-200 ${
                selectedMusic?.trackId === track.trackId
                  ? "bg-flow-500/15 ring-1 ring-flow-500/40"
                  : "hover:bg-gray-50 dark:hover:bg-white/5"
              }`}
            >
              <button
                onClick={() => handlePreviewMusic(track)}
                className="shrink-0 w-14 h-14 rounded-xl overflow-hidden relative group"
              >
                <img src={track.artworkUrl} alt="" className="w-full h-full object-cover" />
                <div className={`absolute inset-0 flex items-center justify-center transition-all duration-200 ${
                  previewingTrackId === track.trackId
                    ? "bg-black/40"
                    : "bg-black/20 group-hover:bg-black/30"
                }`}>
                  {previewingTrackId === track.trackId ? (
                    <div className="flex items-end gap-0.5 h-5">
                      <div className="w-0.5 bg-white rounded-full animate-pulse" style={{height: '60%', animationDelay: '0s'}} />
                      <div className="w-0.5 bg-white rounded-full animate-pulse" style={{height: '100%', animationDelay: '0.15s'}} />
                      <div className="w-0.5 bg-white rounded-full animate-pulse" style={{height: '40%', animationDelay: '0.3s'}} />
                      <div className="w-0.5 bg-white rounded-full animate-pulse" style={{height: '80%', animationDelay: '0.1s'}} />
                    </div>
                  ) : (
                    <svg className="w-6 h-6 text-white ml-0.5 drop-shadow-lg" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M8 5v14l11-7z"/>
                    </svg>
                  )}
                </div>
              </button>
              <button
                onClick={() => handleSelectMusic(track)}
                className="flex-1 min-w-0 text-left py-1"
              >
                <p className="text-sm font-semibold text-gray-900 dark:text-white truncate leading-tight">
                  {track.trackName}
                </p>
                <p className="text-xs text-gray-500 dark:text-gray-400 truncate mt-0.5">
                  {track.artistName}
                </p>
              </button>
              <button
                onClick={() => handleSelectMusic(track)}
                className={`shrink-0 rounded-xl px-3 py-2 text-xs font-semibold transition-all duration-200 ${
                  selectedMusic?.trackId === track.trackId
                    ? "bg-flow-500 text-white shadow-sm shadow-flow-500/30"
                    : "bg-gray-100 dark:bg-white/10 text-gray-600 dark:text-gray-300 hover:bg-flow-100 dark:hover:bg-flow-900/30 hover:text-flow-600"
                }`}
              >
                {selectedMusic?.trackId === track.trackId ? "Added" : "Add"}
              </button>
            </div>
          ))
        )}
      </div>
      <audio ref={previewAudioRef} onEnded={() => setPreviewingTrackId(null)} />
    </div>
  );

  return (
    <div className="fixed inset-0 z-50 bg-white dark:bg-gray-900 flex flex-col">
      {step === "choose" && renderChooseStep()}
      {step === "capture" && renderCaptureStep()}
      {step === "preview" && renderPreviewStep()}
      {step === "music" && renderMusicStep()}
    </div>
  );
}
