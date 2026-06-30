import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import { ThemeProvider } from "./context/ThemeContext";
import Layout from "./components/Layout";
import ProtectedRoute from "./components/ProtectedRoute";
import Home from "./pages/Home";
import Login from "./pages/auth/Login";
import Register from "./pages/auth/Register";
import ForgotPassword from "./pages/auth/ForgotPassword";
import ResetPassword from "./pages/auth/ResetPassword";
import ConfirmEmail from "./pages/auth/ConfirmEmail";
import Feed from "./pages/feed/Feed";
import PostDetail from "./pages/posts/PostDetail";
import CreatePost from "./pages/posts/CreatePost";
import UserProfile from "./pages/profile/UserProfile";
import Settings from "./pages/profile/Settings";
import Chat from "./pages/chat/Chat";
import TagPage from "./pages/TagPage";
import Notifications from "./pages/Notifications";
import Currents from "./pages/Currents";
import CreateWave from "./pages/posts/CreateWave";
import CreateCurrent from "./pages/posts/CreateCurrent";
import WaveStore from "./pages/WaveStore";
import WaveViewer from "./pages/posts/WaveViewer";

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ThemeProvider>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/" element={<Home />} />
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/forgot-password" element={<ForgotPassword />} />
            <Route path="/reset-password/:token" element={<ResetPassword />} />
            <Route path="/confirm-email/:token" element={<ConfirmEmail />} />
            <Route path="/feed" element={<Feed />} />
            <Route path="/posts/:uuid" element={<PostDetail />} />
            <Route
              path="/posts/new"
              element={
                <ProtectedRoute>
                  <CreatePost />
                </ProtectedRoute>
              }
            />
            <Route path="/profile/:username" element={<UserProfile />} />
            <Route
              path="/settings"
              element={
                <ProtectedRoute>
                  <Settings />
                </ProtectedRoute>
              }
            />
            <Route
              path="/chat"
              element={
                <ProtectedRoute>
                  <Chat />
                </ProtectedRoute>
              }
            />
            <Route path="/currents" element={<Currents />} />
            <Route path="/wave-store" element={<WaveStore />} />
            <Route
              path="/waves/new"
              element={
                <ProtectedRoute>
                  <CreateWave />
                </ProtectedRoute>
              }
            />
            <Route
              path="/currents/new"
              element={
                <ProtectedRoute>
                  <CreateCurrent />
                </ProtectedRoute>
              }
            />
            <Route path="/tags/:tag" element={<TagPage />} />
            <Route
              path="/notifications"
              element={
                <ProtectedRoute>
                  <Notifications />
                </ProtectedRoute>
              }
            />
          </Route>
          <Route path="/waves/view/:username" element={<WaveViewer />} />
        </Routes>
        </ThemeProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
