import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { FiEye, FiEyeOff } from "react-icons/fi";
import { useAuth } from "../../context/AuthContext";

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: "", password: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(form.email, form.password);
      navigate("/feed");
    } catch (err) {
      setError(
        err.response?.data?.error || "Invalid email or password"
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[calc(100vh-56px)] flex items-center justify-center px-3 sm:px-4 bg-gradient-to-br from-tide-50/50 via-white to-flow-50/50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <div className="w-full max-w-sm">
        <div className="bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-6 sm:p-7">
          <h1 className="text-2xl font-bold mb-1 text-center bg-gradient-to-r from-tide-600 to-flow-600 bg-clip-text text-transparent">
            Welcome Back
          </h1>
          <p className="text-sm text-gray-500 text-center mb-6">Sign in to continue</p>

          {error && (
            <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-3 rounded-xl mb-4 text-sm border border-red-200 dark:border-red-800/50">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <input
              type="email"
              placeholder="Email address"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
              required
            />
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                placeholder="Password"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                className="w-full px-4 py-2.5 pr-11 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
              >
                {showPassword ? <FiEyeOff size={18} /> : <FiEye size={18} />}
              </button>
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full py-2.5 bg-gradient-to-r from-tide-600 to-flow-600 text-white rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-md shadow-tide-200 dark:shadow-tide-900/30"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>
          </form>

          <div className="mt-5 text-center text-sm space-y-2">
            <Link to="/forgot-password" className="block text-tide-600 hover:text-tide-700 hover:underline transition">
              Forgot password?
            </Link>
            <p className="text-gray-400">
              Don't have an account?{" "}
              <Link to="/register" className="text-tide-600 hover:text-tide-700 hover:underline font-medium transition">
                Sign up
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}