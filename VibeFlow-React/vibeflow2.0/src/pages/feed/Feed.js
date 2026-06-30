import { useState, useEffect, useCallback, useRef } from "react";
import { Link } from "react-router-dom";
import api from "../../utils/api";
import { useAuth } from "../../context/AuthContext";
import PostCard from "../../components/PostCard";
import { joinChannel, onChannel } from "../../utils/realtime";
import { FiSearch, FiTrendingUp, FiLoader, FiClock, FiUsers, FiX } from "react-icons/fi";

const CATEGORIES = [
  "Tech", "Drama", "Action", "Music", "Fitness", "Sports",
  "Science", "Fashion", "Food", "Politics", "Comedy", "Nature",
];

function SearchBar() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    const handler = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  useEffect(() => {
    if (!query.trim()) {
      setResults(null);
      setOpen(false);
      return;
    }
    const timer = setTimeout(async () => {
      setLoading(true);
      try {
        const [usersRes, postsRes] = await Promise.all([
          api.get("/users/search", { params: { q: query.trim() } }).catch(() => null),
          api.get("/feed/posts/search", { params: { q: query.trim() } }).catch(() => null),
        ]);
        setResults({
          users: usersRes?.data?.data?.users || [],
          posts: postsRes?.data?.data?.posts || [],
        });
        setOpen(true);
      } catch {}
      setLoading(false);
    }, 300);
    return () => clearTimeout(timer);
  }, [query]);

  return (
    <div ref={ref} className="relative w-full">
      <div className="relative">
        <FiSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => results && setOpen(true)}
          placeholder="Search users, tags, posts..."
          className="w-full pl-10 pr-4 py-2.5 bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-tide-500/50 focus:border-tide-500 placeholder-gray-400"
        />
        {query && (
          <button onClick={() => { setQuery(""); setResults(null); setOpen(false); }}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
            <FiX size={16} />
          </button>
        )}
        {loading && (
          <FiLoader className="absolute right-3 top-1/2 -translate-y-1/2 text-tide-500 animate-spin" size={16} />
        )}
      </div>

      {open && results && (
        <div className="absolute top-full mt-2 left-0 right-0 bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-xl shadow-black/5 z-50 max-h-[70vh] overflow-y-auto">
          {results.users.length === 0 && results.posts.length === 0 && (
            <div className="p-6 text-center text-sm text-gray-400">No results found</div>
          )}

          {results.users.length > 0 && (
            <div className="p-2">
              <p className="px-3 py-1.5 text-xs font-semibold text-gray-400 uppercase tracking-wider">Users</p>
              {results.users.map((u) => (
                <Link
                  key={u.id}
                  to={`/profile/${u.username}`}
                  onClick={() => { setOpen(false); setQuery(""); }}
                  className="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700/50 transition"
                >
                  <img
                    src={u.avatar_url || `https://ui-avatars.com/api/?name=${u.username}&background=6366F1&color=fff`}
                    alt=""
                    className="w-9 h-9 rounded-full object-cover"
                  />
                  <div>
                    <p className="text-sm font-medium text-gray-900 dark:text-gray-100">{u.username}</p>
                    {u.bio && <p className="text-xs text-gray-500 line-clamp-1">{u.bio}</p>}
                  </div>
                </Link>
              ))}
            </div>
          )}

          {results.posts.length > 0 && (
            <div className="p-2 border-t border-gray-100 dark:border-gray-700">
              <p className="px-3 py-1.5 text-xs font-semibold text-gray-400 uppercase tracking-wider">Posts</p>
              {results.posts.map((p) => (
                <Link
                  key={p.uuid}
                  to={`/posts/${p.uuid}`}
                  onClick={() => { setOpen(false); setQuery(""); }}
                  className="flex items-start gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700/50 transition"
                >
                  <img
                    src={p.user?.avatar_url || `https://ui-avatars.com/api/?name=${p.user?.username || "U"}&background=6366F1&color=fff`}
                    alt=""
                    className="w-8 h-8 mt-0.5 rounded-full object-cover shrink-0"
                  />
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-gray-900 dark:text-gray-100 line-clamp-1">
                      {p.title}
                    </p>
                    <p className="text-xs text-gray-500 line-clamp-2">{p.content}</p>
                    {p.tags?.length > 0 && (
                      <div className="flex gap-1 mt-1 flex-wrap">
                        {p.tags.slice(0, 3).map((t) => (
                          <span key={t} className="text-[10px] px-1.5 py-0.5 bg-tide-50 dark:bg-tide-900/20 text-tide-600 rounded">
                            #{t}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function Feed() {
  const { user } = useAuth();
  const [posts, setPosts] = useState([]);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [category, setCategory] = useState("");
  const [trending, setTrending] = useState([]);
  const [categoryCounts, setCategoryCounts] = useState([]);
  const [suggestions, setSuggestions] = useState({ users: [], posts: [] });
  const [waveGroups, setWaveGroups] = useState([]);
  const observer = useRef();

  const lastPostRef = useCallback(
    (node) => {
      if (loading) return;
      if (observer.current) observer.current.disconnect();
      observer.current = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting && hasMore) {
          setPage((p) => p + 1);
        }
      });
      if (node) observer.current.observe(node);
    },
    [loading, hasMore]
  );

  const fetchPosts = useCallback(
    async (pageNum) => {
      setLoading(true);
      try {
        const params = { page: pageNum, per_page: 20 };
        if (category) params.category = category;
        const res = await api.get("/feed", { params });
        const newPosts = res.data.data.posts;
        if (pageNum === 1) {
          setPosts(newPosts);
        } else {
          setPosts((prev) => [...prev, ...newPosts]);
        }
        setHasMore(newPosts.length === 20);
      } catch {}
      setLoading(false);
    },
    [category]
  );

  useEffect(() => {
    setPage(1);
    fetchPosts(1);
  }, [fetchPosts]);

  useEffect(() => {
    if (page > 1) fetchPosts(page);
  }, [page, fetchPosts]);

  useEffect(() => {
    joinChannel("relay:feed", {});
    onChannel("relay:feed", "new_post", (p) => {
      setPosts((prev) => {
        if (prev.some((x) => x.uuid === p.uuid)) return prev;
        return [{ ...p, likes_count: 0, comments_count: 0 }, ...prev];
      });
    });
    onChannel("relay:feed", "post_deleted", (p) => {
      setPosts((prev) => prev.filter((x) => x.uuid !== p.uuid));
    });
  }, []);

  useEffect(() => {
    api.get("/feed/trending", { params: { limit: 6 } }).then((res) => {
      setTrending(res.data.data.posts || []);
    }).catch(() => {});
    api.get("/feed/categories/counts").then((res) => {
      setCategoryCounts(res.data.data.categories || []);
    }).catch(() => {});
    api.get("/feed/suggestions").then((res) => {
      setSuggestions(res.data.data || { users: [], posts: [] });
    }).catch(() => {});
    api.get("/waves").then((res) => {
      setWaveGroups(res.data.data?.groups || []);
    }).catch(() => {});
  }, []);

  const topCategory = categoryCounts.length > 0 ? categoryCounts[0] : null;

  return (
    <div className="max-w-7xl mx-auto px-3 sm:px-4">
      <div className="flex gap-6 pt-4 sm:pt-6">
        {/* Left Sidebar - Categories */}
        <aside className="hidden lg:block w-56 shrink-0">
          <div className="sticky top-28 bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700">
              <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Categories</h3>
            </div>
            <div className="p-2">
              <button
                onClick={() => setCategory("")}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
                  !category
                    ? "bg-gradient-to-r from-tide-600 to-flow-600 text-white shadow-md shadow-tide-200 dark:shadow-tide-900/30"
                    : "text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50"
                }`}
              >
                <span className="w-6 h-6 rounded-lg bg-gray-200 dark:bg-gray-700 flex items-center justify-center text-xs">
                  <FiClock size={14} />
                </span>
                All
              </button>
              {CATEGORIES.map((c) => (
                <button
                  key={c}
                  onClick={() => setCategory(c)}
                  className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
                    category === c
                      ? "bg-gradient-to-r from-tide-600 to-flow-600 text-white shadow-md shadow-tide-200 dark:shadow-tide-900/30"
                      : "text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50"
                }`}
                >
                  <span className="w-6 h-6 rounded-lg bg-gray-200 dark:bg-gray-700 flex items-center justify-center text-xs">
                    {c[0]}
                  </span>
                  {c}
                </button>
              ))}
            </div>
          </div>
        </aside>

        {/* Center - Feed */}
        <div className="flex-1 min-w-0">
          {/* Waves Stories */}
          {waveGroups.length > 0 && (
            <div className="mb-4">
              <div className="flex items-center gap-4 overflow-x-auto pb-2 scrollbar-hide">
                {user && (
                  <Link
                    to={`/waves/view/${user.username}`}
                    className="flex flex-col items-center gap-1 shrink-0"
                  >
                    <div className="p-[2px] rounded-full bg-gradient-to-br from-tide-500 to-flow-600">
                      <div className="w-[52px] h-[52px] rounded-full bg-white dark:bg-gray-900 p-[2px]">
                        <img
                          src={user.avatar_url || `https://ui-avatars.com/api/?name=${user.username}&background=6366F1&color=fff`}
                          alt={user.username}
                          className="w-full h-full rounded-full object-cover"
                        />
                      </div>
                    </div>
                    <span className="text-[11px] font-medium text-gray-500">You</span>
                  </Link>
                )}
                {waveGroups.map((group) => (
                  <Link
                    key={group.user.id}
                    to={`/waves/view/${group.user.username}`}
                    className="flex flex-col items-center gap-1 shrink-0"
                  >
                    <div className={`p-[2px] rounded-full ${group.has_unseen ? "bg-gradient-to-r from-sun-400 via-coral-500 to-flow-600" : "bg-gray-300 dark:bg-gray-600"}`}>
                      <div className="w-[52px] h-[52px] rounded-full bg-white dark:bg-gray-900 p-[2px]">
                        <img
                          src={group.user.avatar_url || `https://ui-avatars.com/api/?name=${group.user.username}&background=6366F1&color=fff`}
                          alt={group.user.username}
                          className="w-full h-full rounded-full object-cover"
                        />
                      </div>
                    </div>
                    <span className="text-[11px] font-medium text-gray-500 truncate max-w-[64px]">
                      {group.user.id === user?.id ? "You" : group.user.username}
                    </span>
                  </Link>
                ))}
              </div>
            </div>
          )}

          {/* Search bar - matches feed width */}
          <div className="sticky top-14 z-10 pb-3 bg-white dark:bg-gray-900">
            <SearchBar />
          </div>

          {/* Mobile Categories */}
          <div className="flex gap-2 mb-5 overflow-x-auto pb-2 scrollbar-hide lg:hidden">
            <button
              onClick={() => setCategory("")}
              className={`px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-all duration-200 shrink-0 ${
                !category
                  ? "bg-gradient-to-r from-tide-600 to-flow-600 text-white shadow-md shadow-tide-200 dark:shadow-tide-900/30"
                  : "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
              }`}
            >
              All
            </button>
            {CATEGORIES.map((c) => (
              <button
                key={c}
                onClick={() => setCategory(c)}
                className={`px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-all duration-200 shrink-0 ${
                  category === c
                    ? "bg-gradient-to-r from-tide-600 to-flow-600 text-white shadow-md shadow-tide-200 dark:shadow-tide-900/30"
                    : "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
                }`}
              >
                {c}
              </button>
            ))}
          </div>

          {/* Posts */}
          <div className="space-y-4 sm:space-y-5">
            {posts.map((post, i) => (
              <div
                key={post.uuid || i}
                ref={i === posts.length - 1 ? lastPostRef : null}
              >
                <PostCard post={post} />
              </div>
            ))}
            {loading && (
              <div className="text-center py-6">
                <div className="animate-spin rounded-full h-7 w-7 border-[3px] border-tide-500 border-t-transparent mx-auto" />
              </div>
            )}
            {!hasMore && posts.length > 0 && (
              <p className="text-center text-sm text-gray-400 py-4">You are all caught up</p>
            )}
            {!loading && posts.length === 0 && (
              <div className="text-center py-16">
                <p className="text-gray-400 text-lg mb-2">No posts yet</p>
                <p className="text-gray-500 text-sm">Be the first to share something!</p>
              </div>
            )}
          </div>
        </div>

        {/* Right Sidebar - Trending & Suggestions */}
        <aside className="hidden xl:block w-72 shrink-0">
          <div className="sticky top-28 max-h-[calc(100vh-8rem)] overflow-y-auto space-y-5 scrollbar-hide">
            {/* Trending Posts */}
            <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 overflow-hidden">
              <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700 flex items-center gap-2">
                <FiTrendingUp className="text-tide-600" size={16} />
                <h3 className="text-sm font-semibold">Trending</h3>
              </div>
              <div className="p-2">
                {trending.map((post, i) => (
                  <Link
                    key={post.uuid}
                    to={`/posts/${post.uuid}`}
                    className="flex items-start gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700/50 transition group"
                  >
                    <span className="text-xs font-bold text-gray-300 dark:text-gray-600 w-5 shrink-0 pt-0.5">
                      {String(i + 1).padStart(2, "0")}
                    </span>
                    <div className="min-w-0">
                      <p className="text-sm font-medium text-gray-900 dark:text-gray-100 line-clamp-1 group-hover:text-tide-600 transition">
                        {post.title}
                      </p>
                      <div className="flex items-center gap-2 mt-0.5">
                        <span className="text-xs text-gray-500">{post.user?.username}</span>
                        <span className="text-xs text-gray-400">&bull;</span>
                        <span className="text-xs text-gray-500">{post.likes_count} likes</span>
                      </div>
                    </div>
                  </Link>
                ))}
                {trending.length === 0 && (
                  <p className="text-sm text-gray-400 px-3 py-4 text-center">No trending posts</p>
                )}
              </div>
            </div>

            {/* Top Category */}
            {topCategory && (
              <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 overflow-hidden">
                <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700">
                  <h3 className="text-sm font-semibold">Most Active Category</h3>
                </div>
                <div className="p-4 text-center">
                  <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-tide-500 to-flow-600 flex items-center justify-center text-white font-bold text-lg mx-auto mb-2 shadow-md shadow-tide-200 dark:shadow-tide-900/30">
                    {topCategory.name[0]}
                  </div>
                  <p className="text-base font-bold text-gray-900 dark:text-gray-100">{topCategory.name}</p>
                  <p className="text-xs text-gray-500 mt-0.5">{topCategory.count} posts</p>
                  <button
                    onClick={() => setCategory(topCategory.name)}
                    className="mt-3 text-xs font-medium text-tide-600 hover:text-tide-700 bg-tide-50 dark:bg-tide-900/20 px-3 py-1.5 rounded-full transition"
                  >
                    Explore {topCategory.name}
                  </button>
                </div>
              </div>
            )}

            {/* Suggested Users */}
            {suggestions.users.length > 0 && (
              <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 overflow-hidden">
                <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700 flex items-center gap-2">
                  <FiUsers className="text-tide-600" size={16} />
                  <h3 className="text-sm font-semibold">Who to follow</h3>
                </div>
                <div className="p-2">
                  {suggestions.users.map((u) => (
                    <Link
                      key={u.id}
                      to={`/profile/${u.username}`}
                      className="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700/50 transition"
                    >
                      <img
                        src={u.avatar_url || `https://ui-avatars.com/api/?name=${u.username}&background=6366F1&color=fff`}
                        alt=""
                        className="w-9 h-9 rounded-full object-cover"
                      />
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-gray-900 dark:text-gray-100">{u.username}</p>
                        {u.bio && <p className="text-xs text-gray-500 line-clamp-1">{u.bio}</p>}
                      </div>
                    </Link>
                  ))}
                </div>
              </div>
            )}
          </div>
        </aside>
      </div>
    </div>
  );
}