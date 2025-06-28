"use client";

import { useShadowPool } from "../../hooks/useShadowPool";
import { useDAO } from "../../hooks/useDAO";
import { useAccount } from "wagmi";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { Alert, AlertDescription } from "../../components/ui/alert";

export default function TestPage() {
    const { address } = useAccount();
    const shadowPool = useShadowPool();
    const dao = useDAO();

    return (
        <div className="container mx-auto p-6 space-y-6">
            <h1 className="text-3xl font-bold">Тестовая страница контрактов</h1>

            {address && (
                <Alert>
                    <AlertDescription>
                        Подключенный адрес: {address}
                    </AlertDescription>
                </Alert>
            )}

            {/* ShadowPool Stats */}
            <Card>
                <CardHeader>
                    <CardTitle>ShadowPool Статистика</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                    {shadowPool.poolStats ? (
                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <strong>Всего депозитов:</strong> {shadowPool.poolStats.totalDeposits.toString()}
                            </div>
                            <div>
                                <strong>Текущий корень:</strong> {shadowPool.poolStats.currentRoot.slice(0, 10)}...
                            </div>
                            <div>
                                <strong>Процентная комиссия:</strong> {shadowPool.poolStats.currentPercentageFee.toString()} basis points
                            </div>
                            <div>
                                <strong>Фиксированная комиссия:</strong> {shadowPool.poolStats.currentFixedFee.toString()} wei
                            </div>
                        </div>
                    ) : (
                        <p>Загрузка статистики пула...</p>
                    )}

                    <div>
                        <strong>Уровень анонимности:</strong> {shadowPool.anonymityLevel || "Загрузка..."}
                    </div>

                    <div>
                        <strong>Утилизация пула:</strong> {shadowPool.poolUtilization ? shadowPool.poolUtilization.toString() + "%" : "Загрузка..."}
                    </div>
                </CardContent>
            </Card>

            {/* DAO Stats */}
            <Card>
                <CardHeader>
                    <CardTitle>DAO Статистика</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <strong>Активные предложения:</strong> {dao.proposalCount.toString()}
                        </div>
                        <div>
                            <strong>Порог предложений:</strong> {dao.proposalThresholdFormatted} токенов
                        </div>
                        <div>
                            <strong>Период голосования:</strong> {dao.votingPeriod.toString()} блоков
                        </div>
                        <div>
                            <strong>Кворум:</strong> {dao.quorumVotesFormatted} токенов
                        </div>
                    </div>

                    {address && (
                        <div>
                            <strong>Ваш баланс токенов:</strong> {dao.userTokenBalanceFormatted} токенов
                        </div>
                    )}
                </CardContent>
            </Card>

            {/* Error Display */}
            {(shadowPool.lastError || dao.lastError) && (
                <Alert className="bg-red-50 border-red-200">
                    <AlertDescription className="text-red-800">
                        {shadowPool.lastError || dao.lastError}
                    </AlertDescription>
                </Alert>
            )}

            {/* Network Status */}
            <Card>
                <CardHeader>
                    <CardTitle>Статус сети</CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="flex items-center space-x-2">
                        <div className={`w-3 h-3 rounded-full ${shadowPool.isSupportedNetwork ? 'bg-green-500' : 'bg-red-500'}`}></div>
                        <span>
                            {shadowPool.isSupportedNetwork ? 'Поддерживаемая сеть' : 'Неподдерживаемая сеть'}
                        </span>
                    </div>
                </CardContent>
            </Card>

            {/* Contract Addresses */}
            <Card>
                <CardHeader>
                    <CardTitle>Адреса контрактов</CardTitle>
                </CardHeader>
                <CardContent className="space-y-2">
                    <div><strong>ShadowPool:</strong> 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9</div>
                    <div><strong>DAO:</strong> 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707</div>
                    <div><strong>Governance Token:</strong> 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0</div>
                </CardContent>
            </Card>
        </div>
    );
}
