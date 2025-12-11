/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{vue,js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                // Modern "Galaxy" Dark Theme
                galaxy: {
                    bg: '#030712', // Very dark slate/black (Gray 950)
                    surface: '#111827', // Gray 900
                    surfaceHighlight: '#1f2937', // Gray 800
                    border: 'rgba(255, 255, 255, 0.08)', // Subtle white border
                    text: '#f3f4f6', // Gray 100
                    textMuted: '#9ca3af', // Gray 400
                    primary: '#818cf8', // Indigo 400 - Calm but creative
                    accent: '#2dd4bf', // Teal 400 - Fresh accent
                    danger: '#f87171', // Red 400
                }
            },
            fontFamily: {
                mono: ['"JetBrains Mono"', '"Fira Code"', 'monospace'],
                sans: ['"Inter"', 'system-ui', 'sans-serif'],
            },
            boxShadow: {
                'glass': '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
            },
            backgroundImage: {
                'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
                'subtle-glow': 'radial-gradient(circle at top center, rgba(129, 140, 248, 0.08), transparent 40%)',
            }
        },
    },
    plugins: [],
}
