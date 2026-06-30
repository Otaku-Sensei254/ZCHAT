import { useState, useEffect, useRef } from "react";
import { useAuth } from "../../context/AuthContext";
import api from "../../utils/api";
import { FiSend, FiSearch, FiArrowLeft } from "react-icons/fi";

export default function Chat() {
  const { user } = useAuth();
  const [conversations, setConversations] = useState([]);
  const [activeConvo, setActiveConvo] = useState(null);
  const [messages, setMessages] = useState([]);
  const [messageText, setMessageText] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [loading, setLoading] = useState(true);
  const messagesEndRef = useRef(null);

  useEffect(() => {
    loadConversations();
  }, []);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const loadConversations = async () => {
    try {
      const res = await api.get("/chat/conversations");
      setConversations(res.data.data.conversations);
    } catch {}
    setLoading(false);
  };

  const openConversation = async (conv) => {
    setActiveConvo(conv);
    try {
      const res = await api.get(`/chat/conversations/${conv.uuid}/messages`);
      setMessages(res.data.data.messages);
      api.post(`/chat/conversations/${conv.uuid}/read`).catch(() => {});
    } catch {}
  };

  const sendMessage = async (e) => {
    e.preventDefault();
    if (!messageText.trim() || !activeConvo) return;
    try {
      const res = await api.post(`/chat/conversations/${activeConvo.uuid}/messages`, {
        message: { content: messageText },
      });
      setMessages((prev) => [...prev, res.data.data.message]);
      setMessageText("");
    } catch {}
  };

  const searchUsers = async (q) => {
    setSearchQuery(q);
    if (q.length < 2) {
      setSearchResults([]);
      return;
    }
    try {
      const res = await api.get("/users/search", { params: { q } });
      setSearchResults(res.data.data.users);
    } catch {}
  };

  const startConversation = async (username) => {
    try {
      const res = await api.post(`/chat/start/${username}`);
      setSearchQuery("");
      setSearchResults([]);
      loadConversations();
      openConversation(res.data.data.conversation);
    } catch {}
  };

  const [showMobileList, setShowMobileList] = useState(true);

  useEffect(() => {
    if (activeConvo) setShowMobileList(false);
  }, [activeConvo]);

  return (
    <div className="flex h-[calc(100vh-120px)] md:h-[calc(100vh-56px)]">
      <div className={`w-full md:w-80 border-r border-gray-200 dark:border-gray-700 flex-col ${activeConvo && !showMobileList ? "hidden md:flex" : "flex"}`}>
        <div className="p-3 border-b border-gray-200 dark:border-gray-700">
          <div className="relative">
            <FiSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search users..."
              value={searchQuery}
              onChange={(e) => searchUsers(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-sm focus:ring-2 focus:ring-tide-500 outline-none"
            />
          </div>
          {searchResults.length > 0 && (
            <div className="mt-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg">
              {searchResults.map((u) => (
                <button
                  key={u.id}
                  onClick={() => startConversation(u.username)}
                  className="flex items-center gap-2 p-2 hover:bg-gray-50 dark:hover:bg-gray-700 w-full text-left"
                >
                  <img
                    src={u.avatar_url || `https://ui-avatars.com/api/?name=${u.username}&background=6366F1&color=fff`}
                    alt={u.username}
                    className="w-8 h-8 rounded-full"
                  />
                  <span className="text-sm">{u.username}</span>
                </button>
              ))}
            </div>
          )}
        </div>
        <div className="flex-1 overflow-y-auto">
          {loading ? (
            <div className="flex justify-center py-8">
              <div className="animate-spin rounded-full h-6 w-6 border-t-2 border-b-2 border-tide-500" />
            </div>
          ) : conversations.length === 0 ? (
            <p className="text-center text-gray-500 py-8 text-sm">No conversations</p>
          ) : (
            conversations.map((conv) => (
              <button
                key={conv.uuid}
                onClick={() => openConversation(conv)}
                className={`w-full p-3 flex items-center gap-3 hover:bg-gray-50 dark:hover:bg-gray-700 text-left ${
                  activeConvo?.uuid === conv.uuid
                    ? "bg-tide-50 dark:bg-tide-900/20"
                    : ""
                }`}
              >
                <img
                  src={conv.other_user?.avatar_url || `https://ui-avatars.com/api/?name=${conv.other_user?.username || "U"}&background=6366F1&color=fff`}
                  alt={conv.other_user?.username}
                  className="w-10 h-10 rounded-full"
                />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold truncate">
                    {conv.other_user?.username || conv.name}
                  </p>
                  {conv.unread_count > 0 && (
                    <span className="text-xs bg-tide-600 text-white px-1.5 py-0.5 rounded-full">
                      {conv.unread_count}
                    </span>
                  )}
                </div>
              </button>
            ))
          )}
        </div>
      </div>

      <div className={`flex-1 flex-col ${!activeConvo || (!showMobileList && activeConvo) ? "flex" : "hidden md:flex"}`}>
        {activeConvo ? (
          <>
            <div className="p-3 border-b border-gray-200 dark:border-gray-700 flex items-center gap-3">
              <button
                onClick={() => { setShowMobileList(true); setActiveConvo(null); }}
                className="md:hidden p-1 text-gray-500 hover:text-tide-600"
              >
                <FiArrowLeft size={20} />
              </button>
              <p className="font-semibold">
                {activeConvo.other_user?.username || activeConvo.name}
              </p>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-3">
              {messages.map((msg) => (
                <div
                  key={msg.id}
                  className={`flex ${msg.user_id === user.id ? "justify-end" : "justify-start"}`}
                >
                  <div
                    className={`max-w-[70%] p-3 rounded-lg text-sm ${
                      msg.user_id === user.id
                        ? "bg-tide-600 text-white"
                        : "bg-gray-100 dark:bg-gray-700"
                    }`}
                  >
                    {msg.content}
                    <p className="text-xs mt-1 opacity-70">
                      {new Date(msg.inserted_at).toLocaleTimeString([], {
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </p>
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
            <form onSubmit={sendMessage} className="p-3 border-t border-gray-200 dark:border-gray-700 flex gap-2">
              <input
                type="text"
                value={messageText}
                onChange={(e) => setMessageText(e.target.value)}
                placeholder="Type a message..."
                className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 focus:ring-2 focus:ring-tide-500 outline-none"
              />
              <button
                type="submit"
                disabled={!messageText.trim()}
                className="px-4 py-2 bg-tide-600 text-white rounded-lg hover:bg-tide-700 disabled:opacity-50"
              >
                <FiSend />
              </button>
            </form>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center text-gray-500">
            Select a conversation
          </div>
        )}
      </div>
    </div>
  );
}
