import { createContext, useContext, useState, useEffect, useCallback } from "react";
import api from "../utils/api";
import { connectSocket, disconnectSocket, joinChannel } from "../utils/realtime";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const stored = localStorage.getItem("user");
    return stored ? JSON.parse(stored) : null;
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (token) {
      api
        .get("/auth/me")
        .then((res) => {
          const u = res.data.data.user;
          setUser(u);
          localStorage.setItem("user", JSON.stringify(u));
          connectSocket(token);
        })
        .catch(() => {
          localStorage.removeItem("token");
          localStorage.removeItem("user");
          setUser(null);
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
    return () => disconnectSocket();
  }, []);

  const login = async (email, password) => {
    const res = await api.post("/auth/login", { email, password });
    const { token, user: u } = res.data.data;
    localStorage.setItem("token", token);
    localStorage.setItem("user", JSON.stringify(u));
    setUser(u);
    connectSocket(token);
    return u;
  };

  const register = async (userData) => {
    const res = await api.post("/auth/register", { user: userData });
    const { token, user: u } = res.data.data;
    localStorage.setItem("token", token);
    localStorage.setItem("user", JSON.stringify(u));
    setUser(u);
    connectSocket(token);
    return u;
  };

  const logout = async () => {
    try {
      await api.post("/auth/logout");
    } catch {}
    disconnectSocket();
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    setUser(null);
  };

  const updateUser = (u) => {
    setUser(u);
    localStorage.setItem("user", JSON.stringify(u));
  };

  return (
    <AuthContext.Provider
      value={{ user, loading, login, register, logout, updateUser }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
