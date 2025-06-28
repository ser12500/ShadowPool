"use client";

import { useShadowPool } from "@/hooks/useShadowPool";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount } from "wagmi";
import { FaRocket, FaShieldAlt, FaCoins, FaChartLine, FaArrowRight, FaMagic, FaMap, FaBolt, FaGhost, FaEye, FaLock, FaUnlock, FaExclamationTriangle, FaSkull, FaRadiation } from "react-icons/fa";
import MadBackground from "@/components/MadBackground";
import MadCard from "@/components/MadCard";
import MadButton from "@/components/MadButton";
import MadText from "@/components/MadText";
import DangerParticles from "@/components/DangerParticles";
import WarningOverlay from "@/components/WarningOverlay";
import HackerTerminal from "@/components/HackerTerminal";
import DangerButton from "@/components/DangerButton";
import IllegalCounter from "@/components/IllegalCounter";
import DangerSoundEffects from "@/components/DangerSoundEffects";
import { motion, useScroll, useTransform } from 'framer-motion';
import { useRef, useState } from 'react';

export default function HomePage() {
  const { address, isConnected } = useAccount();
  const [showTerminal, setShowTerminal] = useState(false);
  const [showWarnings, setShowWarnings] = useState(true);

  const {
    poolStats,
    anonymityLevel,
    poolUtilization,
    currentPercentageFee,
    currentFixedFee,
    lastError,
  } = useShadowPool();

  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end start"]
  });

  const y = useTransform(scrollYProgress, [0, 1], ["0%", "50%"]);
  const opacity = useTransform(scrollYProgress, [0, 0.5], [1, 0]);

  const features = [
    {
      icon: FaShieldAlt,
      title: "Полная анонимность",
      description: "Ваши транзакции полностью скрыты с помощью zero-knowledge доказательств",
      color: "from-green-500 to-emerald-600",
      delay: 0.1
    },
    {
      icon: FaRocket,
      title: "Быстрые депозиты",
      description: "Мгновенные депозиты с минимальными комиссиями",
      color: "from-blue-500 to-indigo-600",
      delay: 0.2
    },
    {
      icon: FaCoins,
      title: "Гибкие выводы",
      description: "Выводите средства в любое время с сохранением анонимности",
      color: "from-purple-500 to-pink-600",
      delay: 0.3
    },
    {
      icon: FaChartLine,
      title: "Аналитика пула",
      description: "Отслеживайте статистику и эффективность пула",
      color: "from-orange-500 to-red-600",
      delay: 0.4
    },
  ];

  const stats = [
    {
      icon: FaMap,
      title: "Всего депозитов",
      value: poolStats?.totalDeposits?.toString() || "∞",
      color: "from-indigo-500 to-purple-600",
      delay: 0.6
    },
    {
      icon: FaShieldAlt,
      title: "Уровень анонимности",
      value: anonymityLevel?.toString() || "Максимум",
      color: "from-green-500 to-emerald-600",
      delay: 0.7
    },
    {
      icon: FaChartLine,
      title: "Утилизация пула",
      value: `${poolUtilization ? (Number(poolUtilization) * 100).toFixed(1) : "25"}%`,
      color: "from-purple-500 to-pink-600",
      delay: 0.8
    },
  ];

  return (
    <div ref={containerRef} className="min-h-screen relative overflow-hidden">
      {/* Опасные эффекты */}
      <DangerParticles />
      {showWarnings && <WarningOverlay />}
      <IllegalCounter />
      <DangerSoundEffects />

      {/* Безумный 3D фон */}
      <MadBackground />

      {/* Основной контент */}
      <div className="relative z-10">
        {/* Hero секция */}
        <section className="text-center py-20 px-4 min-h-screen flex items-center justify-center">
          <div className="max-w-6xl mx-auto">
            {/* Безумный заголовок */}
            <motion.div
              initial={{ opacity: 0, y: 100 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 1, ease: "easeOut" }}
            >
              <MadText
                variant="gradient"
                size="9xl"
                className="font-black mb-6 glitch"
                data-text="ShadowPool"
                animate={true}
              >
                ShadowPool
              </MadText>

              <MadText
                variant="neon"
                size="4xl"
                className="mb-8 font-bold danger-pulse"
                stagger={true}
                delay={0.5}
              >
                <FaRadiation className="inline mr-2" />
                НЕЗАКОННЫЙ анонимный пул
                <FaSkull className="inline ml-2" />
              </MadText>
            </motion.div>

            {/* Безумное описание */}
            <motion.div
              initial={{ opacity: 0, y: 50 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.3 }}
            >
              <MadText
                variant="body"
                size="2xl"
                className="text-gray-300 mb-12 max-w-4xl mx-auto"
              >
                <FaExclamationTriangle className="inline mr-2 text-red-500" />
                Погрузитесь в мир полной анонимности с нашими
                <span className="text-red-400 font-semibold"> незаконными zero-knowledge доказательствами</span>
                <FaExclamationTriangle className="inline ml-2 text-red-500" />
              </MadText>
            </motion.div>

            {/* Безумные кнопки */}
            <motion.div
              initial={{ opacity: 0, y: 50 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.5 }}
              className="flex flex-col sm:flex-row gap-6 justify-center items-center mb-16"
            >
              {!isConnected ? (
                <div className="hover:scale-105 transition-transform duration-300">
                  <ConnectButton />
                </div>
              ) : (
                <div className="flex flex-col sm:flex-row gap-6">
                  <DangerButton
                    variant="illegal"
                    size="lg"
                    onClick={() => window.location.href = '/deposit'}
                  >
                    <FaRocket className="w-6 h-6" />
                    НЕЗАКОННЫЙ депозит
                  </DangerButton>
                  <DangerButton
                    variant="danger"
                    size="lg"
                    onClick={() => setShowTerminal(!showTerminal)}
                  >
                    <FaSkull className="w-6 h-6" />
                    Хакерский терминал
                  </DangerButton>
                  <DangerButton
                    variant="warning"
                    size="lg"
                    onClick={() => setShowWarnings(!showWarnings)}
                  >
                    <FaExclamationTriangle className="w-6 h-6" />
                    {showWarnings ? 'Скрыть предупреждения' : 'Показать предупреждения'}
                  </DangerButton>
                </div>
              )}
            </motion.div>

            {/* Хакерский терминал */}
            {showTerminal && (
              <motion.div
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.8 }}
                className="mb-12"
              >
                <HackerTerminal />
              </motion.div>
            )}

            {/* Безумные статистики */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-20">
              {stats.map((stat, index) => {
                const Icon = stat.icon;
                return (
                  <MadCard
                    key={index}
                    delay={stat.delay}
                    glow={true}
                    pulse={true}
                    className="group danger-border"
                  >
                    <div className="text-center">
                      <motion.div
                        className={`w-20 h-20 bg-gradient-to-r ${stat.color} rounded-full flex items-center justify-center mx-auto mb-6 group-hover:scale-110 transition-transform duration-300`}
                        whileHover={{ rotate: 360 }}
                        transition={{ duration: 0.6 }}
                      >
                        <Icon className="w-10 h-10 text-white" />
                      </motion.div>
                      <MadText
                        variant="title"
                        size="4xl"
                        className="text-white mb-2"
                      >
                        {stat.value}
                      </MadText>
                      <MadText
                        variant="body"
                        size="lg"
                        className="text-gray-300"
                      >
                        {stat.title}
                      </MadText>
                    </div>
                  </MadCard>
                );
              })}
            </div>
          </div>
        </section>

        {/* Безумные особенности */}
        <section className="py-32 px-4">
          <div className="max-w-7xl mx-auto">
            <motion.div
              initial={{ opacity: 0, y: 50 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8 }}
              viewport={{ once: true }}
              className="text-center mb-20"
            >
              <MadText
                variant="gradient"
                size="6xl"
                className="font-bold mb-8"
              >
                Безумные возможности
              </MadText>
              <MadText
                variant="body"
                size="xl"
                className="text-gray-300 max-w-3xl mx-auto"
              >
                Откройте для себя мир анонимных транзакций с невероятными возможностями
              </MadText>
            </motion.div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
              {features.map((feature, index) => {
                const Icon = feature.icon;
                return (
                  <motion.div
                    key={index}
                    initial={{ opacity: 0, y: 50 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.6, delay: feature.delay }}
                    viewport={{ once: true }}
                  >
                    <MadCard
                      hover={true}
                      glow={true}
                      className="h-full group"
                    >
                      <div className="text-center">
                        <motion.div
                          className={`w-16 h-16 bg-gradient-to-r ${feature.color} rounded-full flex items-center justify-center mb-6 mx-auto group-hover:scale-110 transition-transform duration-300`}
                          whileHover={{ rotate: 360 }}
                          transition={{ duration: 0.6 }}
                        >
                          <Icon className="w-8 h-8 text-white" />
                        </motion.div>
                        <MadText
                          variant="title"
                          size="2xl"
                          className="text-white mb-4"
                        >
                          {feature.title}
                        </MadText>
                        <MadText
                          variant="body"
                          size="base"
                          className="text-gray-300 leading-relaxed"
                        >
                          {feature.description}
                        </MadText>
                      </div>
                    </MadCard>
                  </motion.div>
                );
              })}
            </div>
          </div>
        </section>

        {/* Безумная CTA секция */}
        <section className="py-32 px-4">
          <div className="max-w-5xl mx-auto text-center">
            <MadCard
              glow={true}
              pulse={true}
              className="relative overflow-hidden"
            >
              <motion.div
                initial={{ opacity: 0, scale: 0.8 }}
                whileInView={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.8 }}
                viewport={{ once: true }}
              >
                <MadText
                  variant="gradient"
                  size="5xl"
                  className="font-bold mb-6"
                >
                  Готовы к безумию?
                </MadText>

                <MadText
                  variant="body"
                  size="xl"
                  className="text-gray-300 mb-8 max-w-3xl mx-auto"
                >
                  Присоединяйтесь к революции анонимных транзакций и испытайте силу zero-knowledge доказательств
                </MadText>

                <div className="flex flex-col sm:flex-row gap-6 justify-center items-center">
                  <MadButton
                    variant="glow"
                    size="lg"
                    onClick={() => window.location.href = '/deposit'}
                  >
                    <FaBolt className="w-6 h-6" />
                    Начать сейчас
                  </MadButton>
                  <MadButton
                    variant="neon"
                    size="lg"
                    onClick={() => window.location.href = '/generate-proof'}
                  >
                    <FaGhost className="w-6 h-6" />
                    Узнать больше
                  </MadButton>
                </div>
              </motion.div>

              {/* Безумные декоративные элементы */}
              <div className="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none">
                <motion.div
                  className="absolute -top-10 -left-10 w-20 h-20 bg-indigo-500/20 rounded-full blur-xl"
                  animate={{
                    scale: [1, 1.5, 1],
                    opacity: [0.3, 0.6, 0.3]
                  }}
                  transition={{
                    duration: 3,
                    repeat: Infinity,
                    ease: "easeInOut"
                  }}
                />
                <motion.div
                  className="absolute -bottom-10 -right-10 w-20 h-20 bg-purple-500/20 rounded-full blur-xl"
                  animate={{
                    scale: [1.5, 1, 1.5],
                    opacity: [0.6, 0.3, 0.6]
                  }}
                  transition={{
                    duration: 3,
                    repeat: Infinity,
                    ease: "easeInOut",
                    delay: 1.5
                  }}
                />
              </div>
            </MadCard>
          </div>
        </section>
      </div>
    </div>
  );
}
