import { Sun, Moon } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';

const ThemeToggle = () => {
  const { isDarkMode, toggleTheme } = useTheme();

  return (
    <button
      onClick={toggleTheme}
      className="p-2 rounded-lg transition-colors duration-200 bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-700"
      title={isDarkMode ? '切换到明亮模式' : '切换到黑暗模式'}
    >
      {isDarkMode ? (
        <Sun className="h-5 w-5 text-yellow-500" />
      ) : (
        <Moon className="h-5 w-5 text-gray-600" />
      )}
    </button>
  );
};

export default ThemeToggle;
