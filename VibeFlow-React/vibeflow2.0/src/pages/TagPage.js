import { useState, useEffect, useCallback } from "react";
import { useParams, Link } from "react-router-dom";
import api from "../utils/api";
import PostCard from "../components/PostCard";
import { FiArrowLeft, FiHash } from "react-icons/fi";

export default function TagPage() {
  const { tag } = useParams();
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);

  useEffect(() => {
    setPage(1);
    setPosts([]);
  }, [tag]);

  const loadPosts = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get("/feed", { params: { page, per_page: 20, search: tag } });
      if (page === 1) {
        setPosts(res.data.data.posts);
      } else {
        setPosts((prev) => [...prev, ...res.data.data.posts]);
      }
    } catch {}
    setLoading(false);
  }, [page, tag]);

  useEffect(() => {
    if (page === 1) loadPosts();
  }, [tag, loadPosts, page]);

  useEffect(() => {
    if (page > 1) loadPosts();
  }, [page, loadPosts]);

  return (
    <div className="max-w-2xl mx-auto px-3 sm:px-4 py-4 sm:py-6">
      <Link to="/feed" className="inline-flex items-center gap-1.5 text-sm font-medium text-tide-600 hover:text-tide-700 mb-4 transition-colors">
        <FiArrowLeft size={16} /> Back to feed
      </Link>
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-tide-50 dark:bg-tide-900/30 flex items-center justify-center">
          <FiHash className="text-tide-600" size={20} />
        </div>
        <h1 className="text-xl sm:text-2xl font-bold">{tag}</h1>
      </div>
      <div className="space-y-4 sm:space-y-5">
        {posts.map((post) => (
          <PostCard key={post.uuid} post={post} />
        ))}
        {loading && (
          <div className="text-center py-6">
            <div className="animate-spin rounded-full h-7 w-7 border-[3px] border-tide-500 border-t-transparent mx-auto" />
          </div>
        )}
        {!loading && posts.length === 0 && (
          <div className="text-center py-12">
            <FiHash className="mx-auto text-gray-300 dark:text-gray-600 mb-2" size={32} />
            <p className="text-gray-400">No posts with this tag</p>
          </div>
        )}
      </div>
    </div>
  );
}