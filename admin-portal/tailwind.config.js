/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // FIN1 Brand Colors
        fin1: {
          primary: '#1E3A5F',      // Deep blue (primary)
          secondary: '#2E5A8E',    // Medium blue
          accent: '#4A90D9',       // Light blue (accent)
          success: '#10B981',      // Green
          warning: '#F59E0B',      // Amber
          danger: '#EF4444',       // Red
          info: '#3B82F6',         // Blue
          dark: '#0F172A',         // Near black
          light: '#F8FAFC',        // Near white
          muted: '#64748B',        // Gray
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
