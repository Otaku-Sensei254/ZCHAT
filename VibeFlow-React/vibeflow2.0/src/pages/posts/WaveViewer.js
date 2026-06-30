import { useState, useEffect, useRef, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { FiX, FiChevronLeft, FiVolume2, FiVolumeX, FiHeart, FiSend, FiShare2 } from "react-icons/fi";
import api from "../../utils/api";

const VIDEO_EXTS = [".mp4", ".webm", ".mov", ".mkv", ".avi", ".m4v"];

function isVideo(wave) {
  if (!wave) return false;
  if (wave.media_type === "video") return true;
  if (!wave.media_url) return false;
  try {
    const ext = new URL(wave.media_url).pathname.split(".").pop()?.toLowerCase();
    return ext ? VIDEO_EXTS.includes(`.${ext}`) : false;
  } catch { return false; }
}

function formatTime(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr.endsWith("Z") || dateStr.includes("+") ? dateStr : dateStr + "Z");
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return d.toLocaleDateString();
}

export default function WaveViewer() {
  const { username } = useParams();
  const navigate = useNavigate();
  const videoRef = useRef(null);
  const audioRef = useRef(null);
  const timerRef = useRef(null);

  const [waveGroups, setWaveGroups] = useState([]);
  const [groupIndex, setGroupIndex] = useState(0);
  const [chainEnabled, setChainEnabled] = useState(false);
  const [index, setIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [muted, setMuted] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [liked, setLiked] = useState(false);
  const [likesCount, setLikesCount] = useState(0);
  const [paused, setPaused] = useState(false);
  const [messageText, setMessageText] = useState("");
  const [sending, setSending] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);
  const [shareSearch, setShareSearch] = useState("");
  const [shareResults, setShareResults] = useState([]);
  const [sharing, setSharing] = useState(false);

  const globalIndex = (() => {
    if (!chainEnabled) return index;
    let offset = 0;
    for (let i = 0; i < groupIndex && i < waveGroups.length; i++) {
      offset += waveGroups[i].waves.length;
    }
    return offset + index;
  })();

  useEffect(() => {
    let cancelled = false;
    api.get("/waves").then((res) => {
      if (cancelled) return;
      const groups = res.data.data?.groups || [];
      setWaveGroups(groups);
      const idx = groups.findIndex((g) => g.user?.username === username);
      if (idx >= 0) {
        setGroupIndex(idx);
        setChainEnabled(true);
      } else if (groups.length > 0) {
        setGroupIndex(0);
        setChainEnabled(true);
      }
      setLoaded(true);
    }).catch(() => setLoaded(true));
    return () => { cancelled = true; };
  }, [username]);

  useEffect(() => {
    setLoaded(false);
    setProgress(0);
  }, [groupIndex, index]);

  const currentGroup = waveGroups[groupIndex];
  const waves = currentGroup?.waves || [];
  const current = waves[index];

  useEffect(() => {
    if (current) {
      setLiked(!!current.is_liked);
      setLikesCount(current.likes_count || 0);
    }
  }, [current]);

  useEffect(() => {
    if (!current) return;
    api.post(`/waves/${current.uuid}/view`).catch(() => {});
  }, [current]);

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = "";
    }
    if (current?.music_track?.audio_url) {
      audioRef.current.src = current.music_track.audio_url;
      audioRef.current.volume = 0.3;
      audioRef.current.loop = true;
      audioRef.current.play().catch(() => {});
    }
  }, [current]);

  const goNext = useCallback(() => {
    if (index < waves.length - 1) {
      setIndex((i) => i + 1);
    } else if (chainEnabled && groupIndex < waveGroups.length - 1) {
      setGroupIndex((g) => g + 1);
      setIndex(0);
    } else {
      navigate(-1);
    }
  }, [index, waves.length, groupIndex, waveGroups.length, chainEnabled, navigate]);

  const goPrev = useCallback(() => {
    if (index > 0) {
      setIndex((i) => i - 1);
    } else if (chainEnabled && groupIndex > 0) {
      setGroupIndex((g) => g - 1);
      const prevWaves = waveGroups[groupIndex - 1]?.waves || [];
      setIndex(prevWaves.length - 1);
    }
  }, [index, groupIndex, waveGroups, chainEnabled]);

  useEffect(() => {
    setProgress(0);
    clearInterval(timerRef.current);
    if (!current || !loaded || paused) return;
    const isVid = isVideo(current);
    const duration = isVid ? 15000 : 5000;
    const step = 100 / (duration / 50);
    timerRef.current = setInterval(() => {
      setProgress((p) => {
        if (p >= 100) {
          clearInterval(timerRef.current);
          setTimeout(goNext, 0);
          return 0;
        }
        return p + step;
      });
    }, 50);
    return () => clearInterval(timerRef.current);
  }, [index, current?.uuid, loaded, paused, goNext]); // eslint-disable-line react-hooks/exhaustive-deps

  const handlePointerDown = () => {
    setPaused(true);
    if (videoRef.current) videoRef.current.pause();
  };

  const handlePointerUp = () => {
    setPaused(false);
    if (videoRef.current) videoRef.current.play().catch(() => {});
  };

  const handleLike = async () => {
    if (!current) return;
    const prevLiked = liked;
    const prevCount = likesCount;
    setLiked(!prevLiked);
    setLikesCount(prevLiked ? prevCount - 1 : prevCount + 1);
    try {
      const res = await api.post(`/waves/${current.uuid}/like`);
      setLiked(res.data.data?.liked ?? !prevLiked);
      setLikesCount(res.data.data?.likes_count ?? prevCount);
    } catch {
      setLiked(prevLiked);
      setLikesCount(prevCount);
    }
  };

  const handleSendDM = async () => {
    if (!messageText.trim() || !current || sending) return;
    setSending(true);
    try {
      const convRes = await api.post(`/chat/start/${username}`);
      const convUuid = convRes.data.data?.conversation?.uuid;
      if (convUuid) {
        await api.post(`/chat/conversations/${convUuid}/messages`, {
          message: { content: messageText.trim(), shared_wave_id: current.id }
        });
        setMessageText("");
      }
    } catch {}
    setSending(false);
  };

  const handleShareSearch = async (q) => {
    setShareSearch(q);
    if (!q.trim()) { setShareResults([]); return; }
    try {
      const res = await api.get("/users/search", { params: { q } });
      setShareResults(res.data.data?.users || []);
    } catch { setShareResults([]); }
  };

  const handleShare = async (targetUsername) => {
    if (!current || sharing) return;
    setSharing(true);
    try {
      const convRes = await api.post(`/chat/start/${targetUsername}`);
      const convUuid = convRes.data.data?.conversation?.uuid;
      if (convUuid) {
        await api.post(`/chat/conversations/${convUuid}/messages`, {
          message: { content: "Shared a wave", shared_wave_id: current.id }
        });
      }
    } catch {}
    setSharing(false);
    setShowShareModal(false);
  };

  if (!current) {
    return (
      <div className="fixed inset-0 z-50 bg-black flex items-center justify-center">
        {!loaded ? (
          <div className="w-8 h-8 border-2 border-white/30 border-t-white rounded-full animate-spin" />
        ) : waveGroups.length > 0 ? (
          <p className="text-white/60 text-lg">No waves from {username}</p>
        ) : (
          <p className="text-white/60 text-lg">No waves available</p>
        )}
        <button onClick={() => navigate(-1)} className="absolute top-4 left-4 text-white/70 hover:text-white p-2">
          <FiX size={24} />
        </button>
      </div>
    );
  }

  return (
    <div
      className="fixed inset-0 z-50 bg-black flex flex-col select-none"
      onMouseDown={handlePointerDown}
      onMouseUp={handlePointerUp}
      onTouchStart={handlePointerDown}
      onTouchEnd={handlePointerUp}
    >
      <audio ref={audioRef} />

      {/* Top bar: progress + close + like + mute */}
      <div className="absolute top-0 left-0 right-0 z-10 px-3 pt-3 space-y-3">
        <div className="flex gap-0.5">
          {(chainEnabled ? waveGroups.flatMap((g) => g.waves) : waves).map((w, i) => (
            <div key={w.id || i} className="flex-1 h-[3px] rounded-full bg-white/20 overflow-hidden">
              <div
                className="h-full bg-white transition-all duration-100 ease-linear rounded-full"
                style={{
                  width:
                    i < globalIndex
                      ? "100%"
                      : i === globalIndex
                        ? `${progress}%`
                        : "0%",
                }}
              />
            </div>
          ))}
        </div>
        <div className="flex items-center justify-between">
          <button onClick={() => navigate(-1)} className="text-white/70 hover:text-white p-1">
            <FiX size={22} />
          </button>
          <div className="flex items-center gap-3">
            <button onClick={handleLike} className="text-white/70 hover:text-white p-1 transition-all">
              <FiHeart size={18} className={liked ? "fill-coral-500 text-coral-500" : ""} />
            </button>
            {isVideo(current) && (
              <button onClick={() => setMuted(!muted)} className="text-white/70 hover:text-white p-1">
                {muted ? <FiVolumeX size={18} /> : <FiVolume2 size={18} />}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Media area */}
      <div className="flex-1 relative flex items-center justify-center">
        {isVideo(current) ? (
          <video
            ref={videoRef}
            key={current.uuid}
            src={current.media_url}
            autoPlay
            muted={muted}
            playsInline
            onLoadedData={() => setLoaded(true)}
            onError={() => setLoaded(true)}
            className="max-h-full max-w-full object-contain"
          />
        ) : (
          <img
            key={current.uuid}
            src={current.media_url}
            alt=""
            onLoad={() => setLoaded(true)}
            onError={() => setLoaded(true)}
            className="max-h-full max-w-full object-contain"
          />
        )}

        <button
          onClick={goPrev}
          className="absolute left-0 top-0 bottom-0 w-[30%] flex items-center justify-start pl-2"
        >
          {(chainEnabled && groupIndex > 0) || index > 0 ? (
            <FiChevronLeft size={32} className="text-white/50 drop-shadow-lg" />
          ) : null}
        </button>
        <button onClick={goNext} className="absolute right-0 top-0 bottom-0 w-[70%]" />
      </div>

      {/* Bottom: user info + like count + share */}
      <div className="px-4 pt-4 flex items-center gap-3">
        <img
          src={
            current.user?.avatar_url ||
            `https://ui-avatars.com/api/?name=${current.user?.username || "?"}&background=6366F1&color=fff`
          }
          alt=""
          className="w-9 h-9 rounded-full object-cover ring-2 ring-white/20"
        />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-white truncate">
            {current.user?.username}
            {current.user?.is_verified && (
              <img
                src="/images/vibeflow_verified2.png"
                alt=""
                className="inline w-4 h-4 ml-1 -mt-0.5"
              />
            )}
          </p>
          <p className="text-xs text-white/60">{formatTime(current.inserted_at)}</p>
        </div>
        {likesCount > 0 && (
          <span className="text-xs text-white/50 flex items-center gap-1">
            <FiHeart size={12} className="fill-coral-500 text-coral-500" />
            {likesCount}
          </span>
        )}
        <button
          onClick={() => setShowShareModal(true)}
          className="text-white/70 hover:text-white p-2"
        >
          <FiShare2 size={18} />
        </button>
      </div>

      {current.caption && (
        <div className="px-4 pb-2">
          <p className="text-sm text-white/90">{current.caption}</p>
        </div>
      )}

      {current.music_track && (
        <div className="px-4 pb-2 flex items-center gap-2">
          <div className="flex items-end gap-0.5 h-4">
            {[1,2,3,4,5].map((i) => (
              <div
                key={i}
                className="w-0.5 bg-white rounded-full animate-pulse"
                style={{
                  height: `${40 + Math.random() * 60}%`,
                  animationDelay: `${i * 0.1}s`,
                  animationDuration: "0.8s",
                }}
              />
            ))}
          </div>
          <div className="min-w-0">
            <p className="text-xs font-medium text-white truncate">{current.music_track.title}</p>
            <p className="text-[10px] text-white/50 truncate">{current.music_track.artist}</p>
          </div>
        </div>
      )}

      {/* DM reply input */}
      <div className="px-4 pb-6 flex items-center gap-2">
        <input
          type="text"
          value={messageText}
          onChange={(e) => setMessageText(e.target.value)}
          placeholder="Send a message..."
          className="flex-1 bg-white/10 text-white text-sm rounded-full px-4 py-2 outline-none placeholder-white/40"
          onKeyDown={(e) => e.key === "Enter" && handleSendDM()}
        />
        <button
          onClick={handleSendDM}
          disabled={!messageText.trim() || sending}
          className="text-white/70 hover:text-white p-2 disabled:opacity-30"
        >
          <FiSend size={18} />
        </button>
      </div>

      {/* Share modal */}
      {showShareModal && (
        <div
          className="fixed inset-0 z-[60] bg-black/60 flex items-end sm:items-center justify-center"
          onClick={() => setShowShareModal(false)}
        >
          <div
            className="bg-gray-900 w-full sm:max-w-md rounded-t-2xl sm:rounded-2xl p-4 max-h-[70vh] flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-white font-semibold text-lg mb-3">Share wave</h3>
            <input
              type="text"
              value={shareSearch}
              onChange={(e) => handleShareSearch(e.target.value)}
              placeholder="Search users..."
              className="w-full bg-white/10 text-white text-sm rounded-lg px-4 py-2 outline-none placeholder-white/40 mb-3"
              autoFocus
            />
            <div className="flex-1 overflow-y-auto space-y-1">
              {shareResults.length === 0 && shareSearch.trim() === "" ? (
                <p className="text-white/40 text-sm text-center py-8">
                  Type a name to search
                </p>
              ) : shareResults.length === 0 ? (
                <p className="text-white/40 text-sm text-center py-8">
                  No users found
                </p>
              ) : (
                shareResults.map((u) => (
                  <button
                    key={u.id}
                    onClick={() => handleShare(u.username)}
                    disabled={sharing}
                    className="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-white/10 transition-colors disabled:opacity-50"
                  >
                    <img
                      src={
                        u.avatar_url ||
                        `https://ui-avatars.com/api/?name=${u.username}&background=6366F1&color=fff`
                      }
                      alt=""
                      className="w-10 h-10 rounded-full object-cover"
                    />
                    <span className="text-white text-sm font-medium">{u.username}</span>
                  </button>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
