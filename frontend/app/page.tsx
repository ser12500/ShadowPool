"use client";

import { useShadowPool } from "@/hooks/useShadowPool";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount } from "wagmi";
import { FaRocket, FaShieldAlt, FaCoins, FaChartLine, FaArrowRight, FaMagic, FaMap } from "react-icons/fa";
import ParticleBackground from "@/components/ParticleBackground";

export default function HomePage() {
  const { address, isConnected } = useAccount();
  const {
    poolStats,
    anonymityLevel,
    poolUtilization,
    percentageFee,
    fixedFee,
    isLoadingStats,
    isLoadingAnonymity,
    isLoadingUtilization,
    contractAddress,
  } = useShadowPool();

  const features = [
    {
      icon: FaShieldAlt,
      title: "Полная анонимность",
      description: "Ваши транзакции полностью скрыты с помощью zero-knowledge доказательств",
      color: "from-green-500 to-emerald-600",
    },
    {
      icon: FaRocket,
      title: "Быстрые депозиты",
      description: "Мгновенные депозиты с минимальными комиссиями",
      color: "from-blue-500 to-indigo-600",
    },
    {
      icon: FaCoins,
      title: "Гибкие выводы",
      description: "Выводите средства в любое время с сохранением анонимности",
      color: "from-purple-500 to-pink-600",
    },
    {
      icon: FaChartLine,
      title: "Аналитика пула",
      description: "Отслеживайте статистику и эффективность пула",
      color: "from-orange-500 to-red-600",
    },
  ];

  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* Анимированный фон */}
      <ParticleBackground />

      {/* Основной контент */}
      <div className="relative z-10">
        {/* Hero секция */}
        <section className="text-center py-20 px-4">
          <div className="max-w-4xl mx-auto">
            <h1 className="text-6xl md:text-8xl font-bold mb-6 animate-fade-in-up">
              <span className="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 bg-clip-text text-transparent animate-rotate-gradient">
                ShadowPool
              </span>
              <span className="block text-2xl md:text-4xl mt-4 text-gray-600">
                Безумный анонимный пул
              </span>
            </h1>

            <p className="text-xl md:text-2xl text-gray-600 mb-8 animate-fade-in-up" style={{ animationDelay: '0.2s' }}>
              Погрузитесь в мир полной анонимности с нашими
              <span className="text-indigo-600 font-semibold"> zero-knowledge доказательствами</span>
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-12 animate-fade-in-up" style={{ animationDelay: '0.4s' }}>
              {!isConnected ? (
                <div className="hover:scale-105 transition-transform duration-300">
                  <ConnectButton />
                </div>
              ) : (
                <div className="flex gap-4">
                  <button className="btn-primary flex items-center gap-2 hover:scale-105 transition-transform duration-300">
                    <FaRocket className="w-5 h-5" />
                    Начать депозит
                  </button>
                  <button className="px-6 py-3 rounded-lg font-semibold transition-all duration-300 border-2 border-indigo-600 text-indigo-600 hover:bg-indigo-600 hover:text-white hover:scale-105">
                    <FaMagic className="w-5 h-5 inline mr-2" />
                    Магия
                  </button>
                </div>
              )}
            </div>

            {/* Безумные статистики */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-16 animate-fade-in-up" style={{ animationDelay: '0.6s' }}>
              <div className="card hover-lift">
                <div className="text-center">
                  <div className="w-16 h-16 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-4 animate-pulse-glow">
                    <FaMap className="w-8 h-8 text-white" />
                  </div>
                  <h3 className="text-2xl font-bold text-gray-800 mb-2">
                    {isLoadingStats ? (
                      <div className="loading-shimmer h-8 w-20 mx-auto rounded"></div>
                    ) : poolStats ? (
                      poolStats.totalDeposits.toString()
                    ) : (
                      "∞"
                    )}
                  </h3>
                  <p className="text-gray-600">Всего депозитов</p>
                </div>
              </div>

              <div className="card hover-lift">
                <div className="text-center">
                  <div className="w-16 h-16 bg-gradient-to-r from-green-500 to-emerald-600 rounded-full flex items-center justify-center mx-auto mb-4 animate-pulse-glow">
                    <FaShieldAlt className="w-8 h-8 text-white" />
                  </div>
                  <h3 className="text-2xl font-bold text-gray-800 mb-2">
                    {isLoadingAnonymity ? (
                      <div className="loading-shimmer h-8 w-20 mx-auto rounded"></div>
                    ) : anonymityLevel ? (
                      anonymityLevel
                    ) : (
                      "Максимум"
                    )}
                  </h3>
                  <p className="text-gray-600">Уровень анонимности</p>
                </div>
              </div>

              <div className="card hover-lift">
                <div className="text-center">
                  <div className="w-16 h-16 bg-gradient-to-r from-purple-500 to-pink-600 rounded-full flex items-center justify-center mx-auto mb-4 animate-pulse-glow">
                    <FaChartLine className="w-8 h-8 text-white" />
                  </div>
                  <h3 className="text-2xl font-bold text-gray-800 mb-2">
                    {isLoadingUtilization ? (
                      <div className="loading-shimmer h-8 w-20 mx-auto rounded"></div>
                    ) : (
                      `${(poolUtilization * 100).toFixed(1)}%`
                    )}
                  </h3>
                  <p className="text-gray-600">Утилизация пула</p>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Особенности */}
        <section className="py-20 px-4">
          <div className="max-w-6xl mx-auto">
            <h2 className="text-4xl md:text-5xl font-bold text-center mb-16 animate-fade-in-up">
              <span className="bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
                Безумные возможности
              </span>
            </h2>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
              {features.map((feature, index) => {
                const Icon = feature.icon;
                return (
                  <div
                    key={index}
                    className="card hover-lift animate-fade-in-up"
                    style={{ animationDelay: `${0.2 * index}s` }}
                  >
                    <div className={`w-16 h-16 bg-gradient-to-r ${feature.color} rounded-full flex items-center justify-center mb-6 mx-auto animate-float`}>
                      <Icon className="w-8 h-8 text-white" />
                    </div>
                    <h3 className="text-xl font-bold text-gray-800 mb-4 text-center">
                      {feature.title}
                    </h3>
                    <p className="text-gray-600 text-center leading-relaxed">
                      {feature.description}
                    </p>

                    {/* Безумные частицы */}
                    <div className="absolute -top-2 -right-2 w-2 h-2 bg-indigo-500 rounded-full opacity-0 group-hover:opacity-100 animate-float"></div>
                    <div className="absolute -bottom-2 -left-2 w-1 h-1 bg-purple-500 rounded-full opacity-0 group-hover:opacity-100 animate-float" style={{ animationDelay: '1s' }}></div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        {/* CTA секция */}
        <section className="py-20 px-4">
          <div className="max-w-4xl mx-auto text-center">
            <div className="card glass-effect animate-fade-in-up">
              <h2 className="text-4xl md:text-5xl font-bold mb-6">
                <span className="bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
                  Готовы к безумию?
                </span>
              </h2>
              <p className="text-xl text-gray-600 mb-8">
                Присоединяйтесь к революции анонимных транзакций
              </p>
              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <button className="btn-primary flex items-center justify-center gap-2 hover:scale-105 transition-transform duration-300">
                  <FaRocket className="w-5 h-5" />
                  Начать сейчас
                  <FaArrowRight className="w-4 h-4" />
                </button>
                <button className="px-6 py-3 rounded-lg font-semibold transition-all duration-300 border-2 border-indigo-600 text-indigo-600 hover:bg-indigo-600 hover:text-white hover:scale-105">
                  Узнать больше
                </button>
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
