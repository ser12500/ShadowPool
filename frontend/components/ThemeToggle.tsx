"use client";

import { useState, useEffect } from "react";
import { FaSun, FaMoon, FaMagic } from "react-icons/fa";

export default function ThemeToggle() {
    const [theme, setTheme] = useState<"light" | "dark">("light");
    const [isAnimating, setIsAnimating] = useState(false);

    useEffect(() => {
        const savedTheme = localStorage.getItem("theme") as "light" | "dark" || "light";
        setTheme(savedTheme);
        document.documentElement.setAttribute("data-theme", savedTheme);
    }, []);

    const toggleTheme = () => {
        setIsAnimating(true);
        const newTheme = theme === "light" ? "dark" : "light";

        // Анимация перехода
        document.documentElement.style.transition = "all 0.5s ease";
        document.documentElement.setAttribute("data-theme", newTheme);

        setTheme(newTheme);
        localStorage.setItem("theme", newTheme);

        setTimeout(() => {
            setIsAnimating(false);
            document.documentElement.style.transition = "";
        }, 500);
    };

    return (
        <button
            onClick={toggleTheme}
            disabled={isAnimating}
            className={`
                relative p-3 rounded-full transition-all duration-500
                ${isAnimating ? 'animate-bounce-in' : 'animate-float'}
                ${theme === 'dark'
                    ? 'bg-gradient-to-r from-purple-600 to-blue-600 text-white'
                    : 'bg-gradient-to-r from-yellow-400 to-orange-500 text-white'
                }
                hover:scale-110 hover:rotate-12
                shadow-lg hover:shadow-2xl
                border-2 border-transparent
                ${theme === 'dark' ? 'border-purple-400' : 'border-yellow-300'}
            `}
            style={{
                background: theme === 'dark'
                    ? 'linear-gradient(45deg, #8b5cf6, #3b82f6, #6366f1)'
                    : 'linear-gradient(45deg, #f59e0b, #f97316, #ea580c)'
            }}
        >
            <div className="relative z-10">
                {theme === "light" ? (
                    <FaMoon className="w-5 h-5" />
                ) : (
                    <FaSun className="w-5 h-5" />
                )}
            </div>

            {/* Безумные эффекты */}
            <div className="absolute inset-0 rounded-full opacity-0 hover:opacity-100 transition-opacity duration-300">
                <div className="absolute inset-0 rounded-full animate-pulse-glow"></div>
                <div className="absolute inset-0 rounded-full animate-rotate-gradient"></div>
            </div>

            {/* Частицы */}
            <div className="absolute -top-1 -right-1 w-2 h-2 bg-white rounded-full animate-float"></div>
            <div className="absolute -bottom-1 -left-1 w-1 h-1 bg-white rounded-full animate-float" style={{ animationDelay: '1s' }}></div>
        </button>
    );
} 