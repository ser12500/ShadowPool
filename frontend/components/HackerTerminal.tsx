'use client';

import { useState, useEffect } from 'react';

interface TerminalLine {
    id: number;
    text: string;
    type: 'command' | 'output' | 'error' | 'warning';
    timestamp: string;
}

export default function HackerTerminal() {
    const [lines, setLines] = useState<TerminalLine[]>([]);
    const [currentInput, setCurrentInput] = useState('');

    const hackerCommands = [
        'INITIALIZING SHADOW PROTOCOL...',
        'BYPASSING SECURITY MEASURES...',
        'ACCESSING RESTRICTED DATABASES...',
        'ENCRYPTING COMMUNICATIONS...',
        'ESTABLISHING SECURE CONNECTION...',
        'WARNING: UNAUTHORIZED ACCESS DETECTED',
        'ERROR: SECURITY BREACH IMMINENT',
        'SYSTEM COMPROMISED - EVACUATE IMMEDIATELY'
    ];

    useEffect(() => {
        const addLine = (text: string, type: TerminalLine['type'] = 'output') => {
            const timestamp = new Date().toLocaleTimeString();
            setLines(prev => [...prev, {
                id: Date.now(),
                text,
                type,
                timestamp
            }]);
        };

        // Имитация загрузки системы
        const loadSequence = async () => {
            addLine('> INITIALIZING SHADOW POOL SYSTEM...', 'command');

            await new Promise(resolve => setTimeout(resolve, 1000));
            addLine('ACCESSING DARK WEB NODES...', 'output');

            await new Promise(resolve => setTimeout(resolve, 800));
            addLine('BYPASSING GOVERNMENT FIREWALLS...', 'output');

            await new Promise(resolve => setTimeout(resolve, 1200));
            addLine('WARNING: NSA MONITORING DETECTED', 'warning');

            await new Promise(resolve => setTimeout(resolve, 600));
            addLine('ENCRYPTING ALL COMMUNICATIONS...', 'output');

            await new Promise(resolve => setTimeout(resolve, 900));
            addLine('SHADOW PROTOCOL ACTIVATED', 'output');
            addLine('SYSTEM READY FOR ILLEGAL OPERATIONS', 'output');
        };

        loadSequence();

        // Периодические предупреждения
        const warningInterval = setInterval(() => {
            const randomCommand = hackerCommands[Math.floor(Math.random() * hackerCommands.length)];
            addLine(randomCommand, Math.random() > 0.7 ? 'warning' : 'output');
        }, 5000);

        return () => clearInterval(warningInterval);
    }, []);

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!currentInput.trim()) return;

        addLine(`> ${currentInput}`, 'command');

        // Имитация ответа системы
        setTimeout(() => {
            const responses = [
                'ACCESS DENIED - INSUFFICIENT PRIVILEGES',
                'COMMAND EXECUTED SUCCESSFULLY',
                'ERROR: INVALID SYNTAX',
                'WARNING: THIS ACTION IS ILLEGAL',
                'SYSTEM COMPROMISED - ABORTING OPERATION'
            ];
            const randomResponse = responses[Math.floor(Math.random() * responses.length)];
            addLine(randomResponse, Math.random() > 0.6 ? 'error' : 'output');
        }, 500);

        setCurrentInput('');
    };

    const addLine = (text: string, type: TerminalLine['type'] = 'output') => {
        const timestamp = new Date().toLocaleTimeString();
        setLines(prev => [...prev, {
            id: Date.now(),
            text,
            type,
            timestamp
        }]);
    };

    return (
        <div className="hacker-terminal" style={{ height: '400px', overflow: 'auto' }}>
            <div style={{ marginBottom: '1rem' }}>
                <span style={{ color: '#ff0040', fontWeight: 'bold' }}>SHADOW_TERMINAL_v2.1</span>
                <span style={{ color: '#666', marginLeft: '1rem' }}>// UNAUTHORIZED ACCESS</span>
            </div>

            {lines.map(line => (
                <div key={line.id} style={{ marginBottom: '0.5rem' }}>
                    <span style={{ color: '#666', fontSize: '0.8rem' }}>[{line.timestamp}]</span>
                    <span style={{
                        color: line.type === 'command' ? '#00ff41' :
                            line.type === 'error' ? '#ff0040' :
                                line.type === 'warning' ? '#ffff00' : '#00ff41',
                        marginLeft: '0.5rem'
                    }}>
                        {line.text}
                    </span>
                </div>
            ))}

            <form onSubmit={handleSubmit} style={{ marginTop: '1rem' }}>
                <span style={{ color: '#ff0040' }}>root@shadow:~$ </span>
                <input
                    type="text"
                    value={currentInput}
                    onChange={(e) => setCurrentInput(e.target.value)}
                    style={{
                        background: 'transparent',
                        border: 'none',
                        color: '#00ff41',
                        fontFamily: 'Courier New, monospace',
                        fontSize: '1rem',
                        outline: 'none',
                        width: '300px'
                    }}
                    placeholder="Enter command..."
                />
            </form>
        </div>
    );
} 