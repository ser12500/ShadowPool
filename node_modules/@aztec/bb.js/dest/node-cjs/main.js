#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.proveAndVerifyUltraHonk = proveAndVerifyUltraHonk;
exports.proveAndVerifyMegaHonk = proveAndVerifyMegaHonk;
exports.gateCountUltra = gateCountUltra;
exports.contractUltraHonk = contractUltraHonk;
exports.proveUltraHonk = proveUltraHonk;
exports.writeVkUltraHonk = writeVkUltraHonk;
exports.verifyUltraHonk = verifyUltraHonk;
exports.proofAsFieldsUltraHonk = proofAsFieldsUltraHonk;
exports.vkAsFieldsUltraHonk = vkAsFieldsUltraHonk;
require("source-map-support/register.js");
const index_js_1 = require("./index.js");
const index_js_2 = require("./log/index.js");
const fs_1 = require("fs");
const zlib_1 = require("zlib");
const commander_1 = require("commander");
let debug;
const threads = +process.env.HARDWARE_CONCURRENCY || undefined;
function getBytecode(bytecodePath) {
    const extension = bytecodePath.substring(bytecodePath.lastIndexOf('.') + 1);
    if (extension == 'json') {
        const encodedCircuit = JSON.parse((0, fs_1.readFileSync)(bytecodePath, 'utf8'));
        const decompressed = (0, zlib_1.gunzipSync)(Buffer.from(encodedCircuit.bytecode, 'base64'));
        return Uint8Array.from(decompressed);
    }
    const encodedCircuit = (0, fs_1.readFileSync)(bytecodePath);
    const decompressed = (0, zlib_1.gunzipSync)(encodedCircuit);
    return Uint8Array.from(decompressed);
}
// TODO(https://github.com/AztecProtocol/barretenberg/issues/1126): split this into separate Plonk and Honk functions as their gate count differs
async function getGatesUltra(bytecodePath, recursive, honkRecursion, api) {
    const { total } = await computeCircuitSize(bytecodePath, recursive, honkRecursion, api);
    return total;
}
function getWitness(witnessPath) {
    const data = (0, fs_1.readFileSync)(witnessPath);
    const decompressed = (0, zlib_1.gunzipSync)(data);
    return Uint8Array.from(decompressed);
}
async function computeCircuitSize(bytecodePath, recursive, honkRecursion, api) {
    debug(`Computing circuit size for ${bytecodePath}`);
    const bytecode = getBytecode(bytecodePath);
    const [total, subgroup] = await api.acirGetCircuitSizes(bytecode, recursive, honkRecursion);
    return { total, subgroup };
}
async function initUltraHonk(bytecodePath, crsPath) {
    const api = await index_js_1.Barretenberg.new({
        threads,
    });
    // TODO(https://github.com/AztecProtocol/barretenberg/issues/1248): Get rid of this call to avoid building the circuit twice.
    // TODO(https://github.com/AztecProtocol/barretenberg/issues/1126): use specific UltraHonk function
    // recursive here is useless for UH, as it does not affect anything
    const circuitSize = await getGatesUltra(bytecodePath, /*recursive=*/ false, /*honkRecursion=*/ true, api);
    // TODO(https://github.com/AztecProtocol/barretenberg/issues/811): remove subgroupSizeOverride hack for goblin
    const dyadicCircuitSize = Math.pow(2, Math.ceil(Math.log2(circuitSize)));
    debug(`Loading CRS for UltraHonk with circuit-size=${circuitSize} dyadic-circuit-size=${dyadicCircuitSize}`);
    const crs = await index_js_1.Crs.new(dyadicCircuitSize + 1, crsPath);
    // Load CRS into wasm global CRS state.
    // TODO: Make RawBuffer be default behavior, and have a specific Vector type for when wanting length prefixed.
    await api.srsInitSrs(new index_js_1.RawBuffer(crs.getG1Data()), crs.numPoints, new index_js_1.RawBuffer(crs.getG2Data()));
    return { api, circuitSize, dyadicCircuitSize };
}
async function initLite(crsPath) {
    const api = await index_js_1.Barretenberg.new({ threads: 1 });
    // Plus 1 needed! (Move +1 into Crs?)
    const crs = await index_js_1.Crs.new(1, crsPath);
    // Load CRS into wasm global CRS state.
    await api.srsInitSrs(new index_js_1.RawBuffer(crs.getG1Data()), crs.numPoints, new index_js_1.RawBuffer(crs.getG2Data()));
    return { api };
}
async function proveAndVerifyUltraHonk(bytecodePath, witnessPath, crsPath) {
    /* eslint-disable camelcase */
    const { api } = await initUltraHonk(bytecodePath, crsPath);
    try {
        const bytecode = getBytecode(bytecodePath);
        const witness = getWitness(witnessPath);
        const verified = await api.acirProveAndVerifyUltraHonk(bytecode, witness);
        return verified;
    }
    finally {
        await api.destroy();
    }
    /* eslint-enable camelcase */
}
async function proveAndVerifyMegaHonk(bytecodePath, witnessPath, crsPath) {
    /* eslint-disable camelcase */
    const { api } = await initUltraHonk(bytecodePath, crsPath);
    try {
        const bytecode = getBytecode(bytecodePath);
        const witness = getWitness(witnessPath);
        const verified = await api.acirProveAndVerifyMegaHonk(bytecode, witness);
        return verified;
    }
    finally {
        await api.destroy();
    }
    /* eslint-enable camelcase */
}
async function gateCountUltra(bytecodePath, recursive, honkRecursion) {
    const api = await index_js_1.Barretenberg.new({ threads: 1 });
    try {
        const numberOfGates = await getGatesUltra(bytecodePath, recursive, honkRecursion, api);
        debug(`Number of gates: ${numberOfGates}`);
        // Create an 8-byte buffer and write the number into it.
        // Writing number directly to stdout will result in a variable sized
        // input depending on the size.
        const buffer = Buffer.alloc(8);
        buffer.writeBigInt64LE(BigInt(numberOfGates));
        process.stdout.write(Uint8Array.from(buffer));
    }
    finally {
        await api.destroy();
    }
}
async function contractUltraHonk(bytecodePath, vkPath, crsPath, outputPath) {
    const { api } = await initUltraHonk(bytecodePath, crsPath);
    try {
        debug(`Creating UltraHonk verifier contract bytecode=${bytecodePath} vk=${vkPath}`);
        const bytecode = getBytecode(bytecodePath);
        const vk = new index_js_1.RawBuffer((0, fs_1.readFileSync)(vkPath));
        const contract = await api.acirHonkSolidityVerifier(bytecode, vk);
        if (outputPath === '-') {
            process.stdout.write(contract);
            debug(`Solidity verifier contract written to stdout`);
        }
        else {
            (0, fs_1.writeFileSync)(outputPath, contract);
            debug(`Solidity verifier contract written to ${outputPath}`);
        }
    }
    finally {
        await api.destroy();
    }
}
async function proveUltraHonk(bytecodePath, witnessPath, crsPath, outputPath, options) {
    const { api } = await initUltraHonk(bytecodePath, crsPath);
    try {
        debug(`Creating UltraHonk proof bytecode=${bytecodePath}`);
        const bytecode = getBytecode(bytecodePath);
        const witness = getWitness(witnessPath);
        const acirProveUltraHonk = options?.keccak
            ? api.acirProveUltraKeccakHonk.bind(api)
            : options?.keccakZK
                ? api.acirProveUltraKeccakZkHonk.bind(api)
                : options?.starknet
                    ? api.acirProveUltraStarknetHonk.bind(api)
                    : options?.starknetZK
                        ? api.acirProveUltraStarknetZkHonk.bind(api)
                        : api.acirProveUltraHonk.bind(api);
        const proof = await acirProveUltraHonk(bytecode, witness);
        if (outputPath === '-') {
            process.stdout.write(proof);
            debug(`Proof written to stdout`);
        }
        else {
            (0, fs_1.writeFileSync)(outputPath, proof);
            debug(`Proof written to ${outputPath}`);
        }
    }
    finally {
        await api.destroy();
    }
}
async function writeVkUltraHonk(bytecodePath, crsPath, outputPath, options) {
    const { api } = await initUltraHonk(bytecodePath, crsPath);
    try {
        const bytecode = getBytecode(bytecodePath);
        debug(`Initializing UltraHonk verification key bytecode=${bytecodePath}`);
        const acirWriteVkUltraHonk = options?.keccak
            ? api.acirWriteVkUltraKeccakHonk.bind(api)
            : options?.keccakZK
                ? api.acirWriteVkUltraKeccakZkHonk.bind(api)
                : options?.starknet
                    ? api.acirWriteVkUltraStarknetHonk.bind(api)
                    : options?.starknetZK
                        ? api.acirWriteVkUltraStarknetZkHonk.bind(api)
                        : api.acirWriteVkUltraHonk.bind(api);
        const vk = await acirWriteVkUltraHonk(bytecode);
        if (outputPath === '-') {
            process.stdout.write(vk);
            debug(`Verification key written to stdout`);
        }
        else {
            (0, fs_1.writeFileSync)(outputPath, vk);
            debug(`Verification key written to ${outputPath}`);
        }
    }
    finally {
        await api.destroy();
    }
}
async function verifyUltraHonk(proofPath, vkPath, crsPath, options) {
    const { api } = await initLite(crsPath);
    try {
        const acirVerifyUltraHonk = options?.keccak
            ? api.acirVerifyUltraKeccakHonk.bind(api)
            : options?.keccakZK
                ? api.acirVerifyUltraKeccakZkHonk.bind(api)
                : options?.starknet
                    ? api.acirVerifyUltraStarknetHonk.bind(api)
                    : options?.starknetZK
                        ? api.acirVerifyUltraStarknetZkHonk.bind(api)
                        : api.acirVerifyUltraHonk.bind(api);
        const verified = await acirVerifyUltraHonk(Uint8Array.from((0, fs_1.readFileSync)(proofPath)), new index_js_1.RawBuffer((0, fs_1.readFileSync)(vkPath)));
        debug(`Verification ${verified ? 'successful' : 'failed'}`);
        return verified;
    }
    finally {
        await api.destroy();
    }
}
async function proofAsFieldsUltraHonk(proofPath, outputPath, crsPath) {
    const { api } = await initLite(crsPath);
    try {
        debug(`Outputting UltraHonk proof as vector of fields proof=${proofPath}`);
        const proofAsFields = await api.acirProofAsFieldsUltraHonk(Uint8Array.from((0, fs_1.readFileSync)(proofPath)));
        const jsonProofAsFields = JSON.stringify(proofAsFields.map(f => f.toString()));
        if (outputPath === '-') {
            process.stdout.write(jsonProofAsFields);
            debug(`Proof as fields written to stdout`);
        }
        else {
            (0, fs_1.writeFileSync)(outputPath, jsonProofAsFields);
            debug(`Proof as fields written to ${outputPath}`);
        }
    }
    finally {
        await api.destroy();
    }
}
async function vkAsFieldsUltraHonk(vkPath, vkeyOutputPath, crsPath) {
    const { api } = await initLite(crsPath);
    try {
        debug(`Serializing vk byte array into field elements vk=${vkPath}`);
        const vkAsFields = await api.acirVkAsFieldsUltraHonk(new index_js_1.RawBuffer((0, fs_1.readFileSync)(vkPath)));
        const jsonVKAsFields = JSON.stringify(vkAsFields.map(f => f.toString()));
        if (vkeyOutputPath === '-') {
            process.stdout.write(jsonVKAsFields);
            debug(`Verification key as fields written to stdout`);
        }
        else {
            (0, fs_1.writeFileSync)(vkeyOutputPath, jsonVKAsFields);
            debug(`Verification key as fields written to ${vkeyOutputPath}`);
        }
    }
    finally {
        await api.destroy();
    }
}
const program = new commander_1.Command('bb');
program.option('-v, --verbose', 'enable verbose logging', false);
program.option('-c, --crs-path <path>', 'set crs path', './crs');
function handleGlobalOptions() {
    (0, index_js_2.initLogger)({ useStdErr: true, level: program.opts().verbose ? 'debug' : 'info' });
    debug = (0, index_js_2.createDebugLogger)('bb');
    return { crsPath: program.opts().crsPath };
}
const deprecatedCommandError = () => async () => {
    console.error(`Error: UltraPlonk is now deprecated (see https://github.com/AztecProtocol/barretenberg/issues/1377). Use UltraHonk!`);
    process.exit(1);
};
program
    .command('prove_and_verify')
    .description('Generate a proof and verify it. Process exits with success or failure code. [DEPRECATED]')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-r, --recursive', 'Whether to use a SNARK friendly proof', false)
    .option('-w, --witness-path <path>', 'Specify the witness path', './target/witness.gz')
    .action(deprecatedCommandError());
