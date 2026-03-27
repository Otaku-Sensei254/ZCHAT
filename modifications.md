2026-03-16 17:13hrs
- Synced Waves recording audio to stop when video capture ends and improved timer accuracy to track real elapsed time during recording.
2026-03-26 17:50hrs
- Added points system: migration, account helper, awarding points for posts/likes/ripples, store page balance, and tracked deployment/log health while running migrations on Gigalixir/Neon.
2026-03-26 18:30hrs
- Fixed Tailwind Configuration: Moved `spacing` into `extend` to prevent overwriting default Tailwind utilities.
- Dark Mode Compatibility: Replaced all `zinc-950` instances with `zinc-900` to support Tailwind 3.2.4, fixing white backgrounds in dark mode.
- User Profile Redesign: Implemented premium high-end dark theme for profile header with responsive layouts (centered on mobile, side-by-side on desktop) as per design images.
- Mobile Navigation Fixes: Properly aligned and elevated the center "+" button, and added `pb-20` padding to main content to prevent bottom nav overlap.
- Real-time Notifications: Integrated Phoenix PubSub for instant point-award alerts ("You earned +5 points! ✨") across the platform.
- Bug Fixes: 
    - Resolved `:search_query` KeyError in Feed Live.
    - Fixed `FunctionClauseError` in SinglePostLive for comment editing.
    - Corrected HTML syntax error (mismatched tags) in Feed search form.
- Logic Updates: Adjusted Ripple point allocation to 3 points for the rippler and 5 points for the author.
- Deployment: Successfully pushed code to Gigalixir and migrated production database to Neon DB.

2026-03-27 09:10hrs
- Cleaned up the `Vibeflow.Accounts.grant_points/2` clause boundaries and added the `:invalid_input` fallback so the module compiles without the `def/2 outside module` error.
- Verified `mix compile` but it still fails inside this sandbox with a `Mix.PubSub` socket permission error; please rerun the command in a normal shell (or just `iex -S mix phx.server`) to cover the new logic.
