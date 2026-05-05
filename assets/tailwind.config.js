// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  darkMode: 'class',
  content: [
    "./js/**/*.js",
    "../lib/vibeflow_web.ex",
    "../lib/vibeflow_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#6366F1",
        dark: {
          800: '#1f2937',
          900: '#111827',
        }
      },
      transitionProperty: {
        'theme': 'background-color, border-color, color',
      },
      spacing: {
        'safe': 'env(safe-area-inset-left)',
      },
      animation: {
        bubble: 'bubble 10s ease-in infinite',
        'bubble-slow': 'bubble 15s ease-in infinite',
        'bubble-fast': 'bubble 7s ease-in infinite',
      },
      keyframes: {
        bubble: {
          '0%': { transform: 'translateY(0) scale(1)', opacity: '0' },
          '10%': { opacity: '0.3' },
          '100%': { transform: 'translateY(-100vh) scale(1.5)', opacity: '0' },
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    plugin(({addVariant}) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"]))
  ]
}
