import { useState, useEffect, useCallback } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import api from "../../utils/api";
import { useAuth } from "../../context/AuthContext";
import { joinChannel, onChannel } from "../../utils/realtime";
import {
  FiHeart, FiMessageCircle, FiRepeat, FiBookmark, FiSend,
  FiArrowLeft, FiMoreVertical, FiEdit2, FiTrash2,
  FiCheck, FiX, FiSearch
} from "react-icons/fi";
import MediaCarousel from "../../components/MediaCarousel";

const PinIcon = () => (
  <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor" stroke="none">
    <path d="M16 12V4h1V2H7v2h1v8l-2 2v2h5.2v6h1.6v-6H18v-2l-2-2z" />
  </svg>
);

function formatTime(dateStr) {
  if (!dateStr) return "";
  const normalized = dateStr.endsWith("Z") || dateStr.includes("+") ? dateStr : dateStr + "Z";
  const d = new Date(normalized);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return d.toLocaleDateString();
}

export default function PostDetail() {
  const { uuid } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [post, setPost] = useState(null);
  const [loading, setLoading] = useState(true);
  const [errorType, setErrorType] = useState(null);
  const [commentText, setCommentText] = useState("");
  const [sending, setSending] = useState(false);
  const [editingCommentId, setEditingCommentId] = useState(null);
  const [editText, setEditText] = useState("");
  const [menuOpenId, setMenuOpenId] = useState(null);

  const [showShareModal, setShowShareModal] = useState(false);
  const [shareRecipients, setShareRecipients] = useState([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [following, setFollowing] = useState([]);
  const [sharing, setSharing] = useState(false);

  const [isFollowing, setIsFollowing] = useState(false);
  const [followLoading, setFollowLoading] = useState(false);

  const loadPost = useCallback(async () => {
    try {
      const res = await api.get(`/posts/${uuid}`);
      const p = res.data.data.post;
      setPost(p);
      setIsFollowing(p.is_following || false);
      api.post(`/posts/${uuid}/view`).catch(() => {});
    } catch (err) {
      if (err.response?.status === 401) setErrorType("auth");
      else setErrorType("not_found");
    }
    setLoading(false);
  }, [uuid]);

  useEffect(() => {
    loadPost();
  }, [loadPost]);

  useEffect(() => {
    if (!post) return;
    joinChannel(`relay:post:${uuid}`, {});

    const onLike = (p) => {
      if (p.user_id === user?.id) return;
      setPost((prev) => prev ? { ...prev, likes_count: prev.likes_count + 1 } : prev);
    };
    const onUnlike = (p) => {
      if (p.user_id === user?.id) return;
      setPost((prev) => prev ? { ...prev, likes_count: Math.max(0, prev.likes_count - 1) } : prev);
    };
    const onRepost = (p) => {
      if (p.user_id === user?.id) return;
      setPost((prev) => prev ? { ...prev, reposts_count: prev.reposts_count + 1 } : prev);
    };
    const onUnrepost = (p) => {
      setPost((prev) => prev ? { ...prev, reposts_count: Math.max(0, prev.reposts_count - 1) } : prev);
    };
    const onSave = (p) => {
      if (p.user_id === user?.id) return;
      setPost((prev) => prev ? { ...prev, saves_count: prev.saves_count + 1 } : prev);
    };
    const onUnsave = (p) => {
      if (p.user_id === user?.id) return;
      setPost((prev) => prev ? { ...prev, saves_count: Math.max(0, prev.saves_count - 1) } : prev);
    };

    onChannel(`relay:post:${uuid}`, "post_liked", onLike);
    onChannel(`relay:post:${uuid}`, "post_unliked", onUnlike);
    onChannel(`relay:post:${uuid}`, "repost_added", onRepost);
    onChannel(`relay:post:${uuid}`, "unreposted", onUnrepost);
    onChannel(`relay:post:${uuid}`, "post_saved", onSave);
    onChannel(`relay:post:${uuid}`, "post_unsaved", onUnsave);

    onChannel(`relay:post:${uuid}`, "new_comment", (c) => {
      setPost((prev) => {
        if (!prev) return prev;
        if (prev.comments?.some((x) => x.id === c.id)) return prev;
        return {
          ...prev,
          comments: [...(prev.comments || []), c],
          comments_count: prev.comments_count + 1,
        };
      });
    });

    onChannel(`relay:post:${uuid}`, "comment_updated", (c) => {
      setPost((prev) => {
        if (!prev) return prev;
        return {
          ...prev,
          comments: prev.comments?.map((x) => x.id === c.id ? { ...x, content: c.content } : x),
        };
      });
    });

    onChannel(`relay:post:${uuid}`, "comment_pinned", (c) => {
      setPost((prev) => {
        if (!prev) return prev;
        return {
          ...prev,
          comments: prev.comments?.map((x) => ({ ...x, pinned: x.id === c.id })),
        };
      });
    });

    onChannel(`relay:post:${uuid}`, "comment_deleted", (c) => {
      setPost((prev) => {
        if (!prev) return prev;
        return {
          ...prev,
          comments: prev.comments?.filter((x) => x.id !== c.id),
          comments_count: Math.max(0, prev.comments_count - 1),
        };
      });
    });
  }, [uuid, user?.id]);

  const handleComment = async (e) => {
    e.preventDefault();
    if (!commentText.trim()) return;
    if (!user) { navigate("/login"); return; }
    setSending(true);
    try {
      const res = await api.post(`/posts/${uuid}/comments`, {
        comment: { content: commentText },
      });
      const newComment = res.data.data.comment;
      setPost((prev) => ({
        ...prev,
        comments: [...(prev.comments || []), newComment],
        comments_count: (prev.comments_count || 0) + 1,
      }));
      setCommentText("");
    } catch {}
    setSending(false);
  };

  const toggleLike = async () => {
    if (!user) { navigate("/login"); return; }
    const was = post.is_liked;
    setPost((prev) => ({
      ...prev,
      is_liked: !was,
      likes_count: was ? prev.likes_count - 1 : prev.likes_count + 1,
    }));
    try {
      await api.post(`/posts/${uuid}/like`);
    } catch {
      setPost((prev) => ({
        ...prev,
        is_liked: was,
        likes_count: was ? prev.likes_count + 1 : prev.likes_count - 1,
      }));
    }
  };

  const toggleRepost = async () => {
    if (!user) { navigate("/login"); return; }
    const was = post.is_reposted;
    setPost((prev) => ({
      ...prev,
      is_reposted: !was,
      reposts_count: was ? prev.reposts_count - 1 : prev.reposts_count + 1,
    }));
    try {
      const res = await api.post(`/posts/${uuid}/repost`);
      const isReposted = res.data?.data?.reposted;
      if (isReposted !== !was) {
        setPost((prev) => ({
          ...prev,
          is_reposted: isReposted,
          reposts_count: isReposted ? prev.reposts_count + 1 : prev.reposts_count - 1,
        }));
      }
    } catch {
      setPost((prev) => ({
        ...prev,
        is_reposted: was,
        reposts_count: was ? prev.reposts_count + 1 : prev.reposts_count - 1,
      }));
    }
  };

  const toggleSave = async () => {
    if (!user) { navigate("/login"); return; }
    const was = post.is_saved;
    setPost((prev) => ({
      ...prev,
      is_saved: !was,
      saves_count: was ? prev.saves_count - 1 : prev.saves_count + 1,
    }));
    try {
      const res = await api.post(`/posts/${uuid}/save`);
      const isSaved = res.data?.data?.saved;
      if (isSaved !== !was) {
        setPost((prev) => ({
          ...prev,
          is_saved: isSaved,
          saves_count: isSaved ? prev.saves_count + 1 : prev.saves_count - 1,
        }));
      }
    } catch {
      setPost((prev) => ({
        ...prev,
        is_saved: was,
        saves_count: was ? prev.saves_count + 1 : prev.saves_count - 1,
      }));
    }
  };

  const handleFollow = async () => {
    if (!user) { navigate("/login"); return; }
    if (followLoading) return;
    setFollowLoading(true);
    const username = post.user?.username;
    try {
      if (isFollowing) {
        await api.delete(`/users/${username}/follow`);
        setIsFollowing(false);
      } else {
        await api.post(`/users/${username}/follow`);
        setIsFollowing(true);
      }
    } catch {}
    setFollowLoading(false);
  };

  const openShareModal = async () => {
    if (!user) { navigate("/login"); return; }
    setShowShareModal(true);
    setSearchQuery("");
    setShareRecipients([]);
    setSearchResults([]);
    try {
      const res = await api.get(`/users/${user.username}/following`);
      setFollowing((res.data.data?.users || []).filter((u) => u.id !== user?.id));
    } catch { setFollowing([]); }
  };

  const handleShareSearch = async (q) => {
    setSearchQuery(q);
    if (!q.trim()) { setSearchResults([]); return; }
    try {
      const res = await api.get("/users/search", { params: { q: q.trim() } });
      setSearchResults((res.data.data?.users || []).filter((u) => u.id !== user?.id));
    } catch { setSearchResults([]); }
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
      await api.post(`/posts/${uuid}/share`, {
        recipient_ids: shareRecipients.map((r) => r.id),
      });
      setShowShareModal(false);
      setShareRecipients([]);
      setSearchQuery("");
      setFollowing([]);
    } catch {}
    setSharing(false);
  };

  const handlePinComment = async (commentId) => {
    try {
      await api.post(`/comments/${commentId}/pin`);
    } catch {}
  };

  const handleDeleteComment = async (commentId) => {
    try {
      await api.delete(`/comments/${commentId}`);
      setPost((prev) => ({
        ...prev,
        comments: prev.comments?.filter((c) => c.id !== commentId),
        comments_count: Math.max(0, prev.comments_count - 1),
      }));
    } catch {}
  };

  const handleCommentLike = async (commentId, wasLiked) => {
    if (!user) { navigate("/login"); return; }
    setPost((prev) => ({
      ...prev,
      comments: prev.comments?.map((c) =>
        c.id === commentId
          ? { ...c, is_liked: !wasLiked, likes_count: wasLiked ? c.likes_count - 1 : c.likes_count + 1 }
          : c
      ),
    }));
    try {
      await api.post(`/comments/${commentId}/like`);
    } catch {
      setPost((prev) => ({
        ...prev,
        comments: prev.comments?.map((c) =>
          c.id === commentId
            ? { ...c, is_liked: wasLiked, likes_count: wasLiked ? c.likes_count + 1 : c.likes_count - 1 }
            : c
        ),
      }));
    }
  };

  const startEdit = (comment) => {
    setEditingCommentId(comment.id);
    setEditText(comment.content);
    setMenuOpenId(null);
  };

  const cancelEdit = () => {
    setEditingCommentId(null);
    setEditText("");
  };

  const submitEdit = async (commentId) => {
    if (!editText.trim()) return;
    try {
      const res = await api.put(`/comments/${commentId}`, {
        comment: { content: editText },
      });
      const updated = res.data.data.comment;
      setPost((prev) => ({
        ...prev,
        comments: prev.comments?.map((c) => c.id === commentId ? updated : c),
      }));
      setEditingCommentId(null);
      setEditText("");
    } catch {}
  };

  const isPostOwner = user && post && user.id === post.user?.id;
  const sortedComments = post?.comments
    ? [...post.comments].sort((a, b) => {
        if (b.pinned !== a.pinned) return (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
        return new Date(b.inserted_at) - new Date(a.inserted_at);
      })
    : [];

  if (loading) {
    return (
      <div className="flex justify-center py-16">
        <div className="animate-spin rounded-full h-8 w-8 border-[3px] border-tide-500 border-t-transparent" />
      </div>
    );
  }

  if (!post) {
    return (
      <div className="text-center py-16 px-4">
        {errorType === "auth" ? (
          <>
            <p className="text-gray-500 text-lg mb-2">Please log in to view this post</p>
            <button onClick={() => navigate("/login")} className="text-tide-600 hover:underline text-sm font-medium">
              Log in
            </button>
          </>
        ) : (
          <>
            <p className="text-gray-500 text-lg mb-2">Post not found</p>
            <Link to="/feed" className="text-tide-600 hover:underline text-sm">Back to feed</Link>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950">
      {/* Mobile Header */}
      <div className="lg:hidden bg-white dark:bg-gray-900 px-4 py-3 flex items-center border-b border-gray-200 dark:border-gray-800 sticky top-0 z-20">
        <Link to="/feed" className="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 mr-3">
          <FiArrowLeft size={20} />
        </Link>
        <span className="text-sm font-semibold text-gray-900 dark:text-white">Post</span>
      </div>

      <div className="max-w-3xl mx-auto px-0 lg:px-6 py-0 lg:py-8">
        {/* Back Button (Desktop) */}
        <Link to="/feed" className="hidden lg:inline-flex items-center gap-1.5 text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 mb-6 transition-colors">
          <FiArrowLeft size={16} /> Back to feed
        </Link>

        {/* Post Card */}
        <div className="bg-white dark:bg-gray-900 lg:rounded-3xl lg:shadow-lg lg:border border-gray-100 dark:border-gray-800 overflow-hidden">
          {/* Gradient accent */}
          <div className="h-1 bg-gradient-to-r from-tide-500 via-flow-500 to-coral-500" />

          {/* Media */}
          {post.media_files?.length > 0 && (
            <div className="bg-black">
              <MediaCarousel files={post.media_files} />
            </div>
          )}

          <div className="p-5 sm:p-7 lg:p-8">
            {/* User Header */}
            <div className="flex items-center justify-between mb-6">
              <Link to={`/profile/${post.user?.username}`} className="flex items-center gap-3 group">
                <div className="relative">
                  <img
                    src={post.user?.avatar_url || `https://ui-avatars.com/api/?name=${post.user?.username || "?"}&background=6366F1&color=fff&bold=true`}
                    alt={post.user?.username}
                    className="w-11 h-11 rounded-full object-cover ring-2 ring-white dark:ring-gray-800 group-hover:ring-tide-300 transition-all"
                  />
                </div>
                <div>
                  <div className="flex items-center gap-1.5">
                    <span className="font-semibold text-gray-900 dark:text-white group-hover:text-tide-600 dark:group-hover:text-tide-400 transition-colors">
                      {post.user?.username}
                    </span>
                    {post.user?.is_verified && (
                      <img src="/images/vibeflow_verified2.png" alt="Verified" className="inline w-4 h-4" />
                    )}
                  </div>
                  <p className="text-xs text-gray-400">{formatTime(post.inserted_at)}</p>
                </div>
              </Link>
              {user && user.id !== post.user?.id && (
                <button
                  onClick={handleFollow}
                  disabled={followLoading}
                  className={`shrink-0 px-4 py-1.5 rounded-full text-sm font-semibold transition-all ${
                    isFollowing
                        ? "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-coral-50 hover:text-coral-500 dark:hover:bg-coral-900/20 dark:hover:text-coral-400 border border-gray-200 dark:border-gray-700"
                      : "bg-tide-600 text-white hover:bg-tide-700 shadow-sm shadow-tide-200 dark:shadow-tide-900/30"
                  }`}
                  onMouseEnter={(e) => { if (isFollowing) e.target.textContent = "Unfollow"; }}
                  onMouseLeave={(e) => { if (isFollowing) e.target.textContent = "Following"; }}
                >
                  {isFollowing ? "Following" : "Follow"}
                </button>
              )}
            </div>

            {/* Title */}
            <h1 className="text-2xl sm:text-3xl font-bold mb-3 leading-tight text-gray-900 dark:text-gray-100">
              {post.title}
            </h1>

            {/* Tags */}
            {post.tags?.length > 0 && (
              <div className="flex gap-2 flex-wrap mb-4">
                {post.tags.map((tag) => (
                  <Link
                    key={tag}
                    to={`/tags/${tag}`}
                    className="text-xs font-semibold text-tide-600 dark:text-tide-400 bg-tide-50 dark:bg-tide-900/20 hover:bg-tide-100 dark:hover:bg-tide-900/40 px-2.5 py-1 rounded-full transition-colors"
                  >
                    #{tag}
                  </Link>
                ))}
              </div>
            )}

            {/* Content */}
            <div className="text-gray-700 dark:text-gray-300 mb-6 whitespace-pre-wrap leading-relaxed text-sm sm:text-base">
              {post.content}
            </div>

            {/* Divider */}
            <div className="border-t border-gray-100 dark:border-gray-800 pt-4">
              {/* Action Buttons */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1 sm:gap-2">
                  <button
                    onClick={toggleLike}
                    className={`flex items-center gap-1.5 text-sm font-medium px-3 sm:px-4 py-2 rounded-xl transition-all ${
                      post.is_liked
                        ? "text-coral-500 bg-coral-50 dark:bg-coral-900/20"
                              : "text-gray-500 dark:text-gray-400 hover:text-coral-500 hover:bg-coral-50 dark:hover:bg-coral-900/10"
                    }`}
                  >
                    <FiHeart className={post.is_liked ? "fill-current" : ""} size={18} />
                    {post.likes_count > 0 && <span>{post.likes_count}</span>}
                  </button>

                  <button
                    onClick={toggleRepost}
                    className={`flex items-center gap-1.5 text-sm font-medium px-3 sm:px-4 py-2 rounded-xl transition-all ${
                      post.is_reposted
                        ? "text-green-500 bg-green-50 dark:bg-green-900/20"
                        : "text-gray-500 dark:text-gray-400 hover:text-green-500 hover:bg-green-50 dark:hover:bg-green-900/10"
                    }`}
                  >
                    <FiRepeat size={18} className={post.is_reposted ? "fill-current" : ""} />
                    {post.reposts_count > 0 && <span>{post.reposts_count}</span>}
                  </button>

                  <button
                    onClick={openShareModal}
                    className="flex items-center gap-1.5 text-sm font-medium px-3 sm:px-4 py-2 rounded-xl text-gray-500 dark:text-gray-400 hover:text-tide-500 hover:bg-tide-50 dark:hover:bg-tide-900/10 transition-all"
                  >
                    <FiSend size={18} />
                  </button>

                  <button
                    onClick={toggleSave}
                    className={`flex items-center gap-1.5 text-sm font-medium px-3 sm:px-4 py-2 rounded-xl transition-all ${
                      post.is_saved
                        ? "text-sun-500 bg-sun-50 dark:bg-sun-900/20"
                        : "text-gray-500 dark:text-gray-400 hover:text-sun-500 hover:bg-sun-50 dark:hover:bg-sun-900/10"
                    }`}
                  >
                    <FiBookmark size={18} className={post.is_saved ? "fill-current" : ""} />
                    {post.saves_count > 0 && <span>{post.saves_count}</span>}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Comments Section */}
        <div className="bg-white dark:bg-gray-900 lg:rounded-3xl lg:shadow-lg lg:border border-gray-100 dark:border-gray-800 overflow-hidden mt-4 lg:mt-6">
          {/* Comments Header */}
          <div className="px-5 sm:px-7 lg:px-8 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center gap-2">
            <FiMessageCircle className="text-tide-500" size={16} />
            <h2 className="text-sm font-semibold text-gray-900 dark:text-white">Comments</h2>
            <span className="text-xs text-gray-400 ml-1">({post.comments_count})</span>
          </div>

          {/* Comment Input */}
          {user ? (
            <div className="px-5 sm:px-7 lg:px-8 py-4 border-b border-gray-100 dark:border-gray-800">
              <form onSubmit={handleComment} className="flex items-center gap-3">
                <img
                  src={user?.avatar_url || `https://ui-avatars.com/api/?name=${user?.username || "?"}&background=6366F1&color=fff&bold=true`}
                  alt=""
                  className="w-8 h-8 rounded-full object-cover shrink-0"
                />
                <div className="flex-1 flex items-center gap-2 bg-gray-50 dark:bg-gray-800 rounded-2xl px-4 py-2 border border-gray-100 dark:border-gray-700 focus-within:ring-2 focus-within:ring-tide-500/40 focus-within:border-tide-300 dark:focus-within:border-tide-600 transition-all">
                  <input
                    type="text"
                    value={commentText}
                    onChange={(e) => setCommentText(e.target.value)}
                    placeholder="Write a comment..."
                    className="flex-1 bg-transparent border-0 outline-none text-sm placeholder-gray-400 text-gray-900 dark:text-gray-100"
                  />
                  <button
                    type="submit"
                    disabled={sending || !commentText.trim()}
                    className="text-tide-600 hover:text-tide-700 disabled:text-gray-300 dark:disabled:text-gray-600 transition-colors shrink-0"
                  >
                    {sending ? (
                      <div className="animate-spin rounded-full h-4 w-4 border-2 border-tide-500 border-t-transparent" />
                    ) : (
                      <FiSend size={16} />
                    )}
                  </button>
                </div>
              </form>
            </div>
          ) : (
            <div className="px-5 sm:px-7 lg:px-8 py-4 border-b border-gray-100 dark:border-gray-800">
              <button onClick={() => navigate("/login")} className="w-full py-2.5 text-sm text-tide-600 font-medium text-center bg-gray-50 dark:bg-gray-800 rounded-2xl hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
                Log in to comment
              </button>
            </div>
          )}

          {/* Comments List */}
          <div className="divide-y divide-gray-100 dark:divide-gray-800">
            {sortedComments.length === 0 ? (
              <div className="text-center py-12 px-5 sm:px-7 lg:px-8">
                <FiMessageCircle className="mx-auto text-gray-200 dark:text-gray-700 mb-3" size={32} />
                <p className="text-gray-400 text-sm">No comments yet. Be the first to share your thoughts!</p>
              </div>
            ) : (
              sortedComments.map((comment) => {
                const isCommentOwner = user && user.id === comment.user?.id;
                const canDelete = isCommentOwner || isPostOwner;
                const isEditing = editingCommentId === comment.id;

                return (
                  <div key={comment.id} className={`px-5 sm:px-7 lg:px-8 py-4 ${comment.pinned ? "bg-tide-50/40 dark:bg-tide-900/10" : ""} hover:bg-gray-50/50 dark:hover:bg-gray-800/30 transition-all`}>
                    <div className="flex items-start gap-3">
                      <Link to={`/profile/${comment.user?.username}`} className="shrink-0">
                        <img
                          src={comment.user?.avatar_url || `https://ui-avatars.com/api/?name=${comment.user?.username || "?"}&background=6366F1&color=fff&bold=true`}
                          alt={comment.user?.username}
                          className="w-8 h-8 rounded-full object-cover mt-0.5"
                        />
                      </Link>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1.5 mb-1 flex-wrap">
                          <Link to={`/profile/${comment.user?.username}`} className="text-sm font-semibold text-gray-900 dark:text-gray-100 hover:text-tide-600 dark:hover:text-tide-400 transition-colors">
                            {comment.user?.username}
                          </Link>
                          {comment.user?.is_verified && (
                            <img src="/images/vibeflow_verified2.png" alt="Verified" className="inline w-3.5 h-3.5" />
                          )}
                          <span className="text-xs text-gray-400">{formatTime(comment.inserted_at)}</span>
                          {comment.pinned && (
                            <span className="flex items-center gap-1 text-[10px] font-medium text-tide-600 bg-tide-100 dark:bg-tide-900/30 px-1.5 py-0.5 rounded-full">
                              <PinIcon /> Pinned
                            </span>
                          )}
                        </div>

                        {isEditing ? (
                          <div className="flex gap-2 mt-1">
                            <input
                              type="text"
                              value={editText}
                              onChange={(e) => setEditText(e.target.value)}
                              className="flex-1 px-3 py-1.5 text-sm border border-gray-200 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-900 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-gray-900 dark:text-gray-100"
                              autoFocus
                            />
                            <button onClick={() => submitEdit(comment.id)} className="p-1.5 text-green-600 hover:bg-green-50 dark:hover:bg-green-900/20 rounded-lg transition"><FiCheck size={16} /></button>
                            <button onClick={cancelEdit} className="p-1.5 text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition"><FiX size={16} /></button>
                          </div>
                        ) : (
                          <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">{comment.content}</p>
                        )}
                        <div className="flex items-center gap-3 mt-2">
                          <button
                            onClick={() => handleCommentLike(comment.id, comment.is_liked)}
                            className={`flex items-center gap-1 text-xs font-medium transition-colors ${
                              comment.is_liked ? "text-coral-500" : "text-gray-400 hover:text-coral-500"
                            }`}
                          >
                            <FiHeart size={13} className={comment.is_liked ? "fill-current" : ""} />
                            {comment.likes_count > 0 && <span>{comment.likes_count}</span>}
                          </button>
                        </div>
                      </div>

                      {(isCommentOwner || canDelete) && !isEditing && (
                        <div className="relative shrink-0">
                          <button
                            onClick={() => setMenuOpenId(menuOpenId === comment.id ? null : comment.id)}
                            className="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition"
                          >
                            <FiMoreVertical size={15} />
                          </button>
                          {menuOpenId === comment.id && (
                            <>
                              <div className="fixed inset-0 z-10" onClick={() => setMenuOpenId(null)} />
                              <div className="absolute right-0 top-8 z-20 w-36 bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 shadow-xl py-1">
                                {isPostOwner && !comment.pinned && (
                                  <button onClick={() => { handlePinComment(comment.id); setMenuOpenId(null); }} className="flex items-center gap-2 w-full px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition text-left">
                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none" className="text-tide-500"><path d="M16 12V4h1V2H7v2h1v8l-2 2v2h5.2v6h1.6v-6H18v-2l-2-2z" /></svg>
                                    Pin comment
                                  </button>
                                )}
                                {isCommentOwner && (
                                  <button onClick={() => startEdit(comment)} className="flex items-center gap-2 w-full px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition text-left">
                                    <FiEdit2 size={14} className="text-blue-500" /> Edit
                                  </button>
                                )}
                                {canDelete && (
                                  <button onClick={() => { handleDeleteComment(comment.id); setMenuOpenId(null); }} className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition text-left">
                                    <FiTrash2 size={14} /> Delete
                                  </button>
                                )}
                              </div>
                            </>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                );
              })
            )}
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
    </div>
  );
}
