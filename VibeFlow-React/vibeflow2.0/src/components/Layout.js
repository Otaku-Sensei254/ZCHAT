import { useState, useRef, useEffect } from "react";
import { Link, Outlet, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useTheme } from "../context/ThemeContext";
import {
  FiMenu, FiX, FiGrid, FiMessageCircle,
  FiBell, FiUser, FiLogOut, FiLogIn,
  FiChevronDown, FiPlus, FiPlayCircle, FiEdit, FiMusic,
  FiSun, FiMoon
} from "react-icons/fi";

export default function Layout() {
  const { user, logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [postModalOpen, setPostModalOpen] = useState(false);
  const profileRef = useRef(null);
  const postModalRef = useRef(null);

  useEffect(() => {
    const handler = (e) => {
      if (profileRef.current && !profileRef.current.contains(e.target)) {
        setProfileOpen(false);
      }
      if (postModalRef.current && !postModalRef.current.contains(e.target)) {
        setPostModalOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const handleLogout = async () => {
    setMenuOpen(false);
    setProfileOpen(false);
    await logout();
    navigate("/");
  };

  const isActive = (path) => {
    if (path === "/") return location.pathname === "/";
    if (path === "/feed") return location.pathname === "/feed";
    if (path.startsWith("/profile")) return location.pathname.startsWith("/profile");
    return location.pathname.startsWith(path);
  };

  const navLinks = user
    ? [
        { to: "/feed", label: "Feed", icon: FiGrid },
        { to: "/currents", label: "Currents", icon: FiPlayCircle },
        { to: "/chat", label: "Chat", icon: FiMessageCircle },
        { to: "/notifications", label: "Alerts", icon: FiBell },
      ]
    : [
        { to: "/feed", label: "Feed", icon: FiGrid },
        { to: "/currents", label: "Currents", icon: FiPlayCircle },
        { to: "/login", label: "Log in", icon: FiLogIn },
      ];

  const bottomLinks = user
    ? [
        { to: "/feed", label: "Feed", icon: FiGrid },
        { to: "/currents", label: "Currents", icon: FiPlayCircle },
        { to: "/chat", label: "Chat", icon: FiMessageCircle },
        { to: "/notifications", label: "Alerts", icon: FiBell },
        { to: `/profile/${user.username}`, label: "Profile", icon: FiUser },
      ]
    : [
        { to: "/feed", label: "Feed", icon: FiGrid },
        { to: "/currents", label: "Currents", icon: FiPlayCircle },
        { to: "/login", label: "Log in", icon: FiLogIn },
      ];

  return (
    <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
      <nav className="fixed top-0 z-50 w-full bg-white/90 dark:bg-gray-900/90 backdrop-blur border-b border-gray-200 dark:border-gray-700">
        <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
          <div className="flex items-center gap-2 shrink-0 md:gap-0">
            <Link to={user ? "/feed" : "/"} className="hidden md:flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-tide-600 to-flow-600 flex items-center justify-center text-white font-bold text-sm shadow-md shadow-tide-200 dark:shadow-tide-900/30">
                V
              </div>
              <span className="text-lg font-extrabold tracking-wide bg-gradient-to-r from-tide-600 via-flow-600 to-coral-500 bg-clip-text text-transparent drop-shadow-sm">
                Vibeflow
              </span>
            </Link>
            {user && (
              <button
                onClick={() => setPostModalOpen(true)}
                className="p-2 text-gray-600 dark:text-gray-300 hover:text-tide-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-all"
              >
                <FiPlus size={22} />
              </button>
            )}
          </div>

          <span className="md:hidden text-lg font-extrabold tracking-wide bg-gradient-to-r from-tide-600 via-flow-600 to-coral-500 bg-clip-text text-transparent drop-shadow-sm">
            Vibeflow
          </span>

          <div className="hidden md:flex items-center gap-1">
            {navLinks.map((link) => (
              <Link
                key={link.to}
                to={link.to}
                className={`flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-xl transition-all duration-200 ${
                  isActive(link.to)
                    ? "bg-tide-50 dark:bg-tide-900/20 text-tide-600"
                    : "text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-gray-100"
                }`}
              >
                <link.icon size={18} />
                {link.label}
              </Link>
            ))}
          </div>

          <div className="flex items-center gap-2">
            {user ? (
              <div className="relative" ref={profileRef}>
                <button
                  onClick={() => setProfileOpen(!profileOpen)}
                  className="flex items-center gap-2 px-2 py-1.5 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-all duration-200"
                >
                  <img
                    src={user.avatar_url || `https://ui-avatars.com/api/?name=${user.username}&background=6366F1&color=fff&bold=true`}
                    alt={user.username}
                    className="w-7 h-7 rounded-full object-cover ring-2 ring-white dark:ring-gray-800"
                  />
                  <span className="hidden sm:block text-sm font-medium text-gray-700 dark:text-gray-300 max-w-[100px] truncate">
                    {user.username}
                  </span>
                  <FiChevronDown
                    size={14}
                    className={`text-gray-400 transition-transform duration-200 ${
                      profileOpen ? "rotate-180" : ""
                    }`}
                  />
                </button>

                {profileOpen && (
                  <div className="absolute right-0 mt-2 w-56 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-xl shadow-black/5 dark:shadow-black/20 py-1.5 z-50">
                    <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700 mb-1">
                      <p className="font-semibold text-sm">{user.username}</p>
                      <p className="text-xs text-gray-500 truncate">{user.email}</p>
                    </div>
                    <Link
                      to={`/profile/${user.username}`}
                      onClick={() => setProfileOpen(false)}
                      className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition"
                    >
                      <FiUser size={16} className="text-gray-400" />
                      Profile
                    </Link>
                    <Link
                      to="/settings"
                      onClick={() => setProfileOpen(false)}
                      className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition"
                    >
                      <svg className="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                      Settings
                    </Link>
                    <div className="border-t border-gray-100 dark:border-gray-700 mt-1 pt-1">
                      <button
                        onClick={() => { toggleTheme(); setProfileOpen(false); }}
                        className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700/50 w-full text-left transition"
                      >
                        {theme === "dark" ? <FiSun size={16} /> : <FiMoon size={16} />}
                        {theme === "dark" ? "Light mode" : "Dark mode"}
                      </button>
                      <button
                        onClick={handleLogout}
                        className="flex items-center gap-3 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 w-full text-left transition"
                      >
                        <FiLogOut size={16} />
                        Log out
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ) : null}

            <button
              onClick={() => setMenuOpen(!menuOpen)}
              className="md:hidden p-2 text-gray-600 dark:text-gray-300 hover:text-tide-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-all"
            >
              {menuOpen ? <FiX size={20} /> : <FiMenu size={20} />}
            </button>
          </div>
        </div>
      </nav>

      {menuOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/30 md:hidden"
          onClick={() => setMenuOpen(false)}
        />
      )}

      <div
        className={`fixed top-14 right-0 z-50 h-full w-64 bg-white dark:bg-gray-800 border-l border-gray-200 dark:border-gray-700 transform transition-transform duration-200 ease-in-out md:hidden ${
          menuOpen ? "translate-x-0" : "translate-x-full"
        }`}
      >
        <div className="p-4 space-y-1">
          {user ? (
            <>
              <div className="flex items-center gap-3 p-3 border-b border-gray-200 dark:border-gray-700 mb-2">
                <img
                  src={user.avatar_url || `https://ui-avatars.com/api/?name=${user.username}&background=6366F1&color=fff&bold=true`}
                  alt=""
                  className="w-10 h-10 rounded-full object-cover"
                />
                <div>
                  <p className="font-semibold text-sm">{user.username}</p>
                  <p className="text-xs text-gray-500">{user.email}</p>
                </div>
              </div>
              {navLinks.concat({ to: `/profile/${user.username}`, label: "Profile", icon: FiUser }).map((link) => (
                <Link
                  key={link.to}
                  to={link.to}
                  onClick={() => setMenuOpen(false)}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition ${
                    isActive(link.to)
                      ? "bg-tide-50 dark:bg-tide-900/20 text-tide-600"
                      : "hover:bg-gray-100 dark:hover:bg-gray-700"
                  }`}
                >
                  <link.icon size={18} />
                  {link.label}
                </Link>
              ))}
              <Link
                to="/settings"
                onClick={() => setMenuOpen(false)}
                className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition"
              >
                <svg className="w-[18px] h-[18px] text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                Settings
              </Link>
              <button
                onClick={() => { toggleTheme(); setMenuOpen(false); }}
                className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm hover:bg-gray-100 dark:hover:bg-gray-700 w-full text-left transition"
              >
                {theme === "dark" ? <FiSun size={18} /> : <FiMoon size={18} />}
                {theme === "dark" ? "Light mode" : "Dark mode"}
              </button>
              <button
                onClick={handleLogout}
                className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-coral-500 hover:bg-coral-50 dark:hover:bg-coral-900/20 w-full text-left transition"
              >
                <FiLogOut size={18} />
                Logout
              </button>
            </>
          ) : (
            <>
              {navLinks.map((link) => (
                <Link
                  key={link.to}
                  to={link.to}
                  onClick={() => setMenuOpen(false)}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition ${
                    isActive(link.to)
                      ? "bg-tide-50 dark:bg-tide-900/20 text-tide-600"
                      : "hover:bg-gray-100 dark:hover:bg-gray-700"
                  }`}
                >
                  <link.icon size={18} />
                  {link.label}
                </Link>
              ))}
            </>
          )}
        </div>
      </div>

      {postModalOpen && (
        <>
          <div className="fixed inset-0 z-40 bg-black/30" onClick={() => setPostModalOpen(false)} />
          <div
            ref={postModalRef}
            className="fixed left-0 right-0 z-50 bg-white dark:bg-gray-800 shadow-2xl md:top-1/2 md:left-1/2 md:-translate-x-1/2 md:-translate-y-1/2 md:max-w-md md:rounded-2xl md:border md:border-gray-200 dark:md:border-gray-700 bottom-0 rounded-t-2xl border-t border-gray-100 dark:border-gray-700 animate-slide-up"
          >
            <div className="flex items-center justify-center pt-3 pb-1 md:hidden">
              <div className="w-10 h-1 rounded-full bg-gray-300 dark:bg-gray-600" />
            </div>
            <div className="p-4 space-y-1 pb-16 md:pb-4">
              <div className="flex items-center justify-between px-4 pb-2">
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Create</p>
                <button onClick={() => setPostModalOpen(false)} className="hidden md:block p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition">
                  <FiX size={18} />
                </button>
              </div>
              <button
                onClick={() => { setPostModalOpen(false); navigate("/posts/new"); }}
                className="flex items-center gap-4 w-full px-4 py-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700/50 transition text-left"
              >
                <div className="w-10 h-10 rounded-xl bg-tide-100 dark:bg-tide-900/30 flex items-center justify-center text-tide-600">
                  <FiEdit size={20} />
                </div>
                <div>
                  <p className="font-medium text-sm text-gray-900 dark:text-gray-100">Post</p>
                  <p className="text-xs text-gray-500">Share a thought, story, or update</p>
                </div>
              </button>
              <button
                onClick={() => { setPostModalOpen(false); navigate("/waves/new"); }}
                className="flex items-center gap-4 w-full px-4 py-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700/50 transition text-left"
              >
                <div className="w-10 h-10 rounded-xl bg-cyan-100 dark:bg-cyan-900/30 flex items-center justify-center text-cyan-600">
                  <FiMusic size={20} />
                </div>
                <div>
                  <p className="font-medium text-sm text-gray-900 dark:text-gray-100">Wave</p>
                  <p className="text-xs text-gray-500">Share music, audio, or a vibe</p>
                </div>
              </button>
              <button
                onClick={() => { setPostModalOpen(false); navigate("/currents/new"); }}
                className="flex items-center gap-4 w-full px-4 py-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700/50 transition text-left"
              >
                <div className="w-10 h-10 rounded-xl bg-flow-100 dark:bg-flow-900/30 flex items-center justify-center text-flow-600">
                  <FiPlayCircle size={20} />
                </div>
                <div>
                  <p className="font-medium text-sm text-gray-900 dark:text-gray-100">Current</p>
                  <p className="text-xs text-gray-500">Upload a short-form video</p>
                </div>
              </button>
            </div>
          </div>
        </>
      )}

      <main className={`pt-14 ${location.pathname.startsWith("/waves/") ? "" : "pb-16"} md:pb-0`}>
        <Outlet />
      </main>

      {!location.pathname.startsWith("/waves/") && (
      <nav className="fixed bottom-0 z-50 w-full bg-white/90 dark:bg-gray-900/90 backdrop-blur border-t border-gray-200 dark:border-gray-700 md:hidden">
        <div className="flex items-center justify-around h-16">
          {bottomLinks.map((link) => {
            const isProfile = link.label === "Profile";
            return (
              <Link
                key={link.to}
                to={link.to}
                className={`flex flex-col items-center gap-0.5 px-3 py-1 text-xs transition ${
                  isActive(link.to)
                    ? "text-tide-600"
                    : "text-gray-500 dark:text-gray-400 hover:text-tide-600"
                }`}
              >
                {isProfile && user ? (
                  <img
                    src={user.avatar_url || `https://ui-avatars.com/api/?name=${user.username}&background=6366F1&color=fff&bold=true`}
                    alt=""
                    className="w-6 h-6 rounded-full object-cover ring-2 ring-white dark:ring-gray-800"
                  />
                ) : (
                  <link.icon size={20} />
                )}
                {link.label}
              </Link>
            );
          })}
        </div>
      </nav>
      )}
    </div>
  );
}