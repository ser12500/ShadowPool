"use client";
import { useState } from 'react';
import { useAccount } from 'wagmi';
import { useNoirProof } from '@/hooks/useNoirProof';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Loader2, CheckCircle, XCircle, Download, Copy } from 'lucide-react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';

const TOKENS = [
    { address: "0x0000000000000000000000000000000000000000", symbol: "ETH", name: "Ethereum" },
    { address: "0xA0b86a33E6441b8c4C8C8C8C8C8C8C8C8C8C8C8", symbol: "USDC", name: "USD Coin" },
    { address: "0xB0b86a33E6441b8c4C8C8C8C8C8C8C8C8C8C8C8", symbol: "USDT", name: "Tether" },
];

export default function ProofPage() {
    const { address, isConnected } = useAccount();
    const {
        generateCommitmentAndProof,
        generateVoteProof,
        isGenerating,
        error,
        clearError
    } = useNoirProof();

    // Состояние для депозита
    const [depositToken, setDepositToken] = useState(TOKENS[0].address);
    const [depositAmount, setDepositAmount] = useState('');
    const [depositProofData, setDepositProofData] = useState<any>(null);

    // Состояние для голосования
    const [voteNullifier, setVoteNullifier] = useState('');
    const [voteSecret, setVoteSecret] = useState('');
    const [voteRecipient, setVoteRecipient] = useState('');
    const [voteLeaves, setVoteLeaves] = useState('');
    const [voteProofData, setVoteProofData] = useState<any>(null);

    const handleGenerateDepositProof = async () => {
        if (!depositAmount || parseFloat(depositAmount) <= 0) {
            alert('Пожалуйста, введите корректную сумму');
            return;
        }

        clearError();

        try {
            const result = await generateCommitmentAndProof(
                depositToken,
                depositAmount,
                address || '',
                [] // Пустой массив листьев для нового депозита
            );

            if (result) {
                setDepositProofData(result);
                console.log('Deposit proof данные:', result);
            }
        } catch (err) {
            console.error('Ошибка генерации deposit proof:', err);
        }
    };

    const handleGenerateVoteProof = async () => {
        if (!voteNullifier || !voteSecret || !voteRecipient) {
            alert('Пожалуйста, заполните все поля');
            return;
        }

        clearError();

        try {
            const leaves = voteLeaves ? voteLeaves.split(',').map(l => l.trim()) : [];
            const result = await generateVoteProof(
                voteNullifier,
                voteSecret,
                voteRecipient,
                leaves
            );

            if (result) {
                setVoteProofData(result);
                console.log('Vote proof данные:', result);
            }
        } catch (err) {
            console.error('Ошибка генерации vote proof:', err);
        }
    };

    const exportProof = (proofData: any, type: 'deposit' | 'vote') => {
        const dataStr = JSON.stringify({
            type,
            timestamp: new Date().toISOString(),
            ...proofData
        }, null, 2);

        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        const url = URL.createObjectURL(dataBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${type}-proof-${Date.now()}.json`;
        link.click();
        URL.revokeObjectURL(url);
    };

    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
    };

    const selectedTokenInfo = TOKENS.find(t => t.address === depositToken);

    return (
        <div className="container mx-auto px-4 py-8">
            <div className="max-w-4xl mx-auto space-y-6">
                <div className="text-center">
                    <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
                        Генерация Zero-Knowledge Proof
                    </h1>
                    <p className="text-gray-600 dark:text-gray-400 mt-2">
                        Создавайте и проверяйте анонимные proof для депозитов и голосования
                    </p>
                </div>

                <Tabs defaultValue="deposit" className="w-full">
                    <TabsList className="grid w-full grid-cols-2">
                        <TabsTrigger value="deposit">Депозит</TabsTrigger>
                        <TabsTrigger value="vote">Голосование</TabsTrigger>
                    </TabsList>

                    <TabsContent value="deposit" className="space-y-6">
                        <Card>
                            <CardHeader>
                                <CardTitle>Генерация proof для депозита</CardTitle>
                                <CardDescription>
                                    Создайте анонимный proof для депозита токенов
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                <div className="space-y-2">
                                    <Label htmlFor="deposit-token">Токен</Label>
                                    <Select value={depositToken} onValueChange={setDepositToken}>
                                        <SelectTrigger>
                                            <SelectValue placeholder="Выберите токен" />
                                        </SelectTrigger>
                                        <SelectContent>
                                            {TOKENS.map((token) => (
                                                <SelectItem key={token.address} value={token.address}>
                                                    {token.name} ({token.symbol})
                                                </SelectItem>
                                            ))}
                                        </SelectContent>
                                    </Select>
                                </div>

                                <div className="space-y-2">
                                    <Label htmlFor="deposit-amount">Сумма</Label>
                                    <Input
                                        id="deposit-amount"
                                        type="number"
                                        placeholder="0.0"
                                        value={depositAmount}
                                        onChange={(e) => setDepositAmount(e.target.value)}
                                        step="0.000001"
                                        min="0"
                                    />
                                    <p className="text-sm text-gray-500">
                                        Минимальная сумма: 0.000001 {selectedTokenInfo?.symbol}
                                    </p>
                                </div>

                                <Button
                                    onClick={handleGenerateDepositProof}
                                    disabled={isGenerating || !depositAmount || parseFloat(depositAmount) <= 0}
                                    className="w-full"
                                >
                                    {isGenerating ? (
                                        <>
                                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                            Генерация proof...
                                        </>
                                    ) : (
                                        'Сгенерировать proof для депозита'
                                    )}
                                </Button>
                            </CardContent>
                        </Card>

                        {depositProofData && (
                            <Card>
                                <CardHeader>
                                    <CardTitle className="flex items-center justify-between">
                                        <span>Сгенерированный proof для депозита</span>
                                        <Button
                                            variant="outline"
                                            size="sm"
                                            onClick={() => exportProof(depositProofData, 'deposit')}
                                        >
                                            <Download className="mr-2 h-4 w-4" />
                                            Экспорт
                                        </Button>
                                    </CardTitle>
                                    <CardDescription>
                                        Proof успешно сгенерирован и готов к использованию
                                    </CardDescription>
                                </CardHeader>
                                <CardContent className="space-y-4">
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                                        <div>
                                            <Label className="text-xs text-gray-500">Commitment</Label>
                                            <div className="flex items-center gap-2">
                                                <p className="font-mono text-xs break-all">{depositProofData.commitment}</p>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    onClick={() => copyToClipboard(depositProofData.commitment)}
                                                >
                                                    <Copy className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                        <div>
                                            <Label className="text-xs text-gray-500">Nullifier</Label>
                                            <div className="flex items-center gap-2">
                                                <p className="font-mono text-xs break-all">{depositProofData.nullifier}</p>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    onClick={() => copyToClipboard(depositProofData.nullifier)}
                                                >
                                                    <Copy className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                        <div>
                                            <Label className="text-xs text-gray-500">Secret</Label>
                                            <div className="flex items-center gap-2">
                                                <p className="font-mono text-xs break-all">{depositProofData.secret}</p>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    onClick={() => copyToClipboard(depositProofData.secret)}
                                                >
                                                    <Copy className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                        <div>
                                            <Label className="text-xs text-gray-500">Merkle Root</Label>
                                            <div className="flex items-center gap-2">
                                                <p className="font-mono text-xs break-all">{depositProofData.merkleRoot}</p>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    onClick={() => copyToClipboard(depositProofData.merkleRoot)}
                                                >
                                                    <Copy className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                    </div>
                                </CardContent>
                            </Card>
                        )}
                    </TabsContent>

                    <TabsContent value="vote" className="space-y-6">
                        <Card>
                            <CardHeader>
                                <CardTitle>Генерация proof для голосования</CardTitle>
                                <CardDescription>
                                    Создайте анонимный proof для голосования
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                <div className="space-y-2">
                                    <Label htmlFor="vote-nullifier">Nullifier</Label>
                                    <Input
                                        id="vote-nullifier"
                                        type="text"
                                        placeholder="0x..."
                                        value={voteNullifier}
                                        onChange={(e) => setVoteNullifier(e.target.value)}
                                    />
                                </div>

                                <div className="space-y-2">
                                    <Label htmlFor="vote-secret">Secret</Label>
                                    <Input
                                        id="vote-secret"
                                        type="text"
                                        placeholder="0x..."
                                        value={voteSecret}
                                        onChange={(e) => setVoteSecret(e.target.value)}
                                    />
                                </div>

                                <div className="space-y-2">
                                    <Label htmlFor="vote-recipient">Получатель</Label>
                                    <Input
                                        id="vote-recipient"
                                        type="text"
                                        placeholder="0x..."
                                        value={voteRecipient}
                                        onChange={(e) => setVoteRecipient(e.target.value)}
                                    />
                                </div>

                                <div className="space-y-2">
                                    <Label htmlFor="vote-leaves">Листья Merkle дерева (через запятую)</Label>
                                    <Input
                                        id="vote-leaves"
                                        type="text"
                                        placeholder="0x..., 0x..., 0x..."
                                        value={voteLeaves}
                                        onChange={(e) => setVoteLeaves(e.target.value)}
                                    />
                                    <p className="text-sm text-gray-500">
                                        Оставьте пустым для нового голосования
                                    </p>
                                </div>

                                <Button
                                    onClick={handleGenerateVoteProof}
                                    disabled={isGenerating || !voteNullifier || !voteSecret || !voteRecipient}
                                    className="w-full"
                                >
                                    {isGenerating ? (
                                        <>
                                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                            Генерация proof...
                                        </>
                                    ) : (
                                        'Сгенерировать proof для голосования'
                                    )}
                                </Button>
                            </CardContent>
                        </Card>

                        {voteProofData && (
                            <Card>
                                <CardHeader>
                                    <CardTitle className="flex items-center justify-between">
                                        <span>Сгенерированный proof для голосования</span>
                                        <Button
                                            variant="outline"
                                            size="sm"
                                            onClick={() => exportProof(voteProofData, 'vote')}
                                        >
                                            <Download className="mr-2 h-4 w-4" />
                                            Экспорт
                                        </Button>
                                    </CardTitle>
                                    <CardDescription>
                                        Proof успешно сгенерирован и готов к использованию
                                    </CardDescription>
                                </CardHeader>
                                <CardContent className="space-y-4">
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                                        <div>
                                            <Label className="text-xs text-gray-500">Commitment</Label>
                                            <div className="flex items-center gap-2">
                                                <p className="font-mono text-xs break-all">{voteProofData.commitment}</p>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    onClick={() => copyToClipboard(voteProofData.commitment)}
                                                >
                                                    <Copy className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                        <div>
                                            <Label className="text-xs text-gray-500">Nullifier</Label>
                                            <div className="flex items-center gap-2">
                                                <p className="font-mono text-xs break-all">{voteProofData.nullifier}</p>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    onClick={() => copyToClipboard(voteProofData.nullifier)}
                                                >
                                                    <Copy className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                        <div>
                                            <Label className="text-xs text-gray-500">Secret</Label>
                                            <div className="flex items-center gap-2">
                                                <p className="font-mono text-xs break-all">{voteProofData.secret}</p>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    onClick={() => copyToClipboard(voteProofData.secret)}
                                                >
                                                    <Copy className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                    </div>
                                </CardContent>
                            </Card>
                        )}
                    </TabsContent>
                </Tabs>

                {error && (
                    <Alert variant="destructive">
                        <XCircle className="h-4 w-4" />
                        <AlertDescription>{error}</AlertDescription>
                    </Alert>
                )}
            </div>
        </div>
    );
} 