"use client";

import { useEffect, useState } from "react";

interface Particle {
    id: number;
    x: number;
    y: number;
    size: number;
    speedX: number;
    speedY: number;
    opacity: number;
    color: string;
}

export default function ParticleBackground() {
    const [particles, setParticles] = useState<Particle[]>([]);

    useEffect(() => {
        const colors = [
            "rgb(99, 102, 241)", // indigo
            "rgb(139, 92, 246)", // purple
            "rgb(236, 72, 153)", // pink
            "rgb(245, 158, 11)", // amber
            "rgb(16, 185, 129)", // emerald
            "rgb(59, 130, 246)", // blue
        ];

        const generateParticles = () => {
            const newParticles: Particle[] = [];
            const particleCount = 50;

            for (let i = 0; i < particleCount; i++) {
                newParticles.push({
                    id: i,
                    x: Math.random() * window.innerWidth,
                    y: Math.random() * window.innerHeight,
                    size: Math.random() * 4 + 1,
                    speedX: (Math.random() - 0.5) * 2,
                    speedY: (Math.random() - 0.5) * 2,
                    opacity: Math.random() * 0.5 + 0.1,
                    color: colors[Math.floor(Math.random() * colors.length)],
                });
            }

            setParticles(newParticles);
        };

        generateParticles();

        const animateParticles = () => {
            setParticles(prevParticles =>
                prevParticles.map(particle => {
                    let newX = particle.x + particle.speedX;
                    let newY = particle.y + particle.speedY;

                    // Отскок от границ
                    if (newX <= 0 || newX >= window.innerWidth) {
                        particle.speedX *= -1;
                        newX = particle.x + particle.speedX;
                    }
                    if (newY <= 0 || newY >= window.innerHeight) {
                        particle.speedY *= -1;
                        newY = particle.y + particle.speedY;
                    }

                    return {
                        ...particle,
                        x: newX,
                        y: newY,
                    };
                })
            );
        };

        const interval = setInterval(animateParticles, 50);

        const handleResize = () => {
            generateParticles();
        };

        window.addEventListener("resize", handleResize);

        return () => {
            clearInterval(interval);
            window.removeEventListener("resize", handleResize);
        };
    }, []);

    return (
        <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
            {particles.map(particle => (
                <div
                    key={particle.id}
                    className="absolute rounded-full animate-float"
                    style={{
                        left: `${particle.x}px`,
                        top: `${particle.y}px`,
                        width: `${particle.size}px`,
                        height: `${particle.size}px`,
                        backgroundColor: particle.color,
                        opacity: particle.opacity,
                        animationDelay: `${particle.id * 0.1}s`,
                        animationDuration: `${3 + particle.id % 3}s`,
                    }}
                />
            ))}

            {/* Дополнительные эффекты */}
            <div className="absolute top-1/4 left-1/4 w-32 h-32 rounded-full opacity-10 animate-pulse-glow"
                style={{ background: 'radial-gradient(circle, rgb(99, 102, 241), transparent)' }} />
            <div className="absolute bottom-1/4 right-1/4 w-24 h-24 rounded-full opacity-10 animate-pulse-glow"
                style={{ background: 'radial-gradient(circle, rgb(139, 92, 246), transparent)', animationDelay: '1s' }} />
            <div className="absolute top-1/2 left-1/2 w-16 h-16 rounded-full opacity-10 animate-pulse-glow"
                style={{ background: 'radial-gradient(circle, rgb(236, 72, 153), transparent)', animationDelay: '2s' }} />
        </div>
    );
} 