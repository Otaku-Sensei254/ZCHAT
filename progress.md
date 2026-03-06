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
