import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { FiHeart, FiMessageCircle, FiRepeat, FiBookmark, FiMoreHorizontal, FiSend, FiX, FiSearch } from "react-icons/fi";
import { useAuth } from "../context/AuthContext";
import { joinChannel, onChannel } from "../utils/realtime";
import api from "../utils/api";
import MediaCarousel from "./MediaCarousel";

function formatTime(dateStr) {
  if (!dateStr) return "";
  const normalized = dateStr.endsWith("Z") || dateStr.includes("+") ? dateStr : dateStr + "Z";
  const d = new Date(normalized);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return d.toLocaleDateString();
}

export default function PostCard({ post, onLike: externalOnLike }) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [liked, setLiked] = useState(post.is_liked || false);
  const [likesCount, setLikesCount] = useState(post.likes_count || 0);
  const [reposted, setReposted] = useState(post.is_reposted || false);
  const [repostsCount, setRepostsCount] = useState(post.reposts_count || 0);
  const [saved, setSaved] = useState(post.is_saved || false);
  const [savesCount, setSavesCount] = useState(post.saves_count || 0);
  const [commentsCount, setCommentsCount] = useState(post.comments_count || 0);
  const [seedCount] = useState(post.seed_count || 0);
  const [rippledCount] = useState(post.rippled_count || 0);
  const [showShareModal, setShowShareModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [shareRecipients, setShareRecipients] = useState([]);
  const [searchResults, setSearchResults] = useState([]);
  const [following, setFollowing] = useState([]);
  const [sharing, setSharing] = useState(false);

  useEffect(() => {
    setLiked(post.is_liked || false);
    setLikesCount(post.likes_count || 0);
    setReposted(post.is_reposted || false);
    setRepostsCount(post.reposts_count || 0);
    setSaved(post.is_saved || false);
    setSavesCount(post.saves_count || 0);
    setCommentsCount(post.comments_count || 0);
  }, [post.uuid, post.is_liked, post.likes_count, post.reposts_count, post.saves_count, post.comments_count]);

  useEffect(() => {
    joinChannel("relay:feed", {});
    const handler = (payload) => {
      if (String(payload.post_id) === String(post.id)) {
        if (payload.user_id === user?.id) return;
        setLikesCount((c) => (payload.unliked ? Math.max(0, c - 1) : c + 1));
      }
    };
    onChannel("relay:feed", "post_liked", handler);
    onChannel("relay:feed", "post_unliked", (p) => handler({ ...p, unliked: true }));
    onChannel("relay:feed", "new_comment", (p) => {
      if (p.post_id === post.id) {
        setCommentsCount((c) => c + 1);
      }
    });
    onChannel("relay:feed", "repost_added", (p) => {
      if (String(p.post_id) === String(post.id)) {
        if (p.user_id === user?.id) return;
        setRepostsCount((c) => c + 1);
      }
    });
    onChannel("relay:feed", "unreposted", (p) => {
      if (String(p.post_id) === String(post.id)) {
        setRepostsCount((c) => Math.max(0, c - 1));
      }
    });
    onChannel("relay:feed", "post_saved", (p) => {
      if (String(p.post_id) === String(post.id)) {
        if (p.user_id === user?.id) return;
        setSavesCount((c) => c + 1);
      }
    });
    onChannel("relay:feed", "post_unsaved", (p) => {
      if (String(p.post_id) === String(post.id)) {
        if (p.user_id === user?.id) return;
        setSavesCount((c) => Math.max(0, c - 1));
      }
    });
  }, [post.id, user?.id]);

  const handleLike = async () => {
    if (!user) { navigate("/login"); return; }
    setLiked(!liked);
    setLikesCount((c) => (liked ? c - 1 : c + 1));
    try {
      await api.post(`/posts/${post.uuid}/like`);
    } catch {
      setLiked(liked);
      setLikesCount((c) => (liked ? c + 1 : c - 1));
    }
    externalOnLike?.(post.uuid);
  };

  const handleRepost = async () => {
    if (!user) { navigate("/login"); return; }
    const wasReposted = reposted;
    setReposted(!wasReposted);
    setRepostsCount((c) => (wasReposted ? c - 1 : c + 1));
    try {
      const res = await api.post(`/posts/${post.uuid}/repost`);
      const isReposted = res.data?.data?.reposted;
      if (isReposted !== !wasReposted) {
        setReposted(isReposted);
        setRepostsCount((c) => (isReposted ? c + 1 : c - 1));
      }
    } catch {
      setReposted(wasReposted);
      setRepostsCount((c) => (wasReposted ? c + 1 : c - 1));
    }
  };

  const handleSave = async () => {
    if (!user) { navigate("/login"); return; }
    const wasSaved = saved;
    setSaved(!wasSaved);
    setSavesCount((c) => (wasSaved ? c - 1 : c + 1));
    try {
      const res = await api.post(`/posts/${post.uuid}/save`);
      const isSaved = res.data?.data?.saved;
      if (isSaved !== !wasSaved) {
        setSaved(isSaved);
        setSavesCount((c) => (isSaved ? c + 1 : c - 1));
      }
    } catch {
      setSaved(wasSaved);
      setSavesCount((c) => (wasSaved ? c + 1 : c - 1));
    }
  };

  const handleShareSearch = async (q) => {
    setSearchQuery(q);
    if (!q.trim()) { setSearchResults([]); return; }
    try {
      const res = await api.get("/users/search", { params: { q: q.trim() } });
      setSearchResults((res.data.data?.users || []).filter((u) => u.id !== user?.id));
    } catch { setSearchResults([]); }
  };

  const openShareModal = async () => {
    setShowShareModal(true);
    setSearchQuery("");
    setShareRecipients([]);
    setSearchResults([]);
    try {
      const res = await api.get(`/users/${user.username}/following`);
      setFollowing((res.data.data?.users || []).filter((u) => u.id !== user?.id));
    } catch { setFollowing([]); }
  };

  const toggleRecipient = (u) => {
    setShareRecipients((prev) =>
      prev.some((r) => r.id === u.id) ? prev.filter((r) => r.id !== u.id) : [...prev, u]
    );
  };

  const handleShare = async () => {
    if (shareRecipients.length === 0) return;
    setSharing(true);
    try {
      await api.post(`/posts/${post.uuid}/share`, {
        recipient_ids: shareRecipients.map((r) => r.id),
      });
      setShowShareModal(false);
      setShareRecipients([]);
      setSearchQuery("");
      setFollowing([]);
    } catch {}
    setSharing(false);
  };

  return (
    <>
      <div className="group bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm hover:shadow-md hover:border-tide-200 dark:hover:border-tide-700/50 transition-all duration-200 overflow-hidden">
        <div className="h-1 bg-gradient-to-r from-tide-500 via-flow-500 to-coral-500 opacity-0 group-hover:opacity-100 transition-opacity" />

        <div className="p-4 sm:p-5">
          <div className="flex items-center gap-3 mb-3">
            <Link to={`/profile/${post.user?.username}`} className="shrink-0">
                  <div className="relative">
                <img
                  src={post.user?.avatar_url || `https://ui-avatars.com/api/?name=${post.user?.username || "?"}&background=6366F1&color=fff&bold=true`}
                  alt={post.user?.username}
                  className="w-10 h-10 rounded-full object-cover ring-2 ring-white dark:ring-gray-800"
                />
              </div>
            </Link>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <Link
                  to={`/profile/${post.user?.username}`}
                  className="font-semibold text-sm hover:text-tide-600 transition-colors truncate"
                >
                  {post.user?.username}
                </Link>
                {post.user?.is_verified && (
                  <img src="/images/vibeflow_verified2.png" alt="Verified" className="inline w-4 h-4 ml-0.5 -mt-0.5" />
                )}
                {post.category && (
                  <span className="text-[11px] font-medium text-tide-500 bg-tide-50 dark:bg-tide-900/30 px-2 py-0.5 rounded-full shrink-0">
                    {post.category}
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-400">{formatTime(post.inserted_at)}</p>
            </div>
            <button className="text-gray-300 hover:text-gray-500 dark:hover:text-gray-400 transition-colors p-1">
              <FiMoreHorizontal size={16} />
            </button>
          </div>

          {post.media_files?.length > 0 && (
            <div className="mb-3 rounded-xl overflow-hidden border border-gray-100 dark:border-gray-700/50">
              <MediaCarousel files={post.media_files} />
            </div>
          )}
          <Link to={`/posts/${post.uuid}`} className="block">
            <h3 className="font-bold text-base sm:text-lg mb-1.5 leading-snug text-gray-900 dark:text-gray-100">
              {post.title}
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-3 line-clamp-3 leading-relaxed">
              {post.content}
            </p>
          </Link>

          {post.tags?.length > 0 && (
            <div className="flex gap-1.5 flex-wrap mb-3">
              {post.tags.map((tag) => (
                <Link
                  key={tag}
                  to={`/tags/${tag}`}
                  className="text-xs font-medium text-tide-600 dark:text-tide-400 bg-tide-50 dark:bg-tide-900/20 hover:bg-tide-100 dark:hover:bg-tide-900/40 px-2 py-0.5 rounded-full transition-colors"
                >
                  #{tag}
                </Link>
              ))}
            </div>
          )}

          {/* Ripple / Seed Info */}
          {seedCount > 0 && (
            <div className="flex items-center gap-2 mb-3 px-3 py-2 bg-gradient-to-r from-tide-50/50 to-flow-50/50 dark:from-tide-900/10 dark:to-flow-900/10 rounded-xl border border-tide-100/50 dark:border-tide-800/30">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4 text-tide-400 shrink-0">
                <path d="M15.75 8.25a.75.75 0 01.75.75c0 2.123-.707 3.924-1.548 5.116-.43.611-1.073 1.137-1.864 1.481-.463.201-.959.338-1.492.416l.463 1.654a.75.75 0 01-1.436.46l-.5-1.788a.75.75 0 01.478-.93 5.25 5.25 0 003.597-4.82.75.75 0 01.75-.75h.802zM4.5 8.25a.75.75 0 00-.75.75c0 2.123.707 3.924 1.548 5.116.43.611 1.073 1.137 1.864 1.481.463.201.959.338 1.492.416l-.463 1.654a.75.75 0 001.436.46l.5-1.788a.75.75 0 00-.478-.93 5.25 5.25 0 01-3.597-4.82.75.75 0 00-.75-.75H4.5z" />
              </svg>
              <span className="text-xs font-medium text-tide-600 dark:text-tide-400">
                <strong className="font-bold">{rippledCount}</strong>/{seedCount} ripples
              </span>
              <div className="flex-1 h-1.5 rounded-full bg-tide-100 dark:bg-tide-900/40 overflow-hidden max-w-[80px]">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-tide-400 to-flow-500 transition-all duration-500"
                  style={{ width: `${seedCount > 0 ? (rippledCount / seedCount) * 100 : 0}%` }}
                />
              </div>
            </div>
          )}

          <div className="flex items-center justify-between pt-2 border-t border-gray-100 dark:border-gray-700/50">
            <div className="flex items-center gap-1 sm:gap-3">
              <button
                onClick={handleLike}
                className={`flex items-center gap-1.5 text-sm font-medium px-3 py-1.5 rounded-full transition-all duration-200 ${
                  liked
                    ? "text-coral-500 bg-coral-50 dark:bg-coral-900/20 hover:bg-coral-100 dark:hover:bg-coral-900/30"
                    : "text-gray-500 dark:text-gray-400 hover:text-coral-500 hover:bg-coral-50 dark:hover:bg-coral-900/10"
                }`}
              >
                <FiHeart className={liked ? "fill-current" : ""} size={16} />
                {likesCount > 0 && <span>{likesCount}</span>}
              </button>

              <Link
                to={`/posts/${post.uuid}`}
                className="flex items-center gap-1.5 text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-tide-500 hover:bg-tide-50 dark:hover:bg-tide-900/10 px-3 py-1.5 rounded-full transition-all duration-200"
              >
                <FiMessageCircle size={16} />
                {commentsCount > 0 && <span>{commentsCount}</span>}
              </Link>

              <button
                onClick={handleRepost}
                className={`flex items-center gap-1.5 text-sm font-medium px-3 py-1.5 rounded-full transition-all duration-200 ${
                  reposted
                    ? "text-green-500 bg-green-50 dark:bg-green-900/20 hover:bg-green-100 dark:hover:bg-green-900/30"
                    : "text-gray-500 dark:text-gray-400 hover:text-green-500 hover:bg-green-50 dark:hover:bg-green-900/10"
                }`}
              >
                <FiRepeat size={16} className={reposted ? "fill-current" : ""} />
                {repostsCount > 0 && <span>{repostsCount}</span>}
              </button>

              {user && (
                <button
                  onClick={openShareModal}
                  className="flex items-center gap-1.5 text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-tide-500 hover:bg-tide-50 dark:hover:bg-tide-900/10 px-3 py-1.5 rounded-full transition-all duration-200"
                >
                  <FiSend size={15} />
                </button>
              )}
            </div>

            <button
              onClick={handleSave}
              className={`flex items-center gap-1.5 text-sm font-medium px-3 py-1.5 rounded-full transition-all duration-200 ${
                saved
                  ? "text-sun-500 bg-sun-50 dark:bg-sun-900/20 hover:bg-sun-100 dark:hover:bg-sun-900/30"
                  : "text-gray-400 dark:text-gray-500 hover:text-sun-500 hover:bg-sun-50 dark:hover:bg-sun-900/10"
              }`}
            >
              <FiBookmark size={16} className={saved ? "fill-current" : ""} />
              {savesCount > 0 && <span>{savesCount}</span>}
            </button>
          </div>
        </div>
      </div>

      {/* Share Modal */}
      {showShareModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4 py-10 text-center">
            <div className="fixed inset-0 bg-black/50 backdrop-blur-sm" onClick={() => { setShowShareModal(false); setShareRecipients([]); setSearchQuery(""); setFollowing([]); }} />
            <div className="relative bg-white dark:bg-zinc-900 rounded-2xl shadow-xl w-full max-w-md p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-gray-900 dark:text-white">Share Post</h3>
                <button onClick={() => { setShowShareModal(false); setShareRecipients([]); setSearchQuery(""); setFollowing([]); }} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"><FiX size={20} /></button>
              </div>

              <div className="relative mb-4">
                <FiSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => handleShareSearch(e.target.value)}
                  placeholder="Search users to share with..."
                  className="w-full pl-10 pr-4 py-2.5 bg-gray-100 dark:bg-zinc-800 border border-gray-200 dark:border-zinc-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-tide-500/50 placeholder-gray-400"
                />
              </div>

              {shareRecipients.length > 0 && (
                <div className="flex flex-wrap gap-2 mb-4">
                  {shareRecipients.map((r) => (
                    <span key={r.id} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-tide-100 dark:bg-tide-900/30 text-tide-700 dark:text-tide-300 rounded-full text-sm font-medium">
                      {r.username}
                      <button onClick={() => toggleRecipient(r)} className="hover:text-tide-900 dark:hover:text-tide-100"><FiX size={14} /></button>
                    </span>
                  ))}
                </div>
              )}

              <div className="max-h-52 overflow-y-auto space-y-1 mb-4">
                {!searchQuery.trim() && following.length > 0 && (
                  <p className="px-3 py-1.5 text-xs font-semibold text-gray-400 uppercase tracking-wider">Following</p>
                )}
                {(searchQuery.trim() ? searchResults : following).map((u) => (
                  <button
                    key={u.id}
                    onClick={() => toggleRecipient(u)}
                    className={`flex items-center gap-3 w-full px-3 py-2.5 rounded-xl text-left transition ${
                      shareRecipients.some((r) => r.id === u.id)
                        ? "bg-tide-50 dark:bg-tide-900/20 ring-1 ring-tide-300 dark:ring-tide-700"
                        : "hover:bg-gray-50 dark:hover:bg-zinc-800"
                    }`}
                  >
                    <img src={u.avatar_url || `https://ui-avatars.com/api/?name=${u.username}&background=6366F1&color=fff`} alt="" className="w-9 h-9 rounded-full object-cover" />
                    <div className="flex-1 text-left">
                      <p className="text-sm font-medium text-gray-900 dark:text-gray-100">{u.username}</p>
                      {u.bio && <p className="text-xs text-gray-500 line-clamp-1">{u.bio}</p>}
                    </div>
                    {shareRecipients.some((r) => r.id === u.id) && (
                      <svg className="w-5 h-5 text-tide-600" fill="currentColor" viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" /></svg>
                    )}
                  </button>
                ))}
                {!searchQuery.trim() && following.length === 0 && (
                  <p className="text-sm text-gray-400 text-center py-4">You are not following anyone yet</p>
                )}
                {searchQuery.trim() && searchResults.length === 0 && (
                  <p className="text-sm text-gray-400 text-center py-4">No users found</p>
                )}
              </div>

              <button
                onClick={handleShare}
                disabled={shareRecipients.length === 0 || sharing}
                className="w-full py-3 rounded-xl bg-gradient-to-r from-tide-600 to-flow-600 text-white text-sm font-bold uppercase tracking-wide shadow-lg shadow-tide-600/25 hover:shadow-tide-600/40 disabled:opacity-50 disabled:cursor-not-allowed transition"
              >
                {sharing ? "Sharing..." : `Share with ${shareRecipients.length} friend${shareRecipients.length !== 1 ? "s" : ""}`}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
