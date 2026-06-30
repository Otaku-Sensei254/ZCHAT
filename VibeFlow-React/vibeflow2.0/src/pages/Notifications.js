import { useState, useEffect, useCallback } from "react";
import api from "../utils/api";
import { joinChannel, onChannel } from "../utils/realtime";
import { FiHeart, FiMessageCircle, FiRepeat, FiUserPlus, FiAtSign, FiFileText } from "react-icons/fi";

const NOTIF_ICONS = {
  like: { icon: FiHeart, color: "text-coral-500", bg: "bg-coral-50 dark:bg-coral-900/20" },
  comment: { icon: FiMessageCircle, color: "text-tide-500", bg: "bg-tide-50 dark:bg-tide-900/20" },
  follow: { icon: FiUserPlus, color: "text-green-500", bg: "bg-green-50 dark:bg-green-900/20" },
  repost: { icon: FiRepeat, color: "text-green-500", bg: "bg-green-50 dark:bg-green-900/20" },
  mention: { icon: FiAtSign, color: "text-flow-500", bg: "bg-flow-50 dark:bg-flow-900/20" },
  new_post: { icon: FiFileText, color: "text-blue-500", bg: "bg-blue-50 dark:bg-blue-900/20" },
};

function getIcon(type) {
  return NOTIF_ICONS[type] || { icon: FiHeart, color: "text-gray-500", bg: "bg-gray-50 dark:bg-gray-800" };
}

function formatTime(dateStr) {
  if (!dateStr) return "";
  const normalized = dateStr.endsWith("Z") || dateStr.includes("+") ? dateStr : dateStr + "Z";
  const d = new Date(normalized);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
  return d.toLocaleDateString();
}

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);

  const loadNotifications = useCallback(async () => {
    try {
      const res = await api.get("/notifications");
      setNotifications(res.data.data.notifications);
    } catch {}
    setLoading(false);
  }, []);

  useEffect(() => {
    loadNotifications();
    joinChannel("relay:user", {});
    onChannel("relay:user", "new_notification", (n) => {
      setNotifications((prev) => [n, ...prev]);
    });
    onChannel("relay:user", "update_notifications", () => {
      loadNotifications();
    });
  }, [loadNotifications]);

  const markRead = async (id) => {
    try {
      await api.post(`/notifications/${id}/read`);
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, read_at: new Date().toISOString() } : n))
      );
    } catch {}
  };

  const markAllRead = async () => {
    try {
      await api.post("/notifications/read-all");
      setNotifications((prev) =>
        prev.map((n) => ({ ...n, read_at: new Date().toISOString() }))
      );
    } catch {}
  };

  if (loading) {
    return (
      <div className="flex justify-center py-16">
        <div className="animate-spin rounded-full h-8 w-8 border-[3px] border-tide-500 border-t-transparent" />
      </div>
    );
  }

  const unreadCount = notifications.filter((n) => !n.read_at).length;

  return (
    <div className="max-w-2xl mx-auto px-3 sm:px-4 py-4 sm:py-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <h1 className="text-xl font-bold">Notifications</h1>
          {unreadCount > 0 && (
            <span className="text-xs font-semibold bg-tide-600 text-white px-2 py-0.5 rounded-full">
              {unreadCount}
            </span>
          )}
        </div>
        {unreadCount > 0 && (
          <button
            onClick={markAllRead}
            className="text-sm font-medium text-tide-600 hover:text-tide-700 hover:underline transition"
          >
            Mark all read
          </button>
        )}
      </div>

      <div className="space-y-2">
        {notifications.map((n) => {
          const { icon: Icon, color, bg } = getIcon(n.type);
          const isUnread = !n.read_at;
          return (
            <div
              key={n.id}
              onClick={() => markRead(n.id)}
              className={`group relative flex items-start gap-3 p-3 sm:p-4 rounded-xl border cursor-pointer transition-all duration-200 ${
                isUnread
                  ? "bg-gradient-to-r from-tide-50/80 to-white dark:from-tide-900/15 dark:to-gray-800/80 border-tide-200 dark:border-tide-800/50 hover:shadow-md"
                  : "bg-white dark:bg-gray-800/60 border-gray-100 dark:border-gray-700/50 hover:bg-gray-50 dark:hover:bg-gray-800"
              }`}
            >
              <div className={`shrink-0 w-10 h-10 rounded-full flex items-center justify-center ${bg}`}>
                <Icon className={color} size={18} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-0.5">
                  <img
                    src={n.actor?.avatar_url || `https://ui-avatars.com/api/?name=${n.actor?.username || "?"}&background=6366F1&color=fff&bold=true`}
                    alt=""
                    className="w-5 h-5 rounded-full shrink-0"
                  />
                  <p className="text-sm">
                    <strong className="font-semibold">{n.actor?.username}</strong>{" "}
                    <span className="text-gray-600 dark:text-gray-400">
                      {n.type === "like" ? "liked your post"
                        : n.type === "comment" ? "commented on your post"
                        : n.type === "follow" ? "followed you"
                        : n.type === "repost" ? "reposted your post"
                        : n.type === "mention" ? "mentioned you"
                        : n.type === "new_post" ? "posted something new"
                        : n.type}
                    </span>
                  </p>
                </div>
                <p className="text-xs text-gray-400 mt-1">
                  {formatTime(n.inserted_at)}
                </p>
              </div>
              {isUnread && (
                <span className="shrink-0 w-2.5 h-2.5 bg-tide-600 rounded-full mt-2 ring-2 ring-white dark:ring-gray-900" />
              )}
            </div>
          );
        })}
        {notifications.length === 0 && (
          <div className="text-center py-16">
            <FiHeart className="mx-auto text-gray-300 dark:text-gray-600 mb-3" size={40} />
            <p className="text-gray-500 text-lg mb-1">No notifications yet</p>
            <p className="text-gray-400 text-sm">When someone interacts with your posts, it'll show up here</p>
          </div>
        )}
      </div>
    </div>
  );
}