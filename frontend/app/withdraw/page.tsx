"use client";
import { useState } from "react";
import { useShadowPool } from "@/hooks/useShadowPool";
import { useAccount } from "wagmi";
import ConnectionStatus from "@/components/ConnectionStatus";
import WalletInfo from "@/components/WalletInfo";

export default function WithdrawPage() {
    const [proof, setProof] = useState("");
    const [root, setRoot] = useState("");
    const [nullifierHashes, setNullifierHashes] = useState("");
    const [recipient, setRecipient] = useState("");
    const [amount, setAmount] = useState("");
    const { address, isConnected } = useAccount();
    const {
        performWithdraw,
        isWithdrawing,
        isWaitingWithdraw,
        isWithdrawSuccess
    } = useShadowPool();

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!isConnected || !proof || !root || !nullifierHashes || !recipient || !amount) return;

        // Парсим nullifier hashes из строки
        const nullifierArray = nullifierHashes.split(',').map(hash => hash.trim() as `0x${string}`);

        performWithdraw(proof, root, nullifierArray, recipient, amount);
    };

    const generateRandomProof = () => {
        const randomBytes = Array.from({ length: 256 }, () => Math.floor(Math.random() * 256));
        const hexString = "0x" + randomBytes.map(b => b.toString(16).padStart(2, "0")).join("");
        setProof(hexString);
    };

    const generateRandomRoot = () => {
        const randomBytes = Array.from({ length: 32 }, () => Math.floor(Math.random() * 256));
        const hexString = "0x" + randomBytes.map(b => b.toString(16).padStart(2, "0")).join("");
        setRoot(hexString);
    };

    const generateRandomNullifiers = () => {
        const nullifier1 = Array.from({ length: 32 }, () => Math.floor(Math.random() * 256));
        const nullifier2 = Array.from({ length: 32 }, () => Math.floor(Math.random() * 256));
        const hex1 = "0x" + nullifier1.map(b => b.toString(16).padStart(2, "0")).join("");
        const hex2 = "0x" + nullifier2.map(b => b.toString(16).padStart(2, "0")).join("");
        setNullifierHashes(`${hex1}, ${hex2}`);
    };

    return (
        <div className="flex flex-col items-center gap-8 py-12">
            <h2 className="text-3xl font-bold text-indigo-700 mb-4">Вывод средств</h2>

            <ConnectionStatus />

            {isConnected && <WalletInfo />}

            {!isConnected ? (
                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-center max-w-md">
                    <p className="text-yellow-800">Подключите кошелёк для вывода средств</p>
                </div>
            ) : (
                <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow p-6 flex flex-col gap-4 w-full max-w-2xl">
                    <div>
                        <label className="text-gray-700 font-medium block mb-2">
                            Сумма (ETH):
                        </label>
                        <input
                            type="number"
                            min="0.01"
                            step="0.01"
                            placeholder="Введите сумму для вывода"
                            value={amount}
                            onChange={(e) => setAmount(e.target.value)}
                            className="w-full border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                        />
                    </div>

                    <div>
                        <label className="text-gray-700 font-medium block mb-2">
                            Адрес получателя:
                        </label>
                        <input
                            type="text"
                            placeholder="0x..."
                            value={recipient}
                            onChange={(e) => setRecipient(e.target.value)}
                            className="w-full border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                        />
                    </div>

                    <div>
                        <label className="text-gray-700 font-medium block mb-2">
                            Proof (или сгенерируйте случайный):
                        </label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                placeholder="0x..."
                                value={proof}
                                onChange={(e) => setProof(e.target.value)}
                                className="flex-1 border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                            />
                            <button
                                type="button"
                                onClick={generateRandomProof}
                                className="px-3 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition"
                                title="Сгенерировать случайный proof"
                            >
                                🎲
                            </button>
                        </div>
                    </div>

                    <div>
                        <label className="text-gray-700 font-medium block mb-2">
                            Root (или сгенерируйте случайный):
                        </label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                placeholder="0x..."
                                value={root}
                                onChange={(e) => setRoot(e.target.value)}
                                className="flex-1 border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                            />
                            <button
                                type="button"
                                onClick={generateRandomRoot}
                                className="px-3 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition"
                                title="Сгенерировать случайный root"
                            >
                                🎲
                            </button>
                        </div>
                    </div>

                    <div>
                        <label className="text-gray-700 font-medium block mb-2">
                            Nullifier Hashes (через запятую, или сгенерируйте случайные):
                        </label>
                        <div className="flex gap-2">
                            <input
                                type="text"
                                placeholder="0x..., 0x..."
                                value={nullifierHashes}
                                onChange={(e) => setNullifierHashes(e.target.value)}
                                className="flex-1 border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                            />
                            <button
                                type="button"
                                onClick={generateRandomNullifiers}
                                className="px-3 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition"
                                title="Сгенерировать случайные nullifier hashes"
                            >
                                🎲
                            </button>
                        </div>
                    </div>

                    <button
                        type="submit"
                        disabled={!proof || !root || !nullifierHashes || !recipient || !amount || isWithdrawing || isWaitingWithdraw}
                        className="bg-indigo-600 text-white rounded px-4 py-2 font-semibold hover:bg-indigo-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
                    >
                        {isWithdrawing ? "Подготовка транзакции..." :
                            isWaitingWithdraw ? "Ожидание подтверждения..." :
                                "Вывести средства"}
                    </button>

                    {isWithdrawSuccess && (
                        <div className="bg-green-50 border border-green-200 rounded-lg p-3 text-center">
                            <p className="text-green-800 font-medium">Средства успешно выведены!</p>
                        </div>
                    )}
                </form>
            )}

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 w-full max-w-2xl">
                <h3 className="text-lg font-medium text-blue-800 mb-2">Информация о выводе</h3>
                <p className="text-blue-700 text-sm">
                    Для вывода средств вам необходимо предоставить корректный proof, который доказывает,
                    что у вас есть право на вывод указанной суммы из пула. Nullifier hashes предотвращают
                    повторное использование одного и того же депозита.
                </p>
            </div>
        </div>
    );
} 