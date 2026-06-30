import { useState } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import api from "../../utils/api";

export default function ResetPassword() {
  const { token } = useParams();
  const navigate = useNavigate();
  const [form, setForm] = useState({ password: "", password_confirmation: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (form.password !== form.password_confirmation) {
      setError("Passwords don't match");
      return;
    }
    setError("");
    setLoading(true);
    try {
      await api.post("/auth/reset-password", { token, ...form });
      navigate("/login");
    } catch (err) {
      setError(err.response?.data?.error || "Failed to reset password");
    }
    setLoading(false);
  };

  return (
    <div className="min-h-[calc(100vh-56px)] flex items-center justify-center px-3 sm:px-4 bg-gradient-to-br from-tide-50/50 via-white to-flow-50/50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <div className="w-full max-w-sm bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-6 sm:p-7">
        <h1 className="text-2xl font-bold mb-1 text-center bg-gradient-to-r from-tide-600 to-flow-600 bg-clip-text text-transparent">
          Set New Password
        </h1>
        <p className="text-sm text-gray-500 text-center mb-6">Choose a strong password</p>

        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-3 rounded-xl mb-4 text-sm border border-red-200 dark:border-red-800/50">{error}</div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="password"
            placeholder="New password"
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <input
            type="password"
            placeholder="Confirm password"
            value={form.password_confirmation}
            onChange={(e) => setForm({ ...form, password_confirmation: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 bg-gradient-to-r from-tide-600 to-flow-600 text-white rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-md shadow-tide-200 dark:shadow-tide-900/30"
          >
            {loading ? "Resetting..." : "Reset Password"}
          </button>
        </form>

        <p className="mt-5 text-center text-sm text-gray-400">
          <Link to="/login" className="text-tide-600 hover:underline font-medium">Back to sign in</Link>
        </p>
      </div>
    </div>
  );
}