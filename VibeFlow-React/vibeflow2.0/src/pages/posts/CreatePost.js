import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import api from "../../utils/api";
import { FiArrowLeft } from "react-icons/fi";

const CATEGORIES = [
  "Tech", "Drama", "Action", "Fiction", "Music", "Fitness", "Sports",
  "Thrills", "Science", "Fashion", "Beauty", "Gossip", "Food", "Politics",
  "Business", "Comedy", "Nature", "Couples", "Kids",
];

export default function CreatePost() {
  const navigate = useNavigate();
  const [form, setForm] = useState({
    title: "",
    content: "",
    category: "",
    tags: "",
  });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const tags = form.tags
        ? form.tags.split(",").map((t) => t.trim().toLowerCase()).filter(Boolean)
        : [];
      const res = await api.post("/posts", {
        post: { ...form, tags, media_files: [] },
      });
      navigate(`/posts/${res.data.data.post.uuid}`);
    } catch (err) {
      const errors = err.response?.data?.errors;
      if (errors) {
        setError(Object.values(errors).flat().join(", "));
      } else {
        setError("Failed to create post");
      }
    }
    setLoading(false);
  };

  return (
    <div className="max-w-2xl mx-auto px-3 sm:px-4 py-4 sm:py-6">
      <Link to="/feed" className="inline-flex items-center gap-1.5 text-sm font-medium text-tide-600 hover:text-tide-700 mb-4 transition-colors">
        <FiArrowLeft size={16} /> Back to feed
      </Link>

      <div className="bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-5 sm:p-6">
        <h1 className="text-xl sm:text-2xl font-bold mb-6 bg-gradient-to-r from-tide-600 to-flow-600 bg-clip-text text-transparent">
          Create Post
        </h1>

        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-3 sm:p-4 rounded-xl mb-5 text-sm border border-red-200 dark:border-red-800/50">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="text"
            placeholder="Post title"
            value={form.title}
            onChange={(e) => setForm({ ...form, title: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <textarea
            placeholder="What's on your mind?"
            value={form.content}
            onChange={(e) => setForm({ ...form, content: e.target.value })}
            rows={5}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm resize-none transition-all"
            required
          />
          <select
            value={form.category}
            onChange={(e) => setForm({ ...form, category: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
          >
            <option value="">Select a category</option>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
          <input
            type="text"
            placeholder="Tags (comma separated)"
            value={form.tags}
            onChange={(e) => setForm({ ...form, tags: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
          />
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 bg-gradient-to-r from-tide-600 to-flow-600 text-white rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-md shadow-tide-200 dark:shadow-tide-900/30"
          >
            {loading ? "Publishing..." : "Publish"}
          </button>
        </form>
      </div>
    </div>
  );
}