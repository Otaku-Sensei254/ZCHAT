import { useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import api from "../../utils/api";
import { FiArrowLeft, FiUser, FiLock } from "react-icons/fi";

export default function Settings() {
  const { user, updateUser } = useAuth();
  const [form, setForm] = useState({
    username: user?.username || "",
    bio: user?.bio || "",
  });
  const [passwordForm, setPasswordForm] = useState({
    current_password: "",
    password: "",
    password_confirmation: "",
  });
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const updateProfile = async (e) => {
    e.preventDefault();
    setError("");
    setMessage("");
    try {
      const res = await api.put("/users/profile", { user: form });
      updateUser(res.data.data.user);
      setMessage("Profile updated");
    } catch (err) {
      const errors = err.response?.data?.errors;
      setError(errors ? Object.values(errors).flat().join(", ") : "Update failed");
    }
  };

  const updatePassword = async (e) => {
    e.preventDefault();
    setError("");
    setMessage("");
    if (passwordForm.password !== passwordForm.password_confirmation) {
      setError("Passwords do not match");
      return;
    }
    try {
      await api.put("/users/password", passwordForm);
      setMessage("Password updated");
      setPasswordForm({ current_password: "", password: "", password_confirmation: "" });
    } catch (err) {
      const errors = err.response?.data?.errors;
      setError(errors ? Object.values(errors).flat().join(", ") : "Update failed");
    }
  };

  return (
    <div className="max-w-2xl mx-auto px-3 sm:px-4 py-4 sm:py-6">
      <Link to={`/profile/${user?.username}`} className="inline-flex items-center gap-1.5 text-sm font-medium text-tide-600 hover:text-tide-700 mb-4 transition-colors">
        <FiArrowLeft size={16} /> Back to profile
      </Link>

      {message && (
        <div className="bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400 p-3 sm:p-4 rounded-xl mb-5 text-sm border border-green-200 dark:border-green-800/50 flex items-center gap-2">
          <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" /></svg>
          {message}
        </div>
      )}
      {error && (
        <div className="bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 p-3 sm:p-4 rounded-xl mb-5 text-sm border border-red-200 dark:border-red-800/50">{error}</div>
      )}

      <div className="bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-5 sm:p-6 mb-5">
        <div className="flex items-center gap-2 mb-5">
          <FiUser className="text-tide-600" size={18} />
          <h2 className="font-semibold text-lg">Profile</h2>
        </div>
        <form onSubmit={updateProfile} className="space-y-4">
          <input
            type="text"
            placeholder="Username"
            value={form.username}
            onChange={(e) => setForm({ ...form, username: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <textarea
            placeholder="Bio"
            value={form.bio}
            onChange={(e) => setForm({ ...form, bio: e.target.value })}
            rows={3}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm resize-none transition-all"
          />
          <button
            type="submit"
            className="px-6 py-2.5 bg-gradient-to-r from-tide-600 to-flow-600 text-white rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 transition-all duration-200 shadow-md shadow-tide-200 dark:shadow-tide-900/30"
          >
            Save Profile
          </button>
        </form>
      </div>

      <div className="bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-5 sm:p-6">
        <div className="flex items-center gap-2 mb-5">
          <FiLock className="text-tide-600" size={18} />
          <h2 className="font-semibold text-lg">Change Password</h2>
        </div>
        <form onSubmit={updatePassword} className="space-y-4">
          <input
            type="password"
            placeholder="Current password"
            value={passwordForm.current_password}
            onChange={(e) => setPasswordForm({ ...passwordForm, current_password: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <input
            type="password"
            placeholder="New password"
            value={passwordForm.password}
            onChange={(e) => setPasswordForm({ ...passwordForm, password: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <input
            type="password"
            placeholder="Confirm new password"
            value={passwordForm.password_confirmation}
            onChange={(e) => setPasswordForm({ ...passwordForm, password_confirmation: e.target.value })}
            className="w-full px-4 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 focus:border-transparent outline-none text-sm transition-all"
            required
          />
          <button
            type="submit"
            className="px-6 py-2.5 bg-gradient-to-r from-tide-600 to-flow-600 text-white rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 transition-all duration-200 shadow-md shadow-tide-200 dark:shadow-tide-900/30"
          >
            Update Password
          </button>
        </form>
      </div>
    </div>
  );
}