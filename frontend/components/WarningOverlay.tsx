'use client';

import { useState, useEffect } from 'react';

const warningMessages = [
    'ВНИМАНИЕ: НЕСАНКЦИОНИРОВАННЫЙ ДОСТУП',
    'ОПАСНОСТЬ: СИСТЕМА ПОД НАБЛЮДЕНИЕМ',
    'ПРЕДУПРЕЖДЕНИЕ: АКТИВИРОВАНА ЗАЩИТА',
    'ALERT: UNAUTHORIZED ACCESS DETECTED',
    'WARNING: SYSTEM COMPROMISED',
    'DANGER: INTRUSION DETECTED'
];

export default function WarningOverlay() {
    const [currentMessage, setCurrentMessage] = useState(0);
    const [isVisible, setIsVisible] = useState(false);

    useEffect(() => {
        const messageInterval = setInterval(() => {
            setCurrentMessage(prev => (prev + 1) % warningMessages.length);
        }, 2000);

        const visibilityInterval = setInterval(() => {
            setIsVisible(prev => !prev);
        }, 1000);

        return () => {
            clearInterval(messageInterval);
            clearInterval(visibilityInterval);
        };
    }, []);

    if (!isVisible) return null;

    return (
        <div className="warning-overlay">
            <div
                className="glitch neon-text"
                data-text={warningMessages[currentMessage]}
                style={{
                    position: 'fixed',
                    top: '50%',
                    left: '50%',
                    transform: 'translate(-50%, -50%)',
                    fontSize: '2rem',
                    fontWeight: 'bold',
                    color: '#ff0040',
                    textAlign: 'center',
                    zIndex: 1001,
                    textShadow: '0 0 20px #ff0040, 0 0 40px #ff0040'
                }}
            >
                {warningMessages[currentMessage]}
            </div>
        </div>
    );
} 