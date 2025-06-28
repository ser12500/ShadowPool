"use client";

import { motion } from 'framer-motion';
import { ReactNode } from 'react';

interface MadTextProps {
    children: ReactNode;
    className?: string;
    variant?: 'title' | 'subtitle' | 'body' | 'gradient' | 'neon' | 'glitch';
    size?: 'xs' | 'sm' | 'base' | 'lg' | 'xl' | '2xl' | '3xl' | '4xl' | '5xl' | '6xl' | '7xl' | '8xl' | '9xl';
    delay?: number;
    stagger?: boolean;
    animate?: boolean;
}

export default function MadText({
    children,
    className = "",
    variant = 'body',
    size = 'base',
    delay = 0,
    stagger = false,
    animate = true
}: MadTextProps) {
    const sizeClasses = {
        xs: 'text-xs',
        sm: 'text-sm',
        base: 'text-base',
        lg: 'text-lg',
        xl: 'text-xl',
        '2xl': 'text-2xl',
        '3xl': 'text-3xl',
        '4xl': 'text-4xl',
        '5xl': 'text-5xl',
        '6xl': 'text-6xl',
        '7xl': 'text-7xl',
        '8xl': 'text-8xl',
        '9xl': 'text-9xl'
    };

    const variantClasses = {
        title: 'font-bold tracking-tight',
        subtitle: 'font-semibold tracking-wide',
        body: 'font-normal',
        gradient: 'bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 bg-clip-text text-transparent',
        neon: 'text-cyan-400 drop-shadow-[0_0_10px_rgba(34,211,238,0.5)]',
        glitch: 'relative text-white'
    };

    const glitchVariants = {
        initial: { x: 0 },
        animate: {
            x: [0, -2, 2, -2, 0],
            transition: {
                duration: 0.2,
                repeat: Infinity,
                repeatDelay: 3
            }
        }
    };

    const gradientVariants = {
        initial: { backgroundPosition: '0% 50%' },
        animate: {
            backgroundPosition: ['0% 50%', '100% 50%', '0% 50%'],
            transition: {
                duration: 3,
                repeat: Infinity,
                ease: "linear" as const
            }
        }
    };

    const neonVariants = {
        initial: { filter: 'drop-shadow(0 0 5px rgba(34,211,238,0.5))' },
        animate: {
            filter: [
                'drop-shadow(0 0 5px rgba(34,211,238,0.5))',
                'drop-shadow(0 0 20px rgba(34,211,238,0.8))',
                'drop-shadow(0 0 5px rgba(34,211,238,0.5))'
            ],
            transition: {
                duration: 2,
                repeat: Infinity,
                ease: "easeInOut" as const
            }
        }
    };

    if (variant === 'glitch') {
        return (
            <motion.div
                className={`${sizeClasses[size]} ${variantClasses[variant]} ${className}`}
                variants={glitchVariants}
                initial="initial"
                animate="animate"
            >
                <span className="relative z-10">{children}</span>
                <span className="absolute inset-0 text-red-500 opacity-50" style={{ transform: 'translate(2px, 2px)' }}>
                    {children}
                </span>
                <span className="absolute inset-0 text-blue-500 opacity-50" style={{ transform: 'translate(-2px, -2px)' }}>
                    {children}
                </span>
            </motion.div>
        );
    }

    if (variant === 'gradient') {
        return (
            <motion.div
                className={`${sizeClasses[size]} ${variantClasses[variant]} ${className}`}
                style={{
                    backgroundSize: '200% 200%'
                }}
                variants={gradientVariants}
                initial="initial"
                animate={animate ? "animate" : "initial"}
            >
                {children}
            </motion.div>
        );
    }

    if (variant === 'neon') {
        return (
            <motion.div
                className={`${sizeClasses[size]} ${variantClasses[variant]} ${className}`}
                variants={neonVariants}
                initial="initial"
                animate={animate ? "animate" : "initial"}
            >
                {children}
            </motion.div>
        );
    }

    if (stagger && typeof children === 'string') {
        return (
            <div className={`${sizeClasses[size]} ${variantClasses[variant]} ${className}`}>
                {children.split('').map((char, index) => (
                    <motion.span
                        key={index}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{
                            duration: 0.3,
                            delay: delay + index * 0.05,
                            ease: [0.25, 0.46, 0.45, 0.94]
                        }}
                        className="inline-block"
                    >
                        {char === ' ' ? '\u00A0' : char}
                    </motion.span>
                ))}
            </div>
        );
    }

    return (
        <motion.div
            className={`${sizeClasses[size]} ${variantClasses[variant]} ${className}`}
            initial={animate ? { opacity: 0, y: 20 } : false}
            animate={animate ? { opacity: 1, y: 0 } : false}
            transition={{
                duration: 0.6,
                delay,
                ease: [0.25, 0.46, 0.45, 0.94]
            }}
        >
            {children}
        </motion.div>
    );
} 