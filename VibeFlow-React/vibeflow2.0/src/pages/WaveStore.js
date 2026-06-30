import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import api from "../utils/api";
import { useAuth } from "../context/AuthContext";
import { FiX } from "react-icons/fi";

function formatPoints(p) {
  const n = parseInt(p) || 0;
  return n.toLocaleString();
}

function ItemPreview({ slug, name }) {
  if (slug?.includes("glassmorphism")) {
    return (
      <div className="absolute inset-0 bg-gradient-to-br from-white/20 to-white/5 backdrop-blur-sm border border-white/30 rounded-xl" />
    );
  }
  if (slug?.includes("matrix")) {
    return (
      <div className="absolute inset-0 bg-black/90 rounded-xl">
        <div className="h-full flex flex-col justify-end p-2 space-y-1">
          {[0.8, 0.6, 0.9, 0.7, 0.85].map((o, i) => (
            <div key={i} className="h-0.5 bg-green-500" style={{ opacity: o }} />
          ))}
        </div>
      </div>
    );
  }
  if (slug?.includes("holographic")) {
    return (
      <div className="absolute inset-0 bg-gradient-to-br from-coral-300/20 via-blue-300/20 to-flow-300/20 rounded-xl animate-pulse" />
    );
  }
  if (slug?.includes("vantablack")) {
    return <div className="absolute inset-0 bg-black rounded-xl border border-black" />;
  }
  if (slug?.includes("frame")) {
    const isRed = slug?.includes("red");
    const borderColor = isRed ? "border-amber-400" : "border-blue-400";
    const shadowColor = isRed
      ? "rgba(250,204,21,0.5)"
      : "rgba(59,130,246,0.5)";
    return (
      <div
        className={`w-16 h-16 rounded-full border-4 ${borderColor} bg-slate-200`}
        style={{ boxShadow: `0 0 15px ${shadowColor}` }}
      />
    );
  }
  if (slug?.includes("glow")) {
    return (
      <div className="px-4 py-2 rounded-full bg-gradient-to-r from-flow-400 via-coral-500 to-red-500 text-white font-black tracking-wide shadow-lg">
        Glow
      </div>
    );
  }
  return (
    <span className="text-lg font-black text-slate-600 dark:text-slate-400 uppercase tracking-wider">
      {slug}
    </span>
  );
}

function RarityBadge({ slug }) {
  let label, cls;
  if (slug?.includes("glassmorphism")) {
    label = "Rare";
    cls = "bg-flow-100 text-flow-700 dark:bg-flow-900/30 dark:text-flow-300";
  } else if (slug?.includes("matrix")) {
    label = "Epic";
    cls = "bg-flow-100 text-flow-700 dark:bg-flow-900/30 dark:text-flow-300";
  } else if (slug?.includes("holographic")) {
    label = "Legendary";
    cls = "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300";
  } else if (slug?.includes("vantablack")) {
    label = "Mythic";
    cls = "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300";
  } else {
    label = "Common";
    cls = "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400";
  }
  return (
    <span className={`px-2 py-1 text-xs font-bold rounded-full ${cls}`}>
      {label}
    </span>
  );
}

export default function WaveStore() {
  const { user } = useAuth();
  const [items, setItems] = useState([]);
  const [grouped, setGrouped] = useState({});
  const [pointsBalance, setPointsBalance] = useState(0);
  const [loading, setLoading] = useState(true);
  const [purchasing, setPurchasing] = useState(null);
  const [flash, setFlash] = useState(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await api.get("/store/items");
        const d = res.data.data;
        setItems(d.items);
        setPointsBalance(d.points_balance);
        const g = {};
        (d.items || []).forEach((item) => {
          const cat = item.category || "other";
          if (!g[cat]) g[cat] = [];
          g[cat].push(item);
        });
        setGrouped(g);
      } catch {}
      setLoading(false);
    })();
  }, []);

  const handlePurchase = async (item) => {
    setPurchasing(item.id);
    setFlash(null);
    try {
      const res = await api.post("/store/purchase", { id: item.id });
      const d = res.data.data;
      setPointsBalance(d.points_balance);
      setFlash({ type: "success", message: d.message || "Item purchased!" });
      if (item.item_slug === "profile-glow") {
        window.location.href = "/settings?glow=1";
      }
    } catch (err) {
      const msg =
        err.response?.data?.error || "Purchase failed. Try again.";
      setFlash({ type: "error", message: msg });
    }
    setPurchasing(null);
  };

  const categoryMeta = {
    social_glows: { label: "Social Glows", badge: "Chat Skins", badgeCls: "from-flow-100 to-coral-100 text-flow-700 dark:from-flow-900/30 dark:to-coral-900/30 dark:text-flow-300" },
    digital_flex: { label: "Digital Flex", badge: "Status", badgeCls: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300" },
    power_ups: { label: "Power-Ups", badge: "Utility", badgeCls: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300" },
    message_skins: { label: "Message Skins", badge: "Chat", badgeCls: "bg-teal-100 text-teal-700 dark:bg-teal-900/30 dark:text-teal-300" },
  };

  if (loading) {
    return (
      <div className="flex justify-center py-16">
        <div className="animate-spin rounded-full h-8 w-8 border-[3px] border-tide-500 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <Link
        to={user ? `/profile/${user.username}` : "/feed"}
        className="inline-flex items-center gap-1.5 text-sm font-semibold text-gray-500 hover:text-tide-500 transition-colors group mb-6"
      >
        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 group-hover:-translate-x-1 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to profile
      </Link>

      <header className="flex justify-between items-center mb-10 bg-gradient-to-r from-blue-600 to-cyan-500 p-8 rounded-3xl text-white shadow-xl">
        <div>
          <h1 className="text-3xl font-bold italic tracking-tight">The Wave Store</h1>
          <p className="opacity-90">Exchange your energy for influence.</p>
        </div>
        <div className="text-right">
          <span className="block text-sm uppercase font-semibold opacity-75">Your Balance</span>
          <div className="flex items-center gap-2">
            <span className="text-4xl font-black">{formatPoints(pointsBalance)}</span>
            <span className="text-2xl">🌊</span>
          </div>
          <p className="text-xs opacity-70 mt-1">
            Points track your likes, ripples, and post creations.
            {user ? " Keep creating to unlock more waves." : " Log in to start earning."}
          </p>
        </div>
      </header>

      {flash && (
        <div className={`mb-6 px-5 py-3 rounded-xl text-sm font-medium flex items-center gap-3 ${
          flash.type === "success"
            ? "bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800"
            : "bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300 border border-red-200 dark:border-red-800"
        }`}>
          <span className="flex-1">{flash.message}</span>
          <button onClick={() => setFlash(null)} className="shrink-0 opacity-60 hover:opacity-100">
            <FiX size={16} />
          </button>
        </div>
      )}

      <div className="space-y-10">
        {Object.entries(grouped).map(([cat, catItems]) => {
          const meta = categoryMeta[cat] || { label: cat, badge: "", badgeCls: "" };
          const isPowerUp = cat === "power_ups";

          return (
            <section key={cat}>
              <div className="flex items-center gap-3 mb-6 border-b border-gray-200 dark:border-zinc-700 pb-2">
                <h2 className="text-xl font-bold text-gray-800 dark:text-white">{meta.label}</h2>
                {meta.badge && (
                  <span className={`px-2 py-0.5 bg-gradient-to-r text-xs font-bold rounded-full uppercase ${meta.badgeCls}`}>
                    {meta.badge}
                  </span>
                )}
              </div>

              <div className={`grid gap-6 ${isPowerUp ? "grid-cols-1 md:grid-cols-2" : "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"}`}>
                {catItems.map((item) =>
                  isPowerUp ? (
                    <div key={item.id} className="flex gap-4 bg-emerald-50 dark:bg-emerald-900/20 p-6 rounded-2xl border border-emerald-100 dark:border-emerald-800">
                      <div className="text-4xl shrink-0">
                        {item.item_slug?.includes("bottle") ? "🍾" : "🚀"}
                      </div>
                      <div className="flex-1">
                        <h3 className="font-bold text-emerald-900 dark:text-emerald-100">{item.item_name}</h3>
                        <p className="text-sm text-emerald-700 dark:text-emerald-300 mb-3">
                          Duration: <span className="font-semibold">{item.duration || "Instant"}</span>
                        </p>
                        <button
                          onClick={() => handlePurchase(item)}
                          disabled={purchasing === item.id}
                          className="px-6 py-2 bg-emerald-600 text-white rounded-lg font-bold hover:bg-emerald-700 disabled:opacity-50 transition-all"
                        >
                          {purchasing === item.id ? "..." : `${item.worth} 🌊`}
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div key={item.id} className={`group bg-white dark:bg-zinc-800 p-5 rounded-2xl border border-gray-100 dark:border-zinc-700 shadow-sm hover:shadow-lg transition-all duration-300 ${cat === "social_glows" ? "hover:scale-[1.02]" : "hover:shadow-md"}`}>
                      <div className="w-full h-28 bg-gradient-to-br from-slate-50 to-slate-100 dark:from-zinc-700 dark:to-zinc-800 rounded-xl mb-4 flex items-center justify-center border-2 border-dashed border-slate-200 dark:border-zinc-600 group-hover:border-flow-400 dark:group-hover:border-flow-500 transition-colors relative overflow-hidden">
                        <ItemPreview slug={item.item_slug} name={item.item_name} />
                        <div className="relative text-lg font-black text-slate-800 dark:text-white uppercase tracking-wider">
                          {item.item_slug?.includes("glassmorphism") && "Glass"}
                          {item.item_slug?.includes("matrix") && "Matrix"}
                          {item.item_slug?.includes("holographic") && "Holo"}
                          {item.item_slug?.includes("vantablack") && "Void"}
                          {item.item_slug?.includes("frame") && (item.item_slug?.includes("red") ? "Red" : "Blue")}
                          {item.item_slug === "profile-glow" && "Glow"}
                          {!item.item_slug?.includes("glassmorphism") &&
                           !item.item_slug?.includes("matrix") &&
                           !item.item_slug?.includes("holographic") &&
                           !item.item_slug?.includes("vantablack") &&
                           !item.item_slug?.includes("frame") &&
                           item.item_slug !== "profile-glow" && item.item_slug}
                        </div>
                      </div>
                      <h3 className="font-bold text-slate-800 dark:text-white mb-2">{item.item_name}</h3>
                      <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">
                        Duration: <span className="font-semibold">{item.duration || "Permanent"}</span>
                      </p>
                      <div className="flex items-center justify-between mb-3">
                        <RarityBadge slug={item.item_slug} />
                        <span className="text-lg font-black text-slate-800 dark:text-white">
                          {item.worth} <span className="text-sm">waves</span>
                        </span>
                      </div>
                      <button
                        onClick={() => handlePurchase(item)}
                        disabled={purchasing === item.id}
                        className={`w-full py-2 rounded-lg font-semibold transition-all duration-200 shadow-md hover:shadow-lg disabled:opacity-50 ${
                          cat === "digital_flex"
                            ? "bg-slate-900 dark:bg-white text-white dark:text-slate-900 hover:bg-blue-600 dark:hover:bg-blue-100"
                            : "bg-gradient-to-r from-flow-600 to-coral-600 text-white hover:from-flow-700 hover:to-coral-700"
                        }`}
                      >
                        {purchasing === item.id ? "Processing..." : "Purchase"}
                      </button>
                    </div>
                  )
                )}
              </div>
            </section>
          );
        })}

        {items.length === 0 && (
          <div className="text-center py-16">
            <p className="text-gray-400 text-lg">No store items available yet.</p>
          </div>
        )}
      </div>
    </div>
  );
}
