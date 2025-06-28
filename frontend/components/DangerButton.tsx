'use client';

import { useState } from 'react';

interface DangerButtonProps {
    children: React.ReactNode;
    onClick?: () => void;
    variant?: 'danger' | 'warning' | 'illegal';
    size?: 'sm' | 'md' | 'lg';
    disabled?: boolean;
}

export default function DangerButton({
    children,
    onClick,
    variant = 'danger',
    size = 'md',
    disabled = false
}: DangerButtonProps) {
    const [isGlitching, setIsGlitching] = useState(false);

    const handleClick = () => {
        if (disabled) return;

        setIsGlitching(true);
        setTimeout(() => setIsGlitching(false), 300);

        if (onClick) onClick();
    };

    const getVariantStyles = () => {
        switch (variant) {
            case 'danger':
                return {
                    background: 'linear-gradient(45deg, #ff0040, #ff6600)',
                    borderColor: '#ff0040',
                    textShadow: '0 0 10px #ff0040'
                };
            case 'warning':
                return {
                    background: 'linear-gradient(45deg, #ffff00, #ff6600)',
                    borderColor: '#ffff00',
                    textShadow: '0 0 10px #ffff00'
                };
            case 'illegal':
                return {
                    background: 'linear-gradient(45deg, #ff0000, #800000)',
                    borderColor: '#ff0000',
                    textShadow: '0 0 10px #ff0000'
                };
            default:
                return {};
        }
    };

    const getSizeStyles = () => {
        switch (size) {
            case 'sm':
                return { padding: '0.5rem 1rem', fontSize: '0.875rem' };
            case 'lg':
                return { padding: '1rem 2rem', fontSize: '1.25rem' };
            default:
                return { padding: '0.75rem 1.5rem', fontSize: '1rem' };
        }
    };

    return (
        <button
            onClick={handleClick}
            disabled={disabled}
            className={`btn-danger ${isGlitching ? 'glitch' : ''} ${disabled ? '' : 'danger-pulse'}`}
            style={{
                ...getVariantStyles(),
                ...getSizeStyles(),
                border: '2px solid',
                borderRadius: '4px',
                color: 'white',
                fontFamily: 'Courier New, monospace',
                fontWeight: 'bold',
                textTransform: 'uppercase',
                letterSpacing: '2px',
                cursor: disabled ? 'not-allowed' : 'pointer',
                position: 'relative',
                overflow: 'hidden',
                transition: 'all 0.3s ease',
                opacity: disabled ? 0.5 : 1,
                ...(isGlitching && {
                    animation: 'glitch 0.3s infinite'
                })
            }}
        >
            {children}
            {!disabled && (
                <div
                    style={{
                        position: 'absolute',
                        top: 0,
                        left: 0,
                        width: '100%',
                        height: '100%',
                        background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent)',
                        transform: 'translateX(-100%)',
                        animation: 'danger-sweep 2s ease-in-out infinite'
                    }}
                />
            )}
        </button>
    );
}

// Добавляем стили для анимации
const style = document.createElement('style');
style.textContent = `
  @keyframes danger-sweep {
    0% { transform: translateX(-100%); }
    50% { transform: translateX(100%); }
    100% { transform: translateX(100%); }
  }
`;
document.head.appendChild(style); 