import { useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function Home() {
  const { user } = useAuth();

  return (
    <div className="min-h-[calc(100vh-56px)] bg-gradient-to-br from-tide-50 via-white to-flow-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <div className="max-w-4xl mx-auto px-4 pt-16 sm:pt-20 pb-16 text-center">
        <div className="inline-flex items-center gap-2 px-3 py-1 bg-tide-50 dark:bg-tide-900/30 text-tide-600 dark:text-tide-400 rounded-full text-xs font-medium mb-6">
          <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
          Connect with the world
        </div>

        <h1 className="text-4xl sm:text-6xl font-bold mb-4 bg-gradient-to-r from-tide-600 via-flow-600 to-coral-500 bg-clip-text text-transparent leading-tight">
          Welcome to Vibeflow
        </h1>
        <p className="text-base sm:text-lg text-gray-500 dark:text-gray-400 mb-10 max-w-md mx-auto">
          Connect, create, and share your world in real-time
        </p>

        {user ? (
          <Link
            to="/feed"
            className="inline-flex items-center gap-2 bg-gradient-to-r from-tide-600 to-flow-600 text-white px-8 py-3 rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 transition-all duration-200 shadow-lg shadow-tide-200 dark:shadow-tide-900/30"
          >
            View Feed
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" /></svg>
          </Link>
        ) : (
          <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center">
            <Link
              to="/register"
              className="bg-gradient-to-r from-tide-600 to-flow-600 text-white px-8 py-3 rounded-xl font-semibold hover:from-tide-700 hover:to-flow-700 transition-all duration-200 shadow-lg shadow-tide-200 dark:shadow-tide-900/30"
            >
              Create Account
            </Link>
            <Link
              to="/login"
              className="border-2 border-gray-200 dark:border-gray-600 text-gray-700 dark:text-gray-300 px-8 py-3 rounded-xl font-semibold hover:border-tide-300 dark:hover:border-tide-600 hover:text-tide-600 dark:hover:text-tide-400 transition-all duration-200"
            >
              Sign In
            </Link>
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6 mt-16 max-w-3xl mx-auto">
          {[
            { title: "Connect Globally", desc: "Share your thoughts with the world in real-time", icon: "🌍" },
            { title: "Lightning Fast", desc: "Real-time messaging, likes, and notifications", icon: "⚡" },
            { title: "Secure & Private", desc: "Your data is always protected and private", icon: "🔒" },
          ].map((f) => (
            <div
              key={f.title}
              className="p-5 sm:p-6 rounded-xl bg-white/60 dark:bg-gray-800/60 backdrop-blur border border-gray-100 dark:border-gray-700/50 hover:shadow-lg hover:border-tide-200 dark:hover:border-tide-700/50 transition-all duration-200"
            >
              <span className="text-2xl mb-3 block">{f.icon}</span>
              <h3 className="font-semibold mb-1.5">{f.title}</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}