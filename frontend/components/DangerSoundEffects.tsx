'use client';

import { useState, useEffect } from 'react';
import { FaVolumeUp, FaVolumeMute, FaExclamationTriangle } from 'react-icons/fa';

export default function DangerSoundEffects() {
  const [isEnabled, setIsEnabled] = useState(false);
  const [audioContext, setAudioContext] = useState<AudioContext | null>(null);

  useEffect(() => {
    if (isEnabled && !audioContext) {
      const context = new (window.AudioContext || (window as any).webkitAudioContext)();
      setAudioContext(context);
    }
  }, [isEnabled, audioContext]);

  const playDangerSound = () => {
    if (!audioContext || !isEnabled) return;

    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.frequency.setValueAtTime(200, audioContext.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(50, audioContext.currentTime + 0.5);

    gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.5);

    oscillator.start(audioContext.currentTime);
    oscillator.stop(audioContext.currentTime + 0.5);
  };

  const playWarningSound = () => {
    if (!audioContext || !isEnabled) return;

    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
    oscillator.frequency.setValueAtTime(600, audioContext.currentTime + 0.1);
    oscillator.frequency.setValueAtTime(800, audioContext.currentTime + 0.2);

    gainNode.gain.setValueAtTime(0.05, audioContext.currentTime);
    gainNode.gain.setValueAtTime(0, audioContext.currentTime + 0.3);

    oscillator.start(audioContext.currentTime);
    oscillator.stop(audioContext.currentTime + 0.3);
  };

  useEffect(() => {
    if (!isEnabled) return;

    const dangerInterval = setInterval(() => {
      if (Math.random() > 0.7) {
        playDangerSound();
      }
    }, 5000 + Math.random() * 10000);

    const warningInterval = setInterval(() => {
      if (Math.random() > 0.8) {
        playWarningSound();
      }
    }, 3000 + Math.random() * 8000);

    return () => {
      clearInterval(dangerInterval);
      clearInterval(warningInterval);
    };
  }, [isEnabled]);

  return (
    <div className="fixed top-4 left-4 z-50">
      <div className="bg-black/90 border-2 border-red-500 rounded-lg p-3 danger-pulse">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsEnabled(!isEnabled)}
            className={`p-2 rounded transition-all duration-300 ${
              isEnabled 
                ? 'bg-red-600 text-white hover:bg-red-700' 
                : 'bg-gray-600 text-gray-300 hover:bg-gray-700'
            }`}
            title={isEnabled ? 'Отключить звуки' : 'Включить звуки'}
          >
            {isEnabled ? <FaVolumeUp className="w-4 h-4" /> : <FaVolumeMute className="w-4 h-4" />}
          </button>
          <div className="text-xs">
            <div className="text-red-400 font-bold">ЗВУКИ ОПАСНОСТИ</div>
            <div className="text-red-300 text-xs">
              {isEnabled ? 'ВКЛЮЧЕНЫ' : 'ОТКЛЮЧЕНЫ'}
            </div>
          </div>
        </div>
        
        {isEnabled && (
          <div className="mt-2 p-2 bg-red-900/30 rounded border border-red-500">
            <div className="flex items-center gap-1 text-red-300 text-xs">
              <FaExclamationTriangle className="w-3 h-3" />
              <span>Громкость на минимум!</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
} 