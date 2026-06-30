import { useState, useEffect, useCallback } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import api from "../../utils/api";
import { useAuth } from "../../context/AuthContext";
import { useTheme } from "../../context/ThemeContext";
import {
  FiGrid, FiHeart, FiMessageCircle, FiPlay, FiBookmark, FiX,
  FiCalendar, FiUsers, FiUserCheck, FiCamera, FiSend, FiShield
} from "react-icons/fi";

const USERNAME_STYLES = {
  "neon-green": { color: "#16a34a", textShadow: "0 0 4px rgba(34,197,94,0.3), 0 0 8px rgba(34,197,94,0.2)" },
  "neon-blue": { color: "#2563eb", textShadow: "0 0 4px rgba(59,130,246,0.3), 0 0 8px rgba(59,130,246,0.2)" },
  "neon-coral": { color: "#db2777", textShadow: "0 0 4px rgba(236,72,153,0.3), 0 0 8px rgba(236,72,153,0.2)" },
  "font-serif": { fontFamily: '"Cinzel", serif', color: "#d97706", textShadow: "0 0 4px rgba(251,191,36,0.3)" },
  "font-mono": { fontFamily: '"JetBrains Mono", monospace', color: "#475569", textShadow: "0 0 4px rgba(148,163,184,0.3)" },
  "font-grotesk": { fontFamily: '"Space Grotesk", sans-serif', color: "#7c3aed", textShadow: "0 0 4px rgba(167,139,250,0.3)" },
};

const DARK_USERNAME_STYLES = {
  "neon-green": { color: "#86efac", textShadow: "0 0 5px rgba(7,100,41,0.6), 0 0 10px rgba(34,197,94,0.4)" },
  "neon-blue": { color: "#217ce4", textShadow: "0 0 5px rgba(59,130,246,0.6), 0 0 10px rgba(59,130,246,0.4)" },
  "neon-coral": { color: "#f9a8d4", textShadow: "0 0 5px rgba(236,72,153,0.6), 0 0 10px rgba(236,72,153,0.4)" },
  "font-serif": { fontFamily: '"Cinzel", serif', color: "#fde68a", textShadow: "0 0 6px rgba(251,191,36,0.5)" },
  "font-mono": { fontFamily: '"JetBrains Mono", monospace', color: "#e2e8f0", textShadow: "0 0 6px rgba(148,163,184,0.5)" },
  "font-grotesk": { fontFamily: '"Space Grotesk", sans-serif', color: "#ddd6fe", textShadow: "0 0 6px rgba(167,139,250,0.5)" },
};

function formatDate(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr.endsWith("Z") ? dateStr : dateStr + "Z");
  return d.toLocaleDateString("en-US", { year: "numeric", month: "short" });
}

function linkifyText(text) {
  if (!text) return text;
  const urlRegex = /(https?:\/\/[^\s<]+|www\.[^\s<]+)/gi;
  const parts = text.split(urlRegex);
  return parts.map((part, i) => {
    if (part.match(urlRegex)) {
      const href = part.startsWith("http") ? part : "https://" + part;
      return (
        <a key={i} href={href} target="_blank" rel="noopener noreferrer" className="text-tide-600 hover:text-tide-700 underline underline-offset-2">
          {part}
        </a>
      );
    }
    return part;
  });
}

function SocialIcon({ platform }) {
  const cls = "w-5 h-5";
  switch (platform) {
    case "youtube":
      return <svg viewBox="0 0 24 24" fill="currentColor" className={cls}><path d="M23.5 6.2a3.1 3.1 0 0 0-2.2-2.2C19.3 3.5 12 3.5 12 3.5s-7.3 0-9.3.5A3.1 3.1 0 0 0 .5 6.2 32.7 32.7 0 0 0 0 12a32.7 32.7 0 0 0 .5 5.8 3.1 3.1 0 0 0 2.2 2.2c2 .5 9.3.5 9.3.5s7.3 0 9.3-.5a3.1 3.1 0 0 0 2.2-2.2A32.7 32.7 0 0 0 24 12a32.7 32.7 0 0 0-.5-5.8zM9.6 15.5V8.5l6.4 3.5-6.4 3.5z" /></svg>;
    case "instagram":
      return <svg viewBox="0 0 24 24" fill="currentColor" className={cls}><path d="M7 3h10a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V7a4 4 0 0 1 4-4zm10 2H7a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2zm-5 3.5a3.5 3.5 0 1 1 0 7 3.5 3.5 0 0 1 0-7zm5.3-.8a1 1 0 1 1-2 0 1 1 0 0 1 2 0z" /></svg>;
    case "x":
      return <svg viewBox="0 0 24 24" fill="currentColor" className={cls}><path d="M18.9 2H22l-7.2 8.2L23 22h-6.6l-5.2-6.8L4.7 22H1.6l7.7-8.8L1 2h6.7l4.7 6.2L18.9 2zm-1.2 18h1.8L7.2 4H5.3l12.4 16z" /></svg>;
    case "twitch":
      return <svg viewBox="0 0 24 24" fill="currentColor" className={cls}><path d="M4 3h16v10l-4 4h-4l-2 2H8v-2H4V3zm2 2v10h4v2l2-2h4l2-2V5H6zm5 3h2v4h-2V8zm4 0h2v4h-2V8z" /></svg>;
    case "tiktok":
      return <svg viewBox="0 0 24 24" fill="currentColor" className={cls}><path d="M15 3c.5 2.1 2.1 3.7 4.2 4.1V10a7.1 7.1 0 0 1-4.2-1.5v7.1a5.6 5.6 0 1 1-5.6-5.6c.4 0 .8 0 1.1.1v2.9a2.6 2.6 0 1 0 2.5 2.6V3h2z" /></svg>;
    case "discord":
      return <svg viewBox="0 0 24 24" fill="currentColor" className={cls}><path d="M20 5.3A16 16 0 0 0 15.9 4l-.2.5a14 14 0 0 1 3.5 1.3 13 13 0 0 0-9.4 0A14 14 0 0 1 13.3 4l-.2-.5A16 16 0 0 0 4 5.3a16.9 16.9 0 0 0-2 11.3 16 16 0 0 0 4.9 2.5l1-1.6a10.6 10.6 0 0 1-2.2-1.1c.2.1.4.3.6.4a12.1 12.1 0 0 0 11.4 0l.6-.4c-.7.4-1.4.8-2.2 1.1l1 1.6a16 16 0 0 0 4.9-2.5A16.9 16.9 0 0 0 20 5.3zM9.4 14.3c-1 0-1.8-.9-1.8-2s.8-2 1.8-2 1.8.9 1.8 2-.8 2-1.8 2zm5.2 0c-1 0-1.8-.9-1.8-2s.8-2 1.8-2 1.8.9 1.8 2-.8 2-1.8 2z" /></svg>;
    default:
      return <span className="text-xs font-bold uppercase">{platform?.charAt(0) || "?"}</span>;
  }
}

function PostGridCard({ post }) {
  const firstMedia = post.media_files?.[0];
  const isVideo = firstMedia?.type === "video" || firstMedia?.url?.match(/\.(mp4|mov|webm)$/i);

  return (
    <Link
      to={`/posts/${post.uuid}`}
      className="group relative aspect-square overflow-hidden rounded-2xl bg-gray-100 dark:bg-zinc-800 border border-gray-200/50 dark:border-zinc-700/50 shadow-sm hover:shadow-xl transition-all duration-300 hover:-translate-y-1 hover:border-tide-300 dark:hover:border-tide-700"
    >
      {firstMedia?.url ? (
        <>
          {isVideo ? (
            <>
              <video src={firstMedia.url} muted playsInline preload="metadata" className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
              <div className="absolute top-2.5 right-2.5 w-7 h-7 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center shadow-lg">
                <FiPlay size={13} className="text-white ml-0.5" />
              </div>
            </>
          ) : (
            <img src={firstMedia.url} alt="" loading="lazy" className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
          )}
        </>
      ) : (
        <div className="w-full h-full flex items-center justify-center p-4 bg-gradient-to-br from-gray-50 to-white dark:from-zinc-800 dark:to-zinc-900">
          <p className="text-xs font-medium text-gray-400 dark:text-gray-500 line-clamp-4 italic leading-relaxed text-center">"{post.content}"</p>
        </div>
      )}
      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-end justify-center pb-4 gap-6">
        <span className="flex items-center gap-1.5 text-white text-sm font-semibold drop-shadow-md">
          <FiHeart size={16} fill="white" /> {post.likes_count || 0}
        </span>
        <span className="flex items-center gap-1.5 text-white text-sm font-semibold drop-shadow-md">
          <FiMessageCircle size={16} fill="white" /> {post.comments_count || 0}
        </span>
      </div>
    </Link>
  );
}

export default function UserProfile() {
  const { username } = useParams();
  const { user: currentUser } = useAuth();
  const [profile, setProfile] = useState(null);
  const [posts, setPosts] = useState([]);
  const [savedPosts, setSavedPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("posts");
  const { theme } = useTheme();
  const isDark = theme === "dark";
  const [showVerificationModal, setShowVerificationModal] = useState(false);
  const [socialPlatform, setSocialPlatform] = useState("youtube");
  const [socialUsername, setSocialUsername] = useState("");
  const [pendingVerification, setPendingVerification] = useState(false);
  const [socialAccounts, setSocialAccounts] = useState([]);
  const [hasWaves, setHasWaves] = useState(false);
  const [showFollowersModal, setShowFollowersModal] = useState(false);
  const [showFollowingModal, setShowFollowingModal] = useState(false);
  const [followers, setFollowers] = useState([]);
  const [following, setFollowing] = useState([]);

  const loadProfile = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get(`/users/${username}`);
      setProfile(res.data.data);
      setPosts(res.data.data.posts || []);
      if (currentUser?.username === username) {
        const saved = await api.get("/users/saved-posts");
        setSavedPosts(saved.data.data.posts || []);
        const ver = await api.get("/users/verification-status");
        setPendingVerification(ver.data.data.pending);
      }
      const wavesRes = await api.get(`/waves/${username}`);
      setHasWaves((wavesRes.data.data?.waves || []).length > 0);
    } catch {}
    setLoading(false);
  }, [username, currentUser]);

  useEffect(() => { loadProfile(); }, [loadProfile]);

  const loadFollowModal = async (type) => {
    try {
      const res = await api.get(`/users/${username}/${type}`);
      if (type === "followers") {
        setFollowers(res.data.data.users || []);
        setShowFollowersModal(true);
      } else {
        setFollowing(res.data.data.users || []);
        setShowFollowingModal(true);
      }
    } catch {}
  };

  const navigate = useNavigate();

  const openVerificationModal = async () => {
    setShowVerificationModal(true);
    try {
      const res = await api.get("/users/social-accounts");
      setSocialAccounts(res.data.data?.accounts || []);
    } catch {}
  };

  const handleFollow = async () => {
    try {
      const res = await api.post(`/users/${username}/follow`);
      const following = res.data?.data?.following;
      if (following) setProfile((prev) => prev ? { ...prev, is_following: prev.is_following || true } : prev);
      loadProfile();
    } catch {}
  };

  if (loading) {
    return (
      <div className="flex justify-center py-24">
        <div className="relative w-10 h-10">
          <div className="absolute inset-0 rounded-full border-[3px] border-tide-100 dark:border-tide-900/30" />
          <div className="absolute inset-0 rounded-full border-[3px] border-tide-500 border-t-transparent animate-spin" />
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="text-center py-24">
        <div className="w-16 h-16 mx-auto rounded-2xl bg-gray-100 dark:bg-zinc-800 flex items-center justify-center mb-4">
          <FiUsers size={24} className="text-gray-400" />
        </div>
        <p className="text-gray-500 text-lg font-medium">User not found</p>
      </div>
    );
  }

  const u = profile.user;
  const isOwn = currentUser?.username === username;
  const styleMap = isDark ? DARK_USERNAME_STYLES : USERNAME_STYLES;
  const currentStyle = styleMap[u.username_style || "neon-green"] || styleMap["neon-green"];

  return (
    <div className="max-w-5xl mx-auto px-4 py-6 sm:py-8">
      {/* Cover Card */}
      <div className="relative mb-8 rounded-3xl overflow-hidden bg-gradient-to-br from-gray-50 to-white dark:from-zinc-900 dark:to-zinc-900/80 border border-gray-200/60 dark:border-zinc-800/60 shadow-lg shadow-black/5 dark:shadow-black/20">
        <div className="h-28 sm:h-36 bg-gradient-to-r from-tide-500/80 via-flow-500/80 to-coral-500/80 relative overflow-hidden">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white/20 via-transparent to-transparent" />
          <div className="absolute -top-12 -right-12 w-48 h-48 bg-white/10 rounded-full blur-3xl" />
          <div className="absolute -bottom-8 -left-8 w-32 h-32 bg-black/5 rounded-full blur-2xl" />
        </div>

        <div className="px-5 sm:px-8 pb-6">
          {/* Avatar — overlaps cover */}
          <div className="flex flex-col sm:flex-row sm:items-end gap-4 -mt-12 sm:-mt-16 mb-5">
            <div className="relative shrink-0">
              <div className={`w-24 h-24 sm:w-28 sm:h-28 rounded-full p-0.5 shadow-xl ${
                hasWaves
                  ? "bg-gradient-to-br from-tide-400 via-flow-400 to-coral-400 animate-pulse shadow-tide-300/50 dark:shadow-tide-700/50"
                  : "bg-gradient-to-br from-tide-300 to-flow-300 dark:from-tide-500 dark:to-flow-500"
              }`}>
                <div className="w-full h-full rounded-full overflow-hidden bg-white dark:bg-zinc-900 ring-2 ring-white dark:ring-zinc-900">
                  {u.avatar_url ? (
                    <img src={u.avatar_url} alt={u.username} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full bg-gradient-to-br from-tide-100 to-tide-200 dark:from-tide-900 dark:to-zinc-800 flex items-center justify-center text-tide-600 dark:text-tide-400 font-bold text-3xl">
                      {u.username?.charAt(0).toUpperCase() || "?"}
                    </div>
                  )}
                </div>
              </div>
              {hasWaves && (
                <div className="absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full bg-gradient-to-br from-flow-500 to-coral-500 flex items-center justify-center shadow-lg shadow-flow-500/40 border-2 border-white dark:border-zinc-900">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-2.5 h-2.5 text-white">
                    <path d="M15.75 8.25a.75.75 0 01.75.75c0 2.123-.707 3.924-1.548 5.116-.43.611-1.073 1.137-1.864 1.481-.463.201-.959.338-1.492.416l.463 1.654a.75.75 0 01-1.436.46l-.5-1.788a.75.75 0 01.478-.93 5.25 5.25 0 003.597-4.82.75.75 0 01.75-.75h.802zM4.5 8.25a.75.75 0 00-.75.75c0 2.123.707 3.924 1.548 5.116.43.611 1.073 1.137 1.864 1.481.463.201.959.338 1.492.416l-.463 1.654a.75.75 0 001.436.46l.5-1.788a.75.75 0 00-.478-.93 5.25 5.25 0 01-3.597-4.82.75.75 0 00-.75-.75H4.5z" />
                  </svg>
                </div>
              )}
            </div>

            <div className="flex-1 min-w-0 pt-2 sm:pt-14">
              <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight inline-flex items-center gap-2" style={currentStyle}>
                  {u.username}
                  {u.is_verified && (
                    <img src="/images/vibeflow_verified2.png" alt="Verified" className="h-6 w-6 sm:h-7 sm:w-7 drop-shadow-lg shrink-0" />
                  )}
                </h1>
                <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-zinc-800 border border-gray-200/50 dark:border-zinc-700/50">
                  <FiCalendar size={11} />
                  {formatDate(u.inserted_at)}
                </span>
              </div>

              {/* Stats row */}
              <div className="flex items-center gap-0 mt-2.5">
                <button onClick={() => loadFollowModal("followers")} className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-zinc-800 transition text-sm">
                  <span className="font-bold text-gray-900 dark:text-white">{u.followers_count || 0}</span>
                  <span className="text-gray-500 dark:text-gray-400">Followers</span>
                </button>
                <span className="w-px h-4 bg-gray-200 dark:bg-zinc-700" />
                <button onClick={() => loadFollowModal("following")} className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-zinc-800 transition text-sm">
                  <span className="font-bold text-gray-900 dark:text-white">{u.following_count || 0}</span>
                  <span className="text-gray-500 dark:text-gray-400">Following</span>
                </button>
                <span className="w-px h-4 bg-gray-200 dark:bg-zinc-700" />
                <span className="flex items-center gap-1.5 px-3 py-1.5 text-sm">
                  <span className="font-bold text-gray-900 dark:text-white">{posts.length}</span>
                  <span className="text-gray-500 dark:text-gray-400">Posts</span>
                </span>
              </div>
            </div>
          </div>

          {/* Bio + Points Row */}
          <div className="flex flex-col sm:flex-row sm:items-start gap-4 mb-5">
            <div className="flex-1">
              {u.bio ? (
                <div className="relative pl-4 border-l-2 border-tide-400/50 dark:border-tide-500/50">
                  <p className="text-sm text-gray-600 dark:text-gray-300 leading-relaxed">{linkifyText(u.bio)}</p>
                </div>
              ) : isOwn ? (
                <div className="p-3 bg-amber-50/80 dark:bg-amber-900/15 backdrop-blur-sm rounded-2xl border border-amber-200/50 dark:border-amber-800/50 flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center shrink-0">
                    <FiCamera size={14} className="text-amber-600 dark:text-amber-400" />
                  </div>
                  <div className="flex-1">
                    <p className="text-sm text-amber-800 dark:text-amber-200 font-medium">No bio yet</p>
                    <Link to="/settings" className="text-xs text-amber-600 dark:text-amber-400 hover:underline font-semibold">Add one →</Link>
                  </div>
                </div>
              ) : null}
            </div>
            {isOwn && u.points > 0 && (
              <span className="shrink-0 inline-flex items-center gap-1.5 px-3.5 py-2 bg-gradient-to-r from-sun-50 to-amber-50 dark:from-sun-900/20 dark:to-amber-900/20 rounded-xl border border-sun-200/60 dark:border-sun-800/50 text-sm font-bold text-sun-800 dark:text-sun-200 shadow-sm">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4 text-sun-500"><path d="M7.5 6v.75H5.513c-.96 0-1.764.724-1.86 1.679l-1.263 12A1.875 1.875 0 004.25 22.5h15.5a1.875 1.875 0 001.86-2.071l-1.263-12a1.875 1.875 0 00-1.86-1.679H16.5V6a4.5 4.5 0 10-9 0zM12 3a3 3 0 00-3 3v.75h6V6a3 3 0 00-3-3zm-3 8.25a.75.75 0 100 1.5.75.75 0 000-1.5zm7.5.75a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"/></svg>
                {u.points.toLocaleString()} pts
              </span>
            )}
          </div>

          {/* Actions */}
          <div className="flex flex-wrap items-center gap-2.5 pt-2 border-t border-gray-100 dark:border-zinc-800">
            <Link to="/wave-store" className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-tide-600 to-flow-700 text-white text-sm font-semibold rounded-xl shadow-lg shadow-tide-600/25 hover:shadow-tide-600/40 hover:-translate-y-0.5 active:scale-[0.98] transition-all">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
                <path fillRule="evenodd" d="M7.5 6v.75H5.513c-.96 0-1.764.724-1.86 1.679l-1.263 12A1.875 1.875 0 004.25 22.5h15.5a1.875 1.875 0 001.86-2.071l-1.263-12a1.875 1.875 0 00-1.86-1.679H16.5V6a4.5 4.5 0 10-9 0zM12 3a3 3 0 00-3 3v.75h6V6a3 3 0 00-3-3zm-3 8.25a.75.75 0 100 1.5.75.75 0 000-1.5zm7.5.75a.75.75 0 11-1.5 0 .75.75 0 011.5 0z" clipRule="evenodd" />
              </svg>
              Wave Store
            </Link>

            {isOwn ? (
              <>
                <Link to="/settings" className="inline-flex items-center gap-2 px-4 py-2 bg-white dark:bg-zinc-800 text-gray-700 dark:text-gray-200 text-sm font-semibold rounded-xl border border-gray-200 dark:border-zinc-700 shadow-sm hover:bg-gray-50 dark:hover:bg-zinc-700 hover:border-tide-200 dark:hover:border-tide-800 transition-all">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4"><path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125" /></svg>
                  Edit Profile
                </Link>
                {!u.is_verified && (
                  pendingVerification ? (
                    <span className="inline-flex items-center gap-2 px-4 py-2 bg-gray-100 dark:bg-zinc-800 text-gray-400 dark:text-zinc-500 text-sm font-semibold rounded-xl border border-gray-200 dark:border-zinc-700 cursor-not-allowed">
                      <svg className="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
                      Pending
                    </span>
                  ) : (
                    <button onClick={openVerificationModal} className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-blue-600 to-blue-700 text-white text-sm font-semibold rounded-xl shadow-lg shadow-blue-600/25 hover:shadow-blue-600/40 hover:-translate-y-0.5 active:scale-[0.98] transition-all">
                      <FiShield size={14} />
                      Get Verified
                    </button>
                  )
                )}
                <Link to={`/users/${u.username}/creator-hub`} className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-violet-600 to-flow-600 hover:from-violet-700 hover:to-flow-700 text-white text-sm font-semibold rounded-xl shadow-lg shadow-violet-600/25 hover:shadow-violet-600/40 hover:-translate-y-0.5 active:scale-[0.98] transition-all">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4"><path d="M18.75 12.75h1.5a.75.75 0 000-1.5h-1.5a.75.75 0 000 1.5zM12 6a.75.75 0 01.75.75v6.75a.75.75 0 01-1.5 0V6.75A.75.75 0 0112 6zM12 18a.75.75 0 100-1.5.75.75 0 000 1.5z" /><path fillRule="evenodd" d="M3 8a3 3 0 013-3h12a3 3 0 013 3v8a3 3 0 01-3 3H6a3 3 0 01-3-3V8zm3-1.5h12A1.5 1.5 0 0119.5 8v8a1.5 1.5 0 01-1.5 1.5H6A1.5 1.5 0 014.5 16V8A1.5 1.5 0 016 6.5z" clipRule="evenodd" /></svg>
                  Creative Hub
                </Link>
              </>
            ) : currentUser ? (
              <>
                <button onClick={handleFollow} className={`inline-flex items-center gap-2 px-5 py-2.5 text-sm font-semibold rounded-xl transition-all shadow-sm ${
                  profile.is_following
                    ? "bg-white dark:bg-zinc-800 text-gray-700 dark:text-gray-200 border border-gray-200 dark:border-zinc-700 hover:border-coral-200 hover:bg-coral-50 hover:text-coral-600 dark:hover:bg-coral-900/20 dark:hover:text-coral-400"
                    : "bg-gradient-to-r from-tide-600 to-flow-600 text-white hover:from-tide-700 hover:to-flow-700 shadow-lg shadow-tide-600/25 hover:shadow-tide-600/40 hover:-translate-y-0.5 active:scale-[0.98]"
                }`}>
                  <FiUserCheck size={15} />
                  {profile.is_following ? "Following" : "Follow"}
                </button>
                <button onClick={() => navigate(`/chat?user=${username}`)} className="inline-flex items-center gap-2 px-5 py-2.5 bg-white dark:bg-zinc-800 text-gray-700 dark:text-gray-200 text-sm font-semibold rounded-xl border border-gray-200 dark:border-zinc-700 shadow-sm hover:bg-gray-50 dark:hover:bg-zinc-700 hover:border-tide-200 dark:hover:border-tide-800 transition-all">
                  <FiSend size={14} />
                  Message
                </button>
              </>
            ) : null}
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-0 mb-6 border-b border-gray-200 dark:border-zinc-800">
        {[
          { key: "posts", icon: FiGrid, label: "Posts" },
          ...(isOwn ? [{ key: "saved", icon: FiBookmark, label: "Saved" }] : []),
        ].map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex items-center gap-2 px-5 py-3 text-sm font-semibold border-b-2 transition-all ${
              activeTab === tab.key
                ? "border-tide-500 text-tide-600 dark:text-tide-400"
                : "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
            }`}
          >
            <tab.icon size={15} />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Posts / Saved Grid */}
      {activeTab === "posts" ? (
        posts.length === 0 ? (
          <div className="rounded-3xl border-2 border-dashed border-gray-200 dark:border-zinc-700 py-20 flex flex-col items-center justify-center text-center bg-white/50 dark:bg-zinc-900/50">
            <div className="w-16 h-16 bg-gray-100 dark:bg-zinc-800 rounded-2xl flex items-center justify-center mb-4">
              <FiCamera size={24} className="text-gray-300 dark:text-gray-600" />
            </div>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white">No Posts Yet</h3>
            <p className="text-gray-400 text-sm mt-1">When you post, they will appear here.</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {posts.map((post) => <PostGridCard key={post.uuid} post={post} />)}
          </div>
        )
      ) : (
        savedPosts.length === 0 ? (
          <div className="rounded-3xl border-2 border-dashed border-gray-200 dark:border-zinc-700 py-20 flex flex-col items-center justify-center text-center bg-white/50 dark:bg-zinc-900/50">
            <div className="w-16 h-16 bg-gray-100 dark:bg-zinc-800 rounded-2xl flex items-center justify-center mb-4">
              <FiBookmark size={24} className="text-gray-300 dark:text-gray-600" />
            </div>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white">No Saved Posts</h3>
            <p className="text-gray-400 text-sm mt-1">Posts you save will appear here.</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {savedPosts.map((post) => (
              <div key={post.uuid} className="relative">
                <div className="absolute top-2.5 left-2.5 z-10 w-7 h-7 rounded-full bg-tide-500/80 backdrop-blur-sm flex items-center justify-center shadow-lg">
                  <FiBookmark size={12} className="text-white" />
                </div>
                <PostGridCard post={post} />
              </div>
            ))}
          </div>
        )
      )}

      {/* Verification Modal */}
      {showVerificationModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4 py-10 text-center">
            <div className="fixed inset-0 bg-slate-950/70 backdrop-blur-sm" onClick={() => setShowVerificationModal(false)} />
            <div className="relative inline-block align-middle text-left w-full max-w-3xl">
              <div className="rounded-3xl border border-slate-800/60 bg-gradient-to-br from-slate-900 via-slate-900 to-slate-950 shadow-2xl shadow-blue-900/40 overflow-hidden">
                <div className="absolute inset-0 opacity-30 pointer-events-none">
                  <div className="absolute -top-32 -left-32 h-72 w-72 rounded-full bg-blue-500/20 blur-3xl" />
                  <div className="absolute -bottom-40 -right-32 h-80 w-80 rounded-full bg-tide-500/20 blur-3xl" />
                </div>
                <div className="relative px-8 py-7">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <h3 className="text-sm tracking-[0.3em] text-slate-400 font-semibold">VERIFICATION REQUEST</h3>
                      <p className="mt-2 text-sm text-slate-400">Link your social accounts and submit for verification.</p>
                    </div>
                    <button onClick={() => setShowVerificationModal(false)} className="text-slate-500 hover:text-slate-300 transition-colors"><FiX className="h-5 w-5" /></button>
                  </div>
                  <div className="mt-7 grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                      <h4 className="text-xs font-semibold text-blue-300 tracking-wider uppercase">Add Social Account</h4>
                      <div className="mt-3 grid grid-cols-3 gap-3">
                        {["youtube", "instagram", "x", "twitch", "tiktok", "discord"].map((p) => (
                          <button key={p} onClick={() => setSocialPlatform(p)} className={`h-16 rounded-xl border text-xs font-semibold uppercase tracking-wide transition-all ${
                            socialPlatform === p
                              ? "border-blue-500/80 bg-blue-500/10 text-blue-200 shadow-[0_0_18px_-6px_rgba(59,130,246,0.8)]"
                              : "border-slate-800 bg-slate-900/60 text-slate-400 hover:text-slate-200 hover:border-slate-700"
                          }`}>
                            <span className="flex flex-col items-center justify-center gap-1">
                              <span className={`w-5 h-5 ${socialPlatform === p ? "text-blue-300" : "text-slate-500"}`}><SocialIcon platform={p} /></span>
                              <span className="block text-[10px]">{p.toUpperCase()}</span>
                            </span>
                          </button>
                        ))}
                      </div>
                      <div className="mt-5">
                        <label className="block text-xs font-semibold text-slate-400 tracking-wider uppercase mb-2">Username</label>
                        <div className="flex items-center rounded-xl border border-slate-800 bg-slate-900/70 overflow-hidden">
                          <span className="px-3 py-2.5 text-xs text-slate-500 bg-slate-950/60 border-r border-slate-800">@{socialPlatform}/</span>
                          <input type="text" value={socialUsername} onChange={(e) => setSocialUsername(e.target.value)} placeholder="username" className="w-full px-3 py-2.5 text-sm bg-transparent text-slate-200 placeholder-slate-600 focus:outline-none" />
                        </div>
                      </div>
                      <div className="mt-5">
                        <button onClick={async () => { try { await api.post("/users/social-accounts", { platform: socialPlatform, username: socialUsername }); setSocialUsername(""); openVerificationModal(); } catch {} }} className="w-full py-3 rounded-xl dark:bg-white bg-white text-slate-900 text-sm font-bold uppercase tracking-wide shadow-lg shadow-black/20 hover:brightness-110 transition">+ Add Link</button>
                      </div>
                    </div>
                    <div>
                      <h4 className="text-xs font-semibold text-blue-300 tracking-wider uppercase">Linked Accounts</h4>
                      <div className="mt-4 rounded-2xl border border-slate-800 bg-slate-900/60 p-4 min-h-[240px]">
                        {socialAccounts.length === 0 ? (
                          <div className="h-full flex flex-col items-center justify-center text-slate-600 text-sm">
                            <svg className="h-8 w-8 text-slate-700 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 13a5 5 0 007.07 0l2.12-2.12a5 5 0 10-7.07-7.07L10 6" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 11a5 5 0 00-7.07 0L4.81 13.12a5 5 0 107.07 7.07L14 18" /></svg>
                            No accounts linked yet
                          </div>
                        ) : (
                          <div className="space-y-3">
                            {socialAccounts.map((s) => (
                              <div key={s.id} className="flex items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2">
                                <div className="min-w-0">
                                  <p className="text-xs font-semibold uppercase tracking-wide text-slate-300">{s.platform}</p>
                                  <p className="text-xs text-slate-500 truncate">{s.url}</p>
                                </div>
                                <button onClick={async () => { try { await api.delete(`/users/social-accounts/${s.id}`); openVerificationModal(); } catch {} }} className="text-xs text-red-400 hover:text-red-300 font-semibold">Remove</button>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                      <div className="mt-4">
                        <button onClick={async () => { try { await api.post("/users/verify"); setShowVerificationModal(false); setPendingVerification(true); } catch {} }} className="w-full py-3 rounded-xl bg-slate-800 text-slate-400 text-sm font-bold uppercase tracking-wide border border-slate-700 hover:bg-slate-700 hover:text-slate-200 transition">Submit Request</button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Followers / Following Modals */}
      {showFollowersModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4 py-10 text-center">
            <div className="fixed inset-0 bg-black/50 backdrop-blur-sm" onClick={() => setShowFollowersModal(false)} />
            <div className="relative bg-white dark:bg-zinc-900 rounded-2xl shadow-xl w-full max-w-md p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-gray-900 dark:text-white">Followers</h3>
                <button onClick={() => setShowFollowersModal(false)} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"><FiX size={20} /></button>
              </div>
              {followers.length === 0 ? (
                <p className="text-gray-500 text-center py-8 text-sm">No followers yet</p>
              ) : (
                <div className="space-y-3 max-h-96 overflow-y-auto">
                  {followers.map((f) => (
                    <Link key={f.id} to={`/profile/${f.username}`} onClick={() => setShowFollowersModal(false)} className="flex items-center gap-3 p-2 rounded-xl hover:bg-gray-50 dark:hover:bg-zinc-800 transition">
                      <img src={f.avatar_url || `https://ui-avatars.com/api/?name=${f.username}&background=6366F1&color=fff&bold=true`} alt="" className="w-10 h-10 rounded-full object-cover" />
                      <div>
                        <p className="font-semibold text-sm text-gray-900 dark:text-white">{f.username}</p>
                        {f.bio && <p className="text-xs text-gray-500 truncate max-w-[250px]">{f.bio}</p>}
                      </div>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {showFollowingModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4 py-10 text-center">
            <div className="fixed inset-0 bg-black/50 backdrop-blur-sm" onClick={() => setShowFollowingModal(false)} />
            <div className="relative bg-white dark:bg-zinc-900 rounded-2xl shadow-xl w-full max-w-md p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-gray-900 dark:text-white">Following</h3>
                <button onClick={() => setShowFollowingModal(false)} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"><FiX size={20} /></button>
              </div>
              {following.length === 0 ? (
                <p className="text-gray-500 text-center py-8 text-sm">Not following anyone yet</p>
              ) : (
                <div className="space-y-3 max-h-96 overflow-y-auto">
                  {following.map((f) => (
                    <Link key={f.id} to={`/profile/${f.username}`} onClick={() => setShowFollowingModal(false)} className="flex items-center gap-3 p-2 rounded-xl hover:bg-gray-50 dark:hover:bg-zinc-800 transition">
                      <img src={f.avatar_url || `https://ui-avatars.com/api/?name=${f.username}&background=6366F1&color=fff&bold=true`} alt="" className="w-10 h-10 rounded-full object-cover" />
                      <div>
                        <p className="font-semibold text-sm text-gray-900 dark:text-white">{f.username}</p>
                        {f.bio && <p className="text-xs text-gray-500 truncate max-w-[250px]">{f.bio}</p>}
                      </div>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