program
    .command('prove_and_verify_ultra_honk')
    .description('Generate an UltraHonk proof and verify it. Process exits with success or failure code.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-w, --witness-path <path>', 'Specify the witness path', './target/witness.gz')
    .action(async ({ bytecodePath, witnessPath }) => {
    const { crsPath } = handleGlobalOptions();
    const result = await proveAndVerifyUltraHonk(bytecodePath, witnessPath, crsPath);
    process.exit(result ? 0 : 1);
});
program
    .command('prove_and_verify_mega_honk')
    .description('Generate a MegaHonk proof and verify it. Process exits with success or failure code.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-w, --witness-path <path>', 'Specify the witness path', './target/witness.gz')
    .action(async ({ bytecodePath, witnessPath }) => {
    const { crsPath } = handleGlobalOptions();
    const result = await proveAndVerifyMegaHonk(bytecodePath, witnessPath, crsPath);
    process.exit(result ? 0 : 1);
});
program
    .command('prove')
    .description('Generate a proof and write it to a file. [DEPRECATED]')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-r, --recursive', 'Create a SNARK friendly proof', false)
    .option('-w, --witness-path <path>', 'Specify the witness path', './target/witness.gz')
    .option('-o, --output-path <path>', 'Specify the proof output path', './proofs/proof')
    .action(deprecatedCommandError());
program
    .command('gates')
    .description('Print Ultra Builder gate count to standard output.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-r, --recursive', 'Create a SNARK friendly proof', false)
    .option('-hr, --honk-recursion', 'Specify whether to use UltraHonk recursion', false)
    .action(async ({ bytecodePath, recursive, honkRecursion: honkRecursion }) => {
    handleGlobalOptions();
    await gateCountUltra(bytecodePath, recursive, honkRecursion);
});
program
    .command('verify')
    .description('Verify a proof. Process exists with success or failure code. [DEPRECATED]')
    .requiredOption('-p, --proof-path <path>', 'Specify the path to the proof')
    .requiredOption('-k, --vk <path>', 'path to a verification key. avoids recomputation.')
    .action(deprecatedCommandError());
program
    .command('contract')
    .description('Output solidity verification key contract. [DEPRECATED]')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-o, --output-path <path>', 'Specify the path to write the contract', './target/contract.sol')
    .requiredOption('-k, --vk-path <path>', 'Path to a verification key. avoids recomputation.')
    .action(deprecatedCommandError());
program
    .command('contract_ultra_honk')
    .description('Output solidity verification key contract.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-o, --output-path <path>', 'Specify the path to write the contract', './target/contract.sol')
    .requiredOption('-k, --vk-path <path>', 'Path to a verification key.')
    .action(async ({ bytecodePath, outputPath, vkPath }) => {
    const { crsPath } = handleGlobalOptions();
    await contractUltraHonk(bytecodePath, vkPath, crsPath, outputPath);
});
program
    .command('write_vk')
    .description('Output verification key. [DEPRECATED]')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-r, --recursive', 'Create a SNARK friendly proof', false)
    .option('-o, --output-path <path>', 'Specify the path to write the key')
    .action(deprecatedCommandError());
program
    .command('write_pk')
    .description('Output proving key. [DEPRECATED]')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-r, --recursive', 'Create a SNARK friendly proof', false)
    .requiredOption('-o, --output-path <path>', 'Specify the path to write the key')
    .action(deprecatedCommandError());
program
    .command('proof_as_fields')
    .description('Return the proof as fields elements. [DEPRECATED]')
    .requiredOption('-p, --proof-path <path>', 'Specify the proof path')
    .requiredOption('-k, --vk-path <path>', 'Path to verification key.')
    .requiredOption('-o, --output-path <path>', 'Specify the JSON path to write the proof fields')
    .action(deprecatedCommandError());
program
    .command('vk_as_fields')
    .description('Return the verification key represented as fields elements. Also return the verification key hash. [DEPRECATED]')
    .requiredOption('-k, --vk-path <path>', 'Path to verification key.')
    .requiredOption('-o, --output-path <path>', 'Specify the JSON path to write the verification key fields and key hash')
    .action(deprecatedCommandError());
program
    .command('prove_ultra_honk')
    .description('Generate a proof and write it to a file.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-w, --witness-path <path>', 'Specify the witness path', './target/witness.gz')
    .option('-o, --output-path <path>', 'Specify the proof output path', './proofs/proof')
    .action(async ({ bytecodePath, witnessPath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    debug(`Creating UltraHonk proof bytecode=${bytecodePath}`);
    await proveUltraHonk(bytecodePath, witnessPath, crsPath, outputPath);
});
program
    .command('prove_ultra_keccak_honk')
    .description('Generate a proof and write it to a file.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-w, --witness-path <path>', 'Specify the witness path', './target/witness.gz')
    .option('-o, --output-path <path>', 'Specify the proof output path', './proofs/proof')
    .action(async ({ bytecodePath, witnessPath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    await proveUltraHonk(bytecodePath, witnessPath, crsPath, outputPath, { keccak: true });
});
program
    .command('prove_ultra_starknet_honk')
    .description('Generate a proof and write it to a file.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-r, --recursive', 'Create a SNARK friendly proof', false)
    .option('-w, --witness-path <path>', 'Specify the witness path', './target/witness.gz')
    .option('-o, --output-path <path>', 'Specify the proof output path', './proofs/proof')
    .action(async ({ bytecodePath, witnessPath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    await proveUltraHonk(bytecodePath, witnessPath, crsPath, outputPath, { starknet: true });
});
program
    .command('write_vk_ultra_honk')
    .description('Output verification key.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .requiredOption('-o, --output-path <path>', 'Specify the path to write the key')
    .action(async ({ bytecodePath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    debug(`Writing verification key to ${outputPath}`);
    await writeVkUltraHonk(bytecodePath, crsPath, outputPath);
});
program
    .command('write_vk_ultra_keccak_honk')
    .description('Output verification key.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .requiredOption('-o, --output-path <path>', 'Specify the path to write the key')
    .action(async ({ bytecodePath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    await writeVkUltraHonk(bytecodePath, crsPath, outputPath, { keccak: true });
});
program
    .command('write_vk_ultra_starknet_honk')
    .description('Output verification key.')
    .option('-b, --bytecode-path <path>', 'Specify the bytecode path', './target/program.json')
    .option('-r, --recursive', 'Create a SNARK friendly proof', false)
    .requiredOption('-o, --output-path <path>', 'Specify the path to write the key')
    .action(async ({ bytecodePath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    await writeVkUltraHonk(bytecodePath, crsPath, outputPath, { starknet: true });
});
program
    .command('verify_ultra_honk')
    .description('Verify a proof. Process exists with success or failure code.')
    .requiredOption('-p, --proof-path <path>', 'Specify the path to the proof')
    .requiredOption('-k, --vk <path>', 'path to a verification key. avoids recomputation.')
    .action(async ({ proofPath, vk }) => {
    const { crsPath } = handleGlobalOptions();
    const result = await verifyUltraHonk(proofPath, vk, crsPath);
    process.exit(result ? 0 : 1);
});
program
    .command('verify_ultra_keccak_honk')
    .description('Verify a proof. Process exists with success or failure code.')
    .requiredOption('-p, --proof-path <path>', 'Specify the path to the proof')
    .requiredOption('-k, --vk <path>', 'path to a verification key. avoids recomputation.')
    .action(async ({ proofPath, vk }) => {
    const { crsPath } = handleGlobalOptions();
    const result = await verifyUltraHonk(proofPath, vk, crsPath, { keccak: true });
    process.exit(result ? 0 : 1);
});
program
    .command('verify_ultra_starknet_honk')
    .description('Verify a proof. Process exists with success or failure code.')
    .requiredOption('-p, --proof-path <path>', 'Specify the path to the proof')
    .requiredOption('-k, --vk <path>', 'path to a verification key. avoids recomputation.')
    .action(async ({ proofPath, vk }) => {
    const { crsPath } = handleGlobalOptions();
    const result = await verifyUltraHonk(proofPath, vk, crsPath, { starknet: true });
    process.exit(result ? 0 : 1);
});
program
    .command('proof_as_fields_honk')
    .description('Return the proof as fields elements')
    .requiredOption('-p, --proof-path <path>', 'Specify the proof path')
    .requiredOption('-o, --output-path <path>', 'Specify the JSON path to write the proof fields')
    .action(async ({ proofPath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    await proofAsFieldsUltraHonk(proofPath, outputPath, crsPath);
});
program
    .command('vk_as_fields_ultra_honk')
    .description('Return the verification key represented as fields elements.')
    .requiredOption('-k, --vk-path <path>', 'Path to verification key.')
    .requiredOption('-o, --output-path <path>', 'Specify the JSON path to write the verification key fields.')
    .action(async ({ vkPath, outputPath }) => {
    const { crsPath } = handleGlobalOptions();
    await vkAsFieldsUltraHonk(vkPath, outputPath, crsPath);
});
program.name('bb.js').parse(process.argv);
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoibWFpbi5qcyIsInNvdXJjZVJvb3QiOiIiLCJzb3VyY2VzIjpbIi4uLy4uL3NyYy9tYWluLnRzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiI7OztBQStFQSwwREFhQztBQUVELHdEQWFDO0FBRUQsd0NBZUM7QUFFRCw4Q0FrQkM7QUFFRCx3Q0FrQ0M7QUFFRCw0Q0FnQ0M7QUFFRCwwQ0EyQkM7QUFFRCx3REFpQkM7QUFFRCxrREFrQkM7QUF6UkQsMENBQXdDO0FBQ3hDLHlDQUEwRDtBQUMxRCw2Q0FBK0Q7QUFDL0QsMkJBQWlEO0FBQ2pELCtCQUFrQztBQUNsQyx5Q0FBb0M7QUFHcEMsSUFBSSxLQUE0QixDQUFDO0FBRWpDLE1BQU0sT0FBTyxHQUFHLENBQUMsT0FBTyxDQUFDLEdBQUcsQ0FBQyxvQkFBcUIsSUFBSSxTQUFTLENBQUM7QUFFaEUsU0FBUyxXQUFXLENBQUMsWUFBb0I7SUFDdkMsTUFBTSxTQUFTLEdBQUcsWUFBWSxDQUFDLFNBQVMsQ0FBQyxZQUFZLENBQUMsV0FBVyxDQUFDLEdBQUcsQ0FBQyxHQUFHLENBQUMsQ0FBQyxDQUFDO0lBRTVFLElBQUksU0FBUyxJQUFJLE1BQU0sRUFBRSxDQUFDO1FBQ3hCLE1BQU0sY0FBYyxHQUFHLElBQUksQ0FBQyxLQUFLLENBQUMsSUFBQSxpQkFBWSxFQUFDLFlBQVksRUFBRSxNQUFNLENBQUMsQ0FBQyxDQUFDO1FBQ3RFLE1BQU0sWUFBWSxHQUFHLElBQUEsaUJBQVUsRUFBQyxNQUFNLENBQUMsSUFBSSxDQUFDLGNBQWMsQ0FBQyxRQUFRLEVBQUUsUUFBUSxDQUFDLENBQUMsQ0FBQztRQUNoRixPQUFPLFVBQVUsQ0FBQyxJQUFJLENBQUMsWUFBWSxDQUFDLENBQUM7SUFDdkMsQ0FBQztJQUVELE1BQU0sY0FBYyxHQUFHLElBQUEsaUJBQVksRUFBQyxZQUFZLENBQUMsQ0FBQztJQUNsRCxNQUFNLFlBQVksR0FBRyxJQUFBLGlCQUFVLEVBQUMsY0FBYyxDQUFDLENBQUM7SUFDaEQsT0FBTyxVQUFVLENBQUMsSUFB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