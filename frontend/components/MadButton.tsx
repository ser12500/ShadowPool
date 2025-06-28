"use client";

import { motion, useMotionValue, useTransform, useSpring } from 'framer-motion';
import { ReactNode, useRef, useEffect } from 'react';

interface MadButtonProps {
    children: ReactNode;
    onClick?: () => void;
    className?: string;
    variant?: 'primary' | 'secondary' | 'glow' | 'neon';
    size?: 'sm' | 'md' | 'lg';
    disabled?: boolean;
    loading?: boolean;
}

export default function MadButton({
    children,
    onClick,
    className = "",
    variant = 'primary',
    size = 'md',
    disabled = false,
    loading = false
}: MadButtonProps) {
    const ref = useRef<HTMLButtonElement>(null);
    const mouseX = useMotionValue(0);
    const mouseY = useMotionValue(0);

    const rotateX = useTransform(mouseY, [-0.5, 0.5], [10, -10]);
    const rotateY = useTransform(mouseX, [-0.5, 0.5], [-10, 10]);

    const springConfig = { damping: 25, stiffness: 400 };
    const springRotateX = useSpring(rotateX, springConfig);
    const springRotateY = useSpring(rotateY, springConfig);

    useEffect(() => {
        const handleMouseMove = (e: MouseEvent) => {
            if (!ref.current || disabled) return;

            const rect = ref.current.getBoundingClientRect();
            const centerX = rect.left + rect.width / 2;
            const centerY = rect.top + rect.height / 2;

            mouseX.set((e.clientX - centerX) / (rect.width / 2));
            mouseY.set((e.clientY - centerY) / (rect.height / 2));
        };

        const handleMouseLeave = () => {
            mouseX.set(0);
            mouseY.set(0);
        };

        document.addEventListener('mousemove', handleMouseMove);
        document.addEventListener('mouseleave', handleMouseLeave);

        return () => {
            document.removeEventListener('mousemove', handleMouseMove);
            document.removeEventListener('mouseleave', handleMouseLeave);
        };
    }, [disabled, mouseX, mouseY]);

    const sizeClasses = {
        sm: 'px-4 py-2 text-sm',
        md: 'px-6 py-3 text-base',
        lg: 'px-8 py-4 text-lg'
    };

    const variantClasses = {
        primary: 'bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white',
        secondary: 'bg-gradient-to-r from-gray-600 to-gray-700 hover:from-gray-700 hover:to-gray-800 text-white',
        glow: 'bg-gradient-to-r from-indigo-500 to-purple-500 hover:from-indigo-600 hover:to-purple-600 text-white shadow-lg shadow-indigo-500/50',
        neon: 'bg-transparent border-2 border-cyan-400 text-cyan-400 hover:bg-cyan-400 hover:text-black shadow-lg shadow-cyan-400/50'
    };

    return (
        <motion.button
            ref={ref}
            onClick={onClick}
            disabled={disabled || loading}
            className={`
        relative group font-semibold rounded-xl transition-all duration-300
        ${sizeClasses[size]}
        ${variantClasses[variant]}
        ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
        ${className}
      `}
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            whileHover={!disabled ? {
                scale: 1.05,
                transition: { duration: 0.2 }
            } : undefined}
            whileTap={!disabled ? {
                scale: 0.95,
                transition: { duration: 0.1 }
            } : undefined}
            style={{
                transformStyle: "preserve-3d",
                perspective: "1000px",
                rotateX: springRotateX,
                rotateY: springRotateY
            }}
        >
            {/* Безумные частицы */}
            <div className="absolute -top-1 -left-1 w-1 h-1 bg-white rounded-full opacity-0 group-hover:opacity-100 animate-ping" />
            <div className="absolute -top-1 -right-1 w-1 h-1 bg-white rounded-full opacity-0 group-hover:opacity-100 animate-ping" style={{ animationDelay: '0.2s' }} />
            <div className="absolute -bottom-1 -left-1 w-1 h-1 bg-white rounded-full opacity-0 group-hover:opacity-100 animate-ping" style={{ animationDelay: '0.4s' }} />
            <div className="absolute -bottom-1 -right-1 w-1 h-1 bg-white rounded-full opacity-0 group-hover:opacity-100 animate-ping" style={{ animationDelay: '0.6s' }} />

            {/* Безумная подсветка */}
            <div className="absolute inset-0 rounded-xl bg-gradient-to-r from-white/0 via-white/20 to-white/0 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

            {/* Безумные линии */}
            <div className="absolute inset-0 rounded-xl overflow-hidden">
                <motion.div
                    className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-white to-transparent"
                    initial={{ x: '-100%' }}
                    whileHover={{ x: '100%' }}
                    transition={{ duration: 0.6 }}
                />
                <motion.div
                    className="absolute bottom-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-white to-transparent"
                    initial={{ x: '100%' }}
                    whileHover={{ x: '-100%' }}
                    transition={{ duration: 0.6 }}
                />
            </div>

            {/* Контент */}
            <div className="relative z-10 flex items-center justify-center gap-2">
                {loading && (
                    <motion.div
                        className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full"
                        animate={{ rotate: 360 }}
                        transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                    />
                )}
                {children}
            </div>

            {/* Безумная пульсация для glow варианта */}
            {variant === 'glow' && (
                <motion.div
                    className="absolute inset-0 rounded-xl bg-gradient-to-r from-indigo-500 to-purple-500"
                    animate={{
                        scale: [1, 1.05, 1],
                        opacity: [0.3, 0.6, 0.3]
                    }}
                    transition={{
                        duration: 2,
                        repeat: Infinity,
                        ease: "easeInOut"
                    }}
                />
            )}

            {/* Безумная неоновая подсветка */}
            {variant === 'neon' && (
                <motion.div
                    className="absolute inset-0 rounded-xl bg-cyan-400/20 blur-xl"
                    animate={{
                        scale: [1, 1.1, 1],
                        opacity: [0.3, 0.6, 0.3]
                    }}
                    transition={{
                        duration: 1.5,
                        repeat: Infinity,
                        ease: "easeInOut"
                    }}
                />
            )}
        </motion.button>
    );
} 