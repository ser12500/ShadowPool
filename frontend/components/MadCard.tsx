"use client";

import { motion, useMotionValue, useTransform, useSpring } from 'framer-motion';
import { ReactNode, useRef, useEffect } from 'react';

interface MadCardProps {
    children: ReactNode;
    className?: string;
    delay?: number;
    hover?: boolean;
    glow?: boolean;
    pulse?: boolean;
    float?: boolean;
}

export default function MadCard({
    children,
    className = "",
    delay = 0,
    hover = true,
    glow = true,
    pulse = false,
    float = false
}: MadCardProps) {
    const ref = useRef<HTMLDivElement>(null);
    const mouseX = useMotionValue(0);
    const mouseY = useMotionValue(0);

    const rotateX = useTransform(mouseY, [-0.5, 0.5], [15, -15]);
    const rotateY = useTransform(mouseX, [-0.5, 0.5], [-15, 15]);

    const springConfig = { damping: 20, stiffness: 300 };
    const springRotateX = useSpring(rotateX, springConfig);
    const springRotateY = useSpring(rotateY, springConfig);

    useEffect(() => {
        const handleMouseMove = (e: MouseEvent) => {
            if (!ref.current) return;

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

        if (hover) {
            document.addEventListener('mousemove', handleMouseMove);
            document.addEventListener('mouseleave', handleMouseLeave);
        }

        return () => {
            document.removeEventListener('mousemove', handleMouseMove);
            document.removeEventListener('mouseleave', handleMouseLeave);
        };
    }, [hover, mouseX, mouseY]);

    return (
        <motion.div
            ref={ref}
            className={`relative group ${className}`}
            initial={{ opacity: 0, y: 50, scale: 0.8 }}
            animate={{
                opacity: 1,
                scale: 1,
                y: float ? [0, -10, 0] : 0
            }}
            transition={{
                duration: 0.8,
                delay,
                ease: [0.25, 0.46, 0.45, 0.94],
                y: float ? {
                    duration: 3,
                    repeat: Infinity,
                    ease: "easeInOut"
                } : undefined
            }}
            whileHover={hover ? {
                scale: 1.05,
                transition: { duration: 0.2 }
            } : undefined}
            style={hover ? {
                transformStyle: "preserve-3d",
                perspective: "1000px"
            } : undefined}
        >
            {/* Безумный градиентный фон */}
            <div className="absolute inset-0 rounded-2xl bg-gradient-to-br from-indigo-500/20 via-purple-500/20 to-pink-500/20 backdrop-blur-xl border border-white/10" />

            {/* Безумные частицы */}
            {glow && (
                <>
                    <div className="absolute -top-1 -left-1 w-2 h-2 bg-indigo-400 rounded-full opacity-0 group-hover:opacity-100 animate-ping" />
                    <div className="absolute -top-1 -right-1 w-1 h-1 bg-purple-400 rounded-full opacity-0 group-hover:opacity-100 animate-ping" style={{ animationDelay: '0.5s' }} />
                    <div className="absolute -bottom-1 -left-1 w-1 h-1 bg-pink-400 rounded-full opacity-0 group-hover:opacity-100 animate-ping" style={{ animationDelay: '1s' }} />
                    <div className="absolute -bottom-1 -right-1 w-2 h-2 bg-cyan-400 rounded-full opacity-0 group-hover:opacity-100 animate-ping" style={{ animationDelay: '1.5s' }} />
                </>
            )}

            {/* Безумная подсветка */}
            {glow && (
                <div className="absolute inset-0 rounded-2xl bg-gradient-to-r from-indigo-500/0 via-purple-500/20 to-pink-500/0 opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
            )}

            {/* Основной контент */}
            <motion.div
                className="relative z-10 p-6 rounded-2xl bg-white/5 backdrop-blur-xl border border-white/10"
                style={hover ? {
                    transform: "translateZ(50px)",
                    rotateX: springRotateX,
                    rotateY: springRotateY
                } : undefined}
            >
                {children}
            </motion.div>

            {/* Безумная пульсация */}
            {pulse && (
                <motion.div
                    className="absolute inset-0 rounded-2xl bg-gradient-to-r from-indigo-500/20 to-purple-500/20"
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

            {/* Безумные линии */}
            <div className="absolute inset-0 rounded-2xl overflow-hidden">
                <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-indigo-500 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
                <div className="absolute bottom-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-purple-500 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
                <div className="absolute top-0 left-0 w-px h-full bg-gradient-to-b from-transparent via-pink-500 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
                <div className="absolute top-0 right-0 w-px h-full bg-gradient-to-b from-transparent via-cyan-500 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
            </div>
        </motion.div>
    );
} 