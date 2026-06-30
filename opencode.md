# Vibeflow Session State

## What's Done
- LiveView uploads replaced with fetch-based background uploads — files survive page nav, publish button always enabled
- `Vibeflow.UploadTracker` GenServer — tracks upload state, enqueues Oban job when all files for a post complete
- API endpoints: `POST /api/uploads/init`, `PUT /api/uploads/:id/data`
- Rewrote `create_post_live.ex` — no `allow_upload`, text-only posts publish directly
- Rewrote `create_post_live.html.heex` — JS-driven upload UI with global `__vibeflow_uploadStore` to survive LiveView re-renders
- Capture-phase submit listener injects hidden `post[upload_ids][]` inputs before LiveView serializes form
- `require_authenticated_user` returns JSON 401 for API requests
- File input/drop zone re-bound via `updated()` lifecycle to survive re-render
- Fixed hidden inputs wiped on LiveView re-render — global store + capture-phase submit
- New users get 500 points on registration (`Accounts.register_user/1` calls `grant_points/2`)
- Tests: 8 for UploadTracker, 5 for upload controller

## Known Issues / Blockers
- `PostUploadWorker` → R2 upload times out: `Req.TransportError{reason: :timeout}` from `put_object/4` in `upload_cloudinary.ex`. R2 endpoint reachable via curl/`:httpc` (<1s). Fix applied: added `finch: Vibeflow.Finch` and increased `receive_timeout: 60_000`. Needs verification.
- `GET /icon-192.png` → `Phoenix.Router.NoRouteError` (minor, no route for favicon)

## Key Files
- `lib/vibeflow/upload_tracker.ex` — upload state tracking GenServer
- `lib/vibeflow/application.ex` — UploadTracker + Finch in supervision tree
- `lib/vibeflow_web/router.ex` — `upload_api` pipeline + routes
- `lib/vibeflow_web/controllers/api/upload_controller.ex` — init/upload endpoints
- `lib/vibeflow_web/live/create_post_live.ex` — simplified post creation LiveView
- `lib/vibeflow_web/live/create_post_live.html.heex` — JS upload UI
- `assets/js/app.js` — `CreatePostUpload` hook, global upload store, capture-phase submit
- `lib/vibeflow_web/user_auth.ex` — `require_authenticated_user` JSON 401 handling
- `lib/vibeflow/infrastructure/upload_cloudinary.ex` — R2 upload via Req (timeout TBD)
- `lib/vibeflow/accounts.ex` — `register_user/1` grants 500 points

## Testing
- `mix test test/vibeflow/upload_tracker_test.exs`
- `mix test test/vibeflow_web/controllers/api/upload_controller_test.exs`
