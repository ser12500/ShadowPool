'use client';

import { useState, useEffect } from 'react';
import { FaSkull, FaRadiation, FaExclamationTriangle, FaBiohazard } from 'react-icons/fa';

interface IllegalOperation {
    id: number;
    type: string;
    amount: string;
    timestamp: string;
    status: 'success' | 'warning' | 'danger';
}

export default function IllegalCounter() {
    const [operations, setOperations] = useState<IllegalOperation[]>([]);
    const [totalAmount, setTotalAmount] = useState(0);
    const [isVisible, setIsVisible] = useState(false);

    const operationTypes = [
        { type: 'НЕЗАКОННЫЙ ДЕПОЗИТ', icon: FaSkull, color: 'text-red-400' },
        { type: 'ТЕНЕВОЙ ВЫВОД', icon: FaRadiation, color: 'text-red-500' },
        { type: 'ХАКЕРСКИЙ PROOF', icon: FaExclamationTriangle, color: 'text-red-600' },
        { type: 'ПОДПОЛЬНАЯ ТРАНЗАКЦИЯ', icon: FaBiohazard, color: 'text-red-700' }
    ];

    useEffect(() => {
        // Показываем счетчик через 2 секунды
        const timer = setTimeout(() => setIsVisible(true), 2000);
        return () => clearTimeout(timer);
    }, []);

    useEffect(() => {
        if (!isVisible) return;

        const addOperation = () => {
            const randomType = operationTypes[Math.floor(Math.random() * operationTypes.length)];
            const randomAmount = (Math.random() * 10 + 0.1).toFixed(4);
            const timestamp = new Date().toLocaleTimeString();

            const newOperation: IllegalOperation = {
                id: Date.now(),
                type: randomType.type,
                amount: randomAmount,
                timestamp,
                status: Math.random() > 0.7 ? 'danger' : Math.random() > 0.5 ? 'warning' : 'success'
            };

            setOperations(prev => {
                const updated = [newOperation, ...prev.slice(0, 4)];
                return updated;
            });

            setTotalAmount(prev => prev + parseFloat(randomAmount));
        };

        // Добавляем операции каждые 3-8 секунд
        const interval = setInterval(() => {
            if (Math.random() > 0.3) {
                addOperation();
            }
        }, 3000 + Math.random() * 5000);

        return () => clearInterval(interval);
    }, [isVisible]);

    if (!isVisible) return null;

    return (
        <div className="fixed bottom-4 right-4 z-50">
            <div className="bg-black/90 border-2 border-red-500 rounded-lg p-4 max-w-sm danger-pulse">
                <div className="flex items-center gap-2 mb-3">
                    <FaSkull className="w-5 h-5 text-red-400" />
                    <h3 className="text-red-400 font-bold text-sm">НЕЗАКОННЫЕ ОПЕРАЦИИ</h3>
                    <FaExclamationTriangle className="w-4 h-4 text-red-500 ml-auto" />
                </div>

                <div className="mb-3">
                    <div className="flex justify-between items-center">
                        <span className="text-red-300 text-xs">Общая сумма:</span>
                        <span className="text-red-400 font-bold text-lg">
                            {totalAmount.toFixed(4)} ETH
                        </span>
                    </div>
                    <div className="flex justify-between items-center">
                        <span className="text-red-300 text-xs">Операций:</span>
                        <span className="text-red-400 font-bold">
                            {operations.length}
                        </span>
                    </div>
                </div>

                <div className="space-y-2 max-h-32 overflow-y-auto">
                    {operations.map(operation => {
                        const typeInfo = operationTypes.find(t => t.type === operation.type);
                        const Icon = typeInfo?.icon || FaSkull;

                        return (
                            <div
                                key={operation.id}
                                className={`p-2 rounded border ${operation.status === 'danger' ? 'border-red-600 bg-red-900/30' :
                                        operation.status === 'warning' ? 'border-red-500 bg-red-800/30' :
                                            'border-red-400 bg-red-700/30'
                                    } animate-fade-in-up`}
                            >
                                <div className="flex items-center gap-2">
                                    <Icon className={`w-3 h-3 ${typeInfo?.color}`} />
                                    <span className="text-red-300 text-xs flex-1">{operation.type}</span>
                                    <span className="text-red-400 font-bold text-xs">{operation.amount} ETH</span>
                                </div>
                                <div className="text-red-500 text-xs mt-1">{operation.timestamp}</div>
                            </div>
                        );
                    })}
                </div>

                <div className="mt-3 pt-2 border-t border-red-500">
                    <div className="text-red-300 text-xs text-center">
                        <FaRadiation className="inline mr-1" />
                        ВСЕ ОПЕРАЦИИ ОТСЛЕЖИВАЮТСЯ
                        <FaRadiation className="inline ml-1" />
                    </div>
                </div>
            </div>
        </div>
    );
} 