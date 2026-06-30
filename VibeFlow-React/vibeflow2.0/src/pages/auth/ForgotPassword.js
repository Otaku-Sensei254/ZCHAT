import { useState } from "react";
import { Link } from "react-router-dom";
import api from "../../utils/api";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await api.post("/auth/forgot-password", { email });
      setSent(true);
    } catch {
      setError("Something went wrong. Try again.");
    }
    setLoading(false);
  };

  if (sent) {
    return (
      <div className="min-h-[calc(100vh-56px)] flex items-center justify-center px-3 sm:px-4 bg-gradient-to-br from-tide-50/50 via-white to-flow-50/50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
        <div className="w-full max-w-sm bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-6 sm:p-7 text-center">
          <div className="w-14 h-14 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-7 h-7 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" /></svg>
          </div>
          <h2 className="text-lg font-bold mb-2">Check your email</h2>
          <p className="text-sm text-gray-500 mb-4">If an account with that email exists, we've sent reset instructions.</p>
          <Link to="/login" className="text-tide-600 hover:underline text-sm font-medium">Back to sign in</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-[calc(100vh-56px)] flex items-center justify-center px-3 sm:px-4 bg-gradient-to-br from-tide-50/50 via-white to-flow-50/50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <div className="w-full max-w-sm bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-6 sm:p-7">
        <h1 className="text-2xl font-bold mb-1 text-center bg-gradient-to-r from-tide-600 to-flow-600 bg-clip-text text-transparent">
          Reset Password
        </h1>
        <p className="text-sm text-gray-500 text-center mb-6">Enter your email and we'll send you instructions</p>

        {error && (
          <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-3 rounded-xl mb-4 text-sm border border-red-200 dark:border-red-800/50">{error}</div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="email"
            placeholder="Email address"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 bg-gradient-to-r from-tide-600 to-flow-600 text-white rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-md shadow-tide-200 dark:shadow-tide-900/30"
          >
            {loading ? "Sending..." : "Send Instructions"}
          </button>
        </form>

        <p className="mt-5 text-center text-sm text-gray-400">
          Remember your password?{" "}
          <Link to="/login" className="text-tide-600 hover:underline font-medium">Sign in</Link>
        </p>
      </div>
    </div>
  );
}