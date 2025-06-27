"use client";
import { useState } from "react";
import { useShadowPool } from "@/hooks/useShadowPool";
import { useNoirProof } from "@/hooks/useNoirProof";
import { useAccount } from "wagmi";

interface Proposal {
    id: string;
    title: string;
    description: string;
    startBlock: string;
    endBlock: string;
    totalVotes: string;
    forVotes: string;
    againstVotes: string;
    status: 'active' | 'passed' | 'failed' | 'pending';
}

export default function DaoPage() {
    const [proposals, setProposals] = useState<Proposal[]>([
        {
            id: "1",
            title: "Увеличение комиссии пула",
            description: "Предлагается увеличить комиссию пула с 0.5% до 1% для улучшения доходности участников",
            startBlock: "1000000",
            endBlock: "1000100",
            totalVotes: "10000000000000000000",
            forVotes: "7000000000000000000",
            againstVotes: "3000000000000000000",
            status: 'active'
        },
        {
            id: "2",
            title: "Добавление поддержки новых токенов",
            description: "Добавить поддержку USDC, USDT и DAI в пул для увеличения ликвидности",
            startBlock: "1000200",
            endBlock: "1000300",
            totalVotes: "8000000000000000000",
            forVotes: "6000000000000000000",
            againstVotes: "2000000000000000000",
            status: 'passed'
        }
    ]);

    const [newProposal, setNewProposal] = useState({
        title: "",
        description: "",
        duration: "100" // блоков
    });

    const [selectedProposal, setSelectedProposal] = useState<Proposal | null>(null);
    const [voteAmount, setVoteAmount] = useState("");
    const [voteChoice, setVoteChoice] = useState<'for' | 'against'>('for');

    const { address, isConnected } = useAccount();
    const { poolStats } = useShadowPool();
    const { generateVoteProof, isGenerating } = useNoirProof();

    const createProposal = () => {
        if (!newProposal.title || !newProposal.description) return;

        const proposal: Proposal = {
            id: (proposals.length + 1).toString(),
            title: newProposal.title,
            description: newProposal.description,
            startBlock: "1000000", // Текущий блок
            endBlock: (1000000 + parseInt(newProposal.duration)).toString(),
            totalVotes: "0",
            forVotes: "0",
            againstVotes: "0",
            status: 'pending'
        };

        setProposals([...proposals, proposal]);
        setNewProposal({ title: "", description: "", duration: "100" });
    };

    const submitVote = async () => {
        if (!selectedProposal || !voteAmount || !isConnected) return;

        try {
            // Генерируем proof для голосования
            const nullifier = "0x" + Array.from({ length: 32 }, () => Math.floor(Math.random() * 256))
                .map(b => b.toString(16).padStart(2, "0")).join("");
            const secret = "0x" + Array.from({ length: 32 }, () => Math.floor(Math.random() * 256))
                .map(b => b.toString(16).padStart(2, "0")).join("");

            const proof = await generateVoteProof(
                nullifier,
                secret,
                address || '',
                [] // Пустой массив листьев для нового голосования
            );

            if (proof) {
                console.log('Proof для голосования сгенерирован:', proof);
            }

            // Обновляем результаты голосования
            setProposals(prev => prev.map(p => {
                if (p.id === selectedProposal.id) {
                    const voteAmountWei = BigInt(voteAmount);
                    return {
                        ...p,
                        totalVotes: (BigInt(p.totalVotes) + voteAmountWei).toString(),
                        forVotes: voteChoice === 'for'
                            ? (BigInt(p.forVotes) + voteAmountWei).toString()
                            : p.forVotes,
                        againstVotes: voteChoice === 'against'
                            ? (BigInt(p.againstVotes) + voteAmountWei).toString()
                            : p.againstVotes,
                    };
                }
                return p;
            }));

            setVoteAmount("");
            setSelectedProposal(null);
        } catch (error) {
            console.error('Ошибка при голосовании:', error);
        }
    };

    const getProposalStatus = (proposal: Proposal) => {
        if (proposal.status === 'pending') return 'Ожидает';
        if (proposal.status === 'active') return 'Активно';
        if (proposal.status === 'passed') return 'Принято';
        if (proposal.status === 'failed') return 'Отклонено';
        return 'Неизвестно';
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'active': return 'text-green-600 bg-green-100';
            case 'passed': return 'text-blue-600 bg-blue-100';
            case 'failed': return 'text-red-600 bg-red-100';
            case 'pending': return 'text-yellow-600 bg-yellow-100';
            default: return 'text-gray-600 bg-gray-100';
        }
    };

    return (
        <div className="flex flex-col items-center gap-8 py-12">
            <h2 className="text-3xl font-bold text-indigo-700 mb-4">DAO Управление</h2>

            {!isConnected ? (
                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-center">
                    <p className="text-yellow-800">Подключите кошелёк для участия в DAO</p>
                </div>
            ) : (
                <div className="w-full max-w-6xl space-y-6">
                    {/* Создание нового предложения */}
                    <div className="bg-white rounded-xl shadow p-6">
                        <h3 className="text-xl font-semibold text-gray-800 mb-4">Создать предложение</h3>
                        <div className="space-y-4">
                            <div>
                                <label className="text-gray-700 font-medium block mb-2">Название:</label>
                                <input
                                    type="text"
                                    placeholder="Введите название предложения"
                                    value={newProposal.title}
                                    onChange={(e) => setNewProposal(prev => ({ ...prev, title: e.target.value }))}
                                    className="w-full border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                                />
                            </div>
                            <div>
                                <label className="text-gray-700 font-medium block mb-2">Описание:</label>
                                <textarea
                                    placeholder="Опишите детали предложения"
                                    value={newProposal.description}
                                    onChange={(e) => setNewProposal(prev => ({ ...prev, description: e.target.value }))}
                                    className="w-full border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400 h-24"
                                />
                            </div>
                            <div>
                                <label className="text-gray-700 font-medium block mb-2">Длительность (блоков):</label>
                                <input
                                    type="number"
                                    min="1"
                                    value={newProposal.duration}
                                    onChange={(e) => setNewProposal(prev => ({ ...prev, duration: e.target.value }))}
                                    className="w-full border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                                />
                            </div>
                            <button
                                onClick={createProposal}
                                disabled={!newProposal.title || !newProposal.description}
                                className="bg-indigo-600 text-white rounded px-4 py-2 font-semibold hover:bg-indigo-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
                            >
                                Создать предложение
                            </button>
                        </div>
                    </div>

                    {/* Список предложений */}
                    <div className="bg-white rounded-xl shadow p-6">
                        <h3 className="text-xl font-semibold text-gray-800 mb-4">Активные предложения</h3>
                        <div className="space-y-4">
                            {proposals.map((proposal) => (
                                <div key={proposal.id} className="border rounded-lg p-4 hover:bg-gray-50 transition">
                                    <div className="flex justify-between items-start mb-2">
                                        <h4 className="text-lg font-medium text-gray-800">{proposal.title}</h4>
                                        <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(getProposalStatus(proposal))}`}>
                                            {getProposalStatus(proposal)}
                                        </span>
                                    </div>
                                    <p className="text-gray-600 text-sm mb-3">{proposal.description}</p>

                                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                                        <div>
                                            <span className="text-gray-500">За:</span>
                                            <div className="font-medium">{parseFloat(proposal.forVotes) / 1e18} ETH</div>
                                        </div>
                                        <div>
                                            <span className="text-gray-500">Против:</span>
                                            <div className="font-medium">{parseFloat(proposal.againstVotes) / 1e18} ETH</div>
                                        </div>
                                        <div>
                                            <span className="text-gray-500">Всего:</span>
                                            <div className="font-medium">{parseFloat(proposal.totalVotes) / 1e18} ETH</div>
                                        </div>
                                        <div>
                                            <span className="text-gray-500">ID:</span>
                                            <div className="font-medium">#{proposal.id}</div>
                                        </div>
                                    </div>

                                    {proposal.status === 'active' && (
                                        <button
                                            onClick={() => setSelectedProposal(proposal)}
                                            className="mt-3 bg-green-600 text-white rounded px-3 py-1 text-sm hover:bg-green-700 transition"
                                        >
                                            Голосовать
                                        </button>
                                    )}
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Модальное окно голосования */}
                    {selectedProposal && (
                        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                            <div className="bg-white rounded-xl shadow-lg p-6 w-full max-w-md mx-4">
                                <h3 className="text-xl font-semibold text-gray-800 mb-4">
                                    Голосовать за "{selectedProposal.title}"
                                </h3>

                                <div className="space-y-4">
                                    <div>
                                        <label className="text-gray-700 font-medium block mb-2">Ваш выбор:</label>
                                        <div className="flex gap-4">
                                            <label className="flex items-center">
                                                <input
                                                    type="radio"
                                                    value="for"
                                                    checked={voteChoice === 'for'}
                                                    onChange={(e) => setVoteChoice(e.target.value as 'for' | 'against')}
                                                    className="mr-2"
                                                />
                                                За
                                            </label>
                                            <label className="flex items-center">
                                                <input
                                                    type="radio"
                                                    value="against"
                                                    checked={voteChoice === 'against'}
                                                    onChange={(e) => setVoteChoice(e.target.value as 'for' | 'against')}
                                                    className="mr-2"
                                                />
                                                Против
                                            </label>
                                        </div>
                                    </div>

                                    <div>
                                        <label className="text-gray-700 font-medium block mb-2">Количество токенов для голоса (wei):</label>
                                        <input
                                            type="text"
                                            placeholder="1000000000000000000"
                                            value={voteAmount}
                                            onChange={(e) => setVoteAmount(e.target.value)}
                                            className="w-full border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                                        />
                                    </div>

                                    <div className="flex gap-3">
                                        <button
                                            onClick={submitVote}
                                            disabled={!voteAmount || isGenerating}
                                            className="flex-1 bg-indigo-600 text-white rounded px-4 py-2 font-semibold hover:bg-indigo-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
                                        >
                                            {isGenerating ? "Генерация proof..." : "Проголосовать"}
                                        </button>
                                        <button
                                            onClick={() => setSelectedProposal(null)}
                                            className="flex-1 bg-gray-500 text-white rounded px-4 py-2 font-semibold hover:bg-gray-600 transition"
                                        >
                                            Отмена
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Статистика DAO */}
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                        <h3 className="text-lg font-medium text-blue-800 mb-2">Статистика DAO</h3>
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                            <div>
                                <span className="text-blue-700">Всего предложений:</span>
                                <div className="font-medium text-blue-800">{proposals.length}</div>
                            </div>
                            <div>
                                <span className="text-blue-700">Активных:</span>
                                <div className="font-medium text-blue-800">
                                    {proposals.filter(p => p.status === 'active').length}
                                </div>
                            </div>
                            <div>
                                <span className="text-blue-700">Принятых:</span>
                                <div className="font-medium text-blue-800">
                                    {proposals.filter(p => p.status === 'passed').length}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
} 