// Адреса развернутых контрактов для разных сетей
export const CONTRACT_ADDRESSES = {
    // Для Anvil (локальная сеть)
    SHADOW_POOL: "0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9",
    DAO: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
    GOVERNANCE_TOKEN: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",

    // Вспомогательные контракты
    POSEIDON2: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    HONK_VERIFIER: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
    TIMELOCK_CONTROLLER: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
} as const;

// Адреса для zkSync Era Sepolia (пока не развернуты)
export const ZKSYNC_CONTRACT_ADDRESSES = {
    SHADOW_POOL: "0x0000000000000000000000000000000000000000", // TODO: развернуть
    DAO: "0x0000000000000000000000000000000000000000", // TODO: развернуть
    GOVERNANCE_TOKEN: "0x0000000000000000000000000000000000000000", // TODO: развернуть
} as const;

// Функция для получения адресов контрактов в зависимости от сети
export function getContractAddresses(chainId: number) {
    if (chainId === 31337) {
        // Anvil
        return CONTRACT_ADDRESSES;
    } else if (chainId === 302) {
        // zkSync Era Sepolia
        return ZKSYNC_CONTRACT_ADDRESSES;
    } else {
        // Fallback к Anvil для других сетей
        return CONTRACT_ADDRESSES;
    }
}

// Типы для адресов контрактов
export type ContractAddress = typeof CONTRACT_ADDRESSES[keyof typeof CONTRACT_ADDRESSES];

// Функция для получения адреса контракта по имени
export function getContractAddress(name: keyof typeof CONTRACT_ADDRESSES): ContractAddress {
    return CONTRACT_ADDRESSES[name];
}

// Проверка, что адрес является валидным адресом контракта
export function isValidContractAddress(address: string): boolean {
    return /^0x[a-fA-F0-9]{40}$/.test(address);
}
