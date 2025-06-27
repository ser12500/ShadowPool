"use client";
import dynamic from "next/dynamic";

const Web3Providers = dynamic(() => import("./Web3Providers"), {
    ssr: false,
    loading: () => (
        <div className="min-h-screen flex items-center justify-center">
            <div className="text-center">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto"></div>
                <p className="mt-4 text-gray-600">Загрузка...</p>
            </div>
        </div>
    ),
});

export default function Web3ProvidersWrapper({
    children,
}: {
    children: React.ReactNode;
}) {
    return <Web3Providers>{children}</Web3Providers>;
} 