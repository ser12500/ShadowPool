/** @type {import('next').NextConfig} */
const nextConfig = {
    serverExternalPackages: ['@noir-lang/noir_js', '@aztec/bb.js'],
    webpack: (config, { isServer }) => {
        // Настройка для WebAssembly
        config.experiments = {
            ...config.experiments,
            asyncWebAssembly: true,
        };

        // Настройка для обработки .wasm файлов
        config.module.rules.push({
            test: /\.wasm$/,
            type: 'asset/resource',
        });

        // Настройка для библиотек с WebAssembly
        if (!isServer) {
            config.resolve.fallback = {
                ...config.resolve.fallback,
                fs: false,
                path: false,
                crypto: false,
            };
        }

        return config;
    },
};

module.exports = nextConfig; 