# Progress Notes

## 2026-03-06 Chat Enhancements

- Added emoji picker trigger to chat composer and moved it next to the upload icon.
- Integrated `emoji-mart` (`emoji-mart` + `@emoji-mart/data`) for full emoji search/categories/recent support.
- Added robust emoji picker fallback grid in JS if library initialization fails.
- Hardened emoji picker behavior against LiveView re-renders:
  - Rebinding logic on hook `updated()`.
  - Added `phx-update="ignore"` with stable `id` on emoji wrapper.
  - Outside-click close and `Esc` close support.
- Improved composer UX:
  - Switched from single-line input to auto-growing textarea.
  - Kept `Enter` to send, `Shift+Enter` for newline.
- Added URL highlighting in message text (clickable links).
- Added link preview cards:
  - Basic fallback card (domain + URL).
  - Async Open Graph/Twitter unfurling (title/description/image) via `Req`.
  - In-memory per-LiveView cache for fetched previews.
  - URL safety checks for unsupported/local hosts.
- Fixed unfurl runtime issues:
  - Replaced deprecated Req option `follow_redirects` with `redirect: [max_redirects: 5]`.
  - Replaced missing `Plug.HTML.html_unescape/1` call with local unescape helper.
- Fixed static asset 404s by updating `Plug.Static` `only:` allowlist:
  - `site.webmanifest`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png`, `browserconfig.xml`.
- Enabled media-only chat messages:
  - Relaxed message validation to allow payload when any of: `content`, `media_files`, or `shared_post_id`.
  - Prevented empty string content from being cast to `nil` using `cast(..., empty_values: [])` to satisfy DB `NOT NULL` on `messages.content`.
- Applied all chat-related updates in both app paths:
  - `lib/vibeflow_web/...` and `zchat/lib/zchat_web/...`
  - `assets/...` and `zchat/assets/...`

## 2026-03-06 Browser Notification Popups

- Implemented browser-level notification popups (Web Notifications API) for real-time app events.
- Mounted `NotificationsHook` globally in shared layouts so it is always active:
  - `lib/vibeflow_web/components/layouts/app.html.heex`
  - `lib/vibeflow_web/components/layouts/sidepanel.html.heex`
- Enhanced frontend notification hook in `assets/js/app.js`:
  - Requests notification permission on first user interaction.
  - Shows OS/browser popup notifications when tab is not visible.
  - Opens/focuses app and navigates on notification click.
  - Keeps existing in-app badge/modal refresh behavior.
- Updated `lib/vibeflow_web/user_activity_hook.ex` to push `new_notification` events with payloads for:
  - General notifications (likes/comments/follows/shares).
  - New incoming chat messages with deep-link target to chat conversation.
- Build verification:
  - `mix compile` completed successfully (existing warnings remain; no new compile errors from this change).

## 2026-04-02 Feed, Profiles, Socials, and Likes

- Feed behavior:
  - Inserted current user’s new posts at top in LiveView.
  - Promoted current user’s posts to top of page 1 feed without changing ripple logic.
- Roles/likes query fixes:
  - Added `user_roles` association on users and proper `belongs_to` links on user roles.
  - Fixed role-based featured ordering fragment to use bound parameters.
- Profile page:
  - Restored centered layout (padding instead of overriding `mx-auto`).
  - Bio linkification (URL detection + clickable links).
  - Socials display as icons with handles underneath.
  - Added “Add Socials” CTA on profile when none exist.
- User settings:
  - Added Social Accounts section (add/remove).
  - Enforced max 3 socials per user (server-side check).
- Single post comments:
  - Show initials for current user when avatar is missing.
- Likes/points:
  - Prevented points (including ripple points) on self-like of own posts.

## 2026-04-07 Chat Voice Notes & Audio Player

- Added custom WavePlayer audio message UI (play/pause, progress, single timer).
- Normalized media type detection so audio isn't misclassified as video.
- Updated Cloudinary upload routing for audio to use `raw/upload`.
- Refined recorder UI and behavior (stable hook wrapper, tap-to-start, stop button in recording bar).
- Increased chat scroll padding so fixed composer doesn't cover messages on mobile.
