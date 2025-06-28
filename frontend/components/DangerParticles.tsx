'use client';

import { useEffect, useState } from 'react';

interface Particle {
    id: number;
    x: number;
    y: number;
    speed: number;
    size: number;
    color: string;
}

export default function DangerParticles() {
    const [particles, setParticles] = useState<Particle[]>([]);

    useEffect(() => {
        const colors = ['#ff0040', '#ff6600', '#ffff00', '#ff0000'];

        const createParticle = (): Particle => ({
            id: Math.random(),
            x: Math.random() * window.innerWidth,
            y: -10,
            speed: 1 + Math.random() * 3,
            size: 2 + Math.random() * 4,
            color: colors[Math.floor(Math.random() * colors.length)]
        });

        const interval = setInterval(() => {
            setParticles(prev => {
                const newParticles = prev
                    .map(p => ({ ...p, y: p.y + p.speed }))
                    .filter(p => p.y < window.innerHeight + 10);

                if (Math.random() < 0.3) {
                    newParticles.push(createParticle());
                }

                return newParticles;
            });
        }, 50);

        return () => clearInterval(interval);
    }, []);

    return (
        <div className="danger-particles">
            {particles.map(particle => (
                <div
                    key={particle.id}
                    className="particle"
                    style={{
                        left: particle.x,
                        top: particle.y,
                        width: particle.size,
                        height: particle.size,
                        backgroundColor: particle.color,
                        boxShadow: `0 0 ${particle.size * 2}px ${particle.color}`
                    }}
                />
            ))}
        </div>
    );
} 