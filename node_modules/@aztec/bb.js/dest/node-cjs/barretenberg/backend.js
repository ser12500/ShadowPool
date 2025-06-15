"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AztecClientBackend = exports.UltraHonkBackend = exports.AztecClientBackendError = void 0;
const index_js_1 = require("./index.js");
const raw_buffer_js_1 = require("../types/raw_buffer.js");
const index_js_2 = require("../proof/index.js");
const pack_1 = require("msgpackr/pack");
const pako_1 = require("pako");
class AztecClientBackendError extends Error {
    constructor(message) {
        super(message);
    }
}
exports.AztecClientBackendError = AztecClientBackendError;
// Utility for parsing gate counts from buffer
// TODO: Where should this logic live? Should go away with move to msgpack.
function parseBigEndianU32Array(buffer) {
    const dv = new DataView(buffer.buffer, buffer.byteOffset, buffer.byteLength);
    let offset = 0;
    const count = buffer.byteLength >>> 2; // default is entire buffer length / 4
    const out = new Array(count);
    for (let i = 0; i < count; i++) {
        out[i] = dv.getUint32(offset, false);
        offset += 4;
    }
    return out;
}
class UltraHonkBackend {
    constructor(acirBytecode, backendOptions = { threads: 1 }, circuitOptions = { recursive: false }) {
        this.backendOptions = backendOptions;
        this.circuitOptions = circuitOptions;
        this.acirUncompressedBytecode = acirToUint8Array(acirBytecode);
    }
    /** @ignore */
    async instantiate() {
        if (!this.api) {
            const api = await index_js_1.Barretenberg.new(this.backendOptions);
            const honkRecursion = true;
            await api.acirInitSRS(this.acirUncompressedBytecode, this.circuitOptions.recursive, honkRecursion);
            // We don't init a proving key here in the Honk API
            // await api.acirInitProvingKey(this.acirComposer, this.acirUncompressedBytecode);
            this.api = api;
        }
    }
    async generateProof(compressedWitness, options) {
        await this.instantiate();
        const proveUltraHonk = options?.keccak
            ? this.api.acirProveUltraKeccakHonk.bind(this.api)
            : options?.keccakZK
                ? this.api.acirProveUltraKeccakZkHonk.bind(this.api)
                : options?.starknet
                    ? this.api.acirProveUltraStarknetHonk.bind(this.api)
                    : options?.starknetZK
                        ? this.api.acirProveUltraStarknetZkHonk.bind(this.api)
                        : this.api.acirProveUltraHonk.bind(this.api);
        const proofWithPublicInputs = await proveUltraHonk(this.acirUncompressedBytecode, (0, pako_1.ungzip)(compressedWitness));
        // Write VK to get the number of public inputs
        const writeVKUltraHonk = options?.keccak
            ? this.api.acirWriteVkUltraKeccakHonk.bind(this.api)
            : options?.keccakZK
                ? this.api.acirWriteVkUltraKeccakZkHonk.bind(this.api)
                : options?.starknet
                    ? this.api.acirWriteVkUltraStarknetHonk.bind(this.api)
                    : options?.starknetZK
                        ? this.api.acirWriteVkUltraStarknetZkHonk.bind(this.api)
                        : this.api.acirWriteVkUltraHonk.bind(this.api);
        const vk = await writeVKUltraHonk(this.acirUncompressedBytecode);
        const vkAsFields = await this.api.acirVkAsFieldsUltraHonk(new raw_buffer_js_1.RawBuffer(vk));
        // Item at index 1 in VK is the number of public inputs
        const publicInputsSizeIndex = 1; // index into VK for numPublicInputs
        const numPublicInputs = Number(vkAsFields[publicInputsSizeIndex].toString()) - index_js_2.PAIRING_POINTS_SIZE;
        const { proof, publicInputs: publicInputsBytes } = (0, index_js_2.splitHonkProof)(proofWithPublicInputs, numPublicInputs);
        const publicInputs = (0, index_js_2.deflattenFields)(publicInputsBytes);
        return { proof, publicInputs };
    }
    async verifyProof(proofData, options) {
        await this.instantiate();
        const proof = (0, index_js_2.reconstructHonkProof)((0, index_js_2.flattenFieldsAsArray)(proofData.publicInputs), proofData.proof);
        const writeVkUltraHonk = options?.keccak
            ? this.api.acirWriteVkUltraKeccakHonk.bind(this.api)
            : options?.keccakZK
                ? this.api.acirWriteVkUltraKeccakZkHonk.bind(this.api)
                : options?.starknet
                    ? this.api.acirWriteVkUltraStarknetHonk.bind(this.api)
                    : options?.starknetZK
                        ? this.api.acirWriteVkUltraStarknetZkHonk.bind(this.api)
                        : this.api.acirWriteVkUltraHonk.bind(this.api);
        const verifyUltraHonk = options?.keccak
            ? this.api.acirVerifyUltraKeccakHonk.bind(this.api)
            : options?.keccakZK
                ? this.api.acirVerifyUltraKeccakZkHonk.bind(this.api)
                : options?.starknet
                    ? this.api.acirVerifyUltraStarknetHonk.bind(this.api)
                    : options?.starknetZK
                        ? this.api.acirVerifyUltraStarknetZkHonk.bind(this.api)
                        : this.api.acirVerifyUltraHonk.bind(this.api);
        const vkBuf = await writeVkUltraHonk(this.acirUncompressedBytecode);
        return await verifyUltraHonk(proof, new raw_buffer_js_1.RawBuffer(vkBuf));
    }
    async getVerificationKey(options) {
        await this.instantiate();
        return options?.keccak
            ? await this.api.acirWriteVkUltraKeccakHonk(this.acirUncompressedBytecode)
            : options?.keccakZK
                ? await this.api.acirWriteVkUltraKeccakZkHonk(this.acirUncompressedBytecode)
                : options?.starknet
                    ? await this.api.acirWriteVkUltraStarknetHonk(this.acirUncompressedBytecode)
                    : options?.starknetZK
                        ? await this.api.acirWriteVkUltraStarknetZkHonk(this.acirUncompressedBytecode)
                        : await this.api.acirWriteVkUltraHonk(this.acirUncompressedBytecode);
    }
    /** @description Returns a solidity verifier */
    async getSolidityVerifier(vk) {
        await this.instantiate();
        const vkBuf = vk ?? (await this.api.acirWriteVkUltraKeccakHonk(this.acirUncompressedBytecode));
        return await this.api.acirHonkSolidityVerifier(this.acirUncompressedBytecode, new raw_buffer_js_1.RawBuffer(vkBuf));
    }
    // TODO(https://github.com/noir-lang/noir/issues/5661): Update this to handle Honk recursive aggregation in the browser once it is ready in the backend itself
    async generateRecursiveProofArtifacts(
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    _proof, 
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    _numOfPublicInputs) {
        await this.instantiate();
        // TODO(https://github.com/noir-lang/noir/issues/5661): This needs to be updated to handle recursive aggregation.
        // There is still a proofAsFields method but we could consider getting rid of it as the proof itself
        // is a list of field elements.
        // UltraHonk also does not have public inputs directly prepended to the proof and they are still instead
        // inserted at an offset.
        // const proof = reconstructProofWithPublicInputs(proofData);
        // const proofAsFields = (await this.api.acirProofAsFieldsUltraHonk(proof)).slice(numOfPublicInputs);
        // TODO: perhaps we should put this in the init function. Need to benchmark
        // TODO how long it takes.
        const vkBuf = await this.api.acirWriteVkUltraHonk(this.acirUncompressedBytecode);
        const vk = await this.api.acirVkAsFieldsUltraHonk(vkBuf);
        return {
            // TODO(https://github.com/noir-lang/noir/issues/5661)
            proofAsFields: [],
            vkAsFields: vk.map(vk => vk.toString()),
            // We use an empty string for the vk hash here as it is unneeded as part of the recursive artifacts
            // The user can be expected to hash the vk inside their circuit to check whether the vk is the circuit
            // they expect
            vkHash: '',
        };
    }
    async destroy() {
        if (!this.api) {
            return;
        }
        await this.api.destroy();
    }
}
exports.UltraHonkBackend = UltraHonkBackend;
function serializeAztecClientExecutionSteps(acirBuf, witnessBuf, vksBuf) {
    const steps = [];
    for (let i = 0; i < acirBuf.length; i++) {
        const bytecode = acirBuf[i];
        // Witnesses are not provided at all for gates info.
        const witness = witnessBuf[i] || Buffer.from([]);
        // VKs are optional for proving (deprecated feature) or not provided at all for gates info.
        const vk = vksBuf[i] || Buffer.from([]);
        const functionName = `unknown_wasm_${i}`;
        steps.push({
            bytecode,
            witness,
            vk,
            functionName,
        });
    }
    return new pack_1.Encoder({ useRecords: false }).pack(steps);
}
class AztecClientBackend {
    constructor(acirBuf, options = { threads: 1 }) {
        this.acirBuf = acirBuf;
        this.options = options;
    }
    /** @ignore */
    async instantiate() {
        if (!this.api) {
            const api = await index_js_1.Barretenberg.new(this.options);
            await api.initSRSClientIVC();
            this.api = api;
        }
    }
    async prove(witnessBuf, vksBuf = []) {
        if (vksBuf.length !== 0 && this.acirBuf.length !== witnessBuf.length) {
            throw new AztecClientBackendError('Witness and bytecodes must have the same stack depth!');
        }
        if (vksBuf.length !== 0 && vksBuf.length !== witnessBuf.length) {
            // NOTE: we allow 0 as an explicit 'I have no VKs'. This is a deprecated feature.
            throw new AztecClientBackendError('Witness and VKs must have the same stack depth!');
        }
        await this.instantiate();
        const ivcInputsBuf = serializeAztecClientExecutionSteps(this.acirBuf, witnessBuf, vksBuf);
        const proofAndVk = await this.api.acirProveAztecClient(ivcInputsBuf);
        const [proof, vk] = proofAndVk;
        if (!(await this.verify(proof, vk))) {
            throw new AztecClientBackendError('Failed to verify the private (ClientIVC) transaction proof!');
        }
        return proofAndVk;
    }
    async verify(proof, vk) {
        await this.instantiate();
        return this.api.acirVerifyAztecClient(proof, vk);
    }
    async gates() {
        // call function on API
        await this.instantiate();
        const ivcInputsBuf = serializeAztecClientExecutionSteps(this.acirBuf, [], []);
        const resultBuffer = await this.api.acirGatesAztecClient(ivcInputsBuf);
        return parseBigEndianU32Array(resultBuffer);
    }
    async destroy() {
        if (!this.api) {
            return;
        }
        await this.api.destroy();
    }
}
exports.AztecClientBackend = AztecClientBackend;
// Converts bytecode from a base64 string to a Uint8Array
function acirToUint8Array(base64EncodedBytecode) {
    const compressedByteCode = base64Decode(base64EncodedBytecode);
    return (0, pako_1.ungzip)(compressedByteCode);
}
// Since this is a simple function, we can use feature detection to
// see if we are in the nodeJs environment or the browser environment.
function base64Decode(input) {
    if (typeof Buffer !== 'undefined') {
        // Node.js environment
        const b = Buffer.from(input, 'base64');
        return new Uint8Array(b.buffer, b.byteOffset, b.byteLength);
    }
    else if (typeof atob === 'function') {
        // Browser environment
        return Uint8Array.from(atob(input), c => c.charCodeAt(0));
    }
    else {
        throw new Error('No implementation found for base64 decoding.');
    }
}
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiYmFja2VuZC5qcyIsInNvdXJjZVJvb3QiOiIiLCJzb3VyY2VzIjpbIi4uLy4uLy4uL3NyYy9iYXJyZXRlbmJlcmcvYmFja2VuZC50cyJdLCJuYW1lcyI6W10sIm1hcHBpbmdzIjoiOzs7QUFBQSx5Q0FBMEU7QUFDMUUsMERBQW1EO0FBQ25ELGdEQU8yQjtBQUMzQix3Q0FBd0M7QUFDeEMsK0JBQThCO0FBRTlCLE1BQWEsdUJBQXdCLFNBQVEsS0FBSztJQUNoRCxZQUFZLE9BQWU7UUFDekIsS0FBSyxDQUFDLE9BQU8sQ0FBQyxDQUFDO0lBQ2pCLENBQUM7Q0FDRjtBQUpELDBEQUlDO0FBRUQsOENBQThDO0FBQzlDLDJFQUEyRTtBQUMzRSxTQUFTLHNCQUFzQixDQUFDLE1BQWtCO0lBQ2hELE1BQU0sRUFBRSxHQUFHLElBQUksUUFBUSxDQUFDLE1BQU0sQ0FBQyxNQUFNLEVBQUUsTUFBTSxDQUFDLFVBQVUsRUFBRSxNQUFNLENBQUMsVUFBVSxDQUFDLENBQUM7SUFFN0UsSUFBSSxNQUFNLEdBQUcsQ0FBQyxDQUFDO0lBQ2YsTUFBTSxLQUFLLEdBQUcsTUFBTSxDQUFDLFVBQVUsS0FBSyxDQUFDLENBQUMsQ0FBQyxzQ0FBc0M7SUFFN0UsTUFBTSxHQUFHLEdBQWEsSUFBSSxLQUFLLENBQUMsS0FBSyxDQUFDLENBQUM7SUFDdkMsS0FBSyxJQUFJLENBQUMsR0FBRyxDQUFDLEVBQUUsQ0FBQyxHQUFHLEtBQUssRUFBRSxDQUFDLEVBQUUsRUFBRSxDQUFDO1FBQy9CLEdBQUcsQ0FBQyxDQUFDLENBQUMsR0FBRyxFQUFFLENBQUMsU0FBUyxDQUFDLE1BQU0sRUFBRSxLQUFLLENBQUMsQ0FBQztRQUNyQyxNQUFNLElBQUksQ0FBQyxDQUFDO0lBQ2QsQ0FBQztJQUVELE9BQU8sR0FBRyxDQUFDO0FBQ2IsQ0FBQztBQTRCRCxNQUFhLGdCQUFnQjtJQVMzQixZQUNFLFlBQW9CLEVBQ1YsaUJBQWlDLEVBQUUsT0FBTyxFQUFFLENBQUMsRUFBRSxFQUMvQyxpQkFBaUMsRUFBRSxTQUFTLEVBQUUsS0FBSyxFQUFFO1FBRHJELG1CQUFjLEdBQWQsY0FBYyxDQUFpQztRQUMvQyxtQkFBYyxHQUFkLGNBQWMsQ0FBdUM7UUFFL0QsSUFBSSxDQUFDLHdCQUF3QixHQUFHLGdCQUFnQixDQUFDLFlBQVksQ0FBQyxDQUFDO0lBQ2pFLENBQUM7SUFDRCxjQUFjO0lBQ04sS0FBSyxDQUFDLFdBQVc7UUFDdkIsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLEVBQUUsQ0FBQztZQUNkLE1BQU0sR0FBRyxHQUFHLE1BQU0sdUJBQVksQ0FBQyxHQUFHLENBQUMsSUFBSSxDQUFDLGNBQWMsQ0FBQyxDQUFDO1lBQ3hELE1BQU0sYUFBYSxHQUFHLElBQUksQ0FBQztZQUMzQixNQUFNLEdBQUcsQ0FBQyxXQUFXLENBQUMsSUFBSSxDQUFDLHdCQUF3QixFQUFFLElBQUksQ0FBQyxjQUFjLENBQUMsU0FBUyxFQUFFLGFBQWEsQ0FBQyxDQUFDO1lBRW5HLG1EQUFtRDtZQUNuRCxrRkFBa0Y7WUFDbEYsSUFBSSxDQUFDLEdBQUcsR0FBRyxHQUFHLENBQUM7UUFDakIsQ0FBQztJQUNILENBQUM7SUFFRCxLQUFLLENBQUMsYUFBYSxDQUFDLGlCQUE2QixFQUFFLE9BQWlDO1FBQ2xGLE1BQU0sSUFBSSxDQUFDLFdBQVcsRUFBRSxDQUFDO1FBRXpCLE1BQU0sY0FBYyxHQUFHLE9BQU8sRUFBRSxNQUFNO1lBQ3BDLENBQUMsQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLHdCQUF3QixDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDO1lBQ2xELENBQUMsQ0FBQyxPQUFPLEVBQUUsUUFBUTtnQkFDakIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsMEJBQTBCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7Z0JBQ3BELENBQUMsQ0FBQyxPQUFPLEVBQUUsUUFBUTtvQkFDakIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsMEJBQTBCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7b0JBQ3BELENBQUMsQ0FBQyxPQUFPLEVBQUUsVUFBVTt3QkFDbkIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsNEJBQTRCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7d0JBQ3RELENBQUMsQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLGtCQUFrQixDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLENBQUM7UUFFckQsTUFBTSxxQkFBcUIsR0FBRyxNQUFNLGNBQWMsQ0FBQyxJQUFJLENBQUMsd0JBQXdCLEVBQUUsSUFBQSxhQUFNLEVBQUMsaUJBQWlCLENBQUMsQ0FBQyxDQUFDO1FBRTdHLDhDQUE4QztRQUM5QyxNQUFNLGdCQUFnQixHQUFHLE9BQU8sRUFBRSxNQUFNO1lBQ3RDLENBQUMsQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLDBCQUEwQixDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDO1lBQ3BELENBQUMsQ0FBQyxPQUFPLEVBQUUsUUFBUTtnQkFDakIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsNEJBQTRCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7Z0JBQ3RELENBQUMsQ0FBQyxPQUFPLEVBQUUsUUFBUTtvQkFDakIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsNEJBQTRCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7b0JBQ3RELENBQUMsQ0FBQyxPQUFPLEVBQUUsVUFBVTt3QkFDbkIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsOEJBQThCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7d0JBQ3hELENBQUMsQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLG9CQUFvQixDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLENBQUM7UUFFdkQsTUFBTSxFQUFFLEdBQUcsTUFBTSxnQkFBZ0IsQ0FBQyxJQUFJLENBQUMsd0JBQXdCLENBQUMsQ0FBQztRQUNqRSxNQUFNLFVBQVUsR0FBRyxNQUFNLElBQUksQ0FBQyxHQUFHLENBQUMsdUJBQXVCLENBQUMsSUFBSSx5QkFBUyxDQUFDLEVBQUUsQ0FBQyxDQUFDLENBQUM7UUFFN0UsdURBQXVEO1FBQ3ZELE1BQU0scUJBQXFCLEdBQUcsQ0FBQyxDQUFDLENBQUMsb0NBQW9DO1FBQ3JFLE1BQU0sZUFBZSxHQUFHLE1BQU0sQ0FBQyxVQUFVLENBQUMscUJBQXFCLENBQUMsQ0FBQyxRQUFRLEVBQUUsQ0FBQyxHQUFHLDhCQUFtQixDQUFDO1FBRW5HLE1BQU0sRUFBRSxLQUFLLEVBQUUsWUFBWSxFQUFFLGlCQUFpQixFQUFFLEdBQUcsSUFBQSx5QkFBYyxFQUFDLHFCQUFxQixFQUFFLGVBQWUsQ0FBQyxDQUFDO1FBQzFHLE1BQU0sWUFBWSxHQUFHLElBQUEsMEJBQWUsRUFBQyxpQkFBaUIsQ0FBQyxDQUFDO1FBRXhELE9BQU8sRUFBRSxLQUFLLEVBQUUsWUFBWSxFQUFFLENBQUM7SUFDakMsQ0FBQztJQUVELEtBQUssQ0FBQyxXQUFXLENBQUMsU0FBb0IsRUFBRSxPQUFpQztRQUN2RSxNQUFNLElBQUksQ0FBQyxXQUFXLEVBQUUsQ0FBQztRQUV6QixNQUFNLEtBQUssR0FBRyxJQUFBLCtCQUFvQixFQUFDLElBQUEsK0JBQW9CLEVBQUMsU0FBUyxDQUFDLFlBQVksQ0FBQyxFQUFFLFNBQVMsQ0FBQyxLQUFLLENBQUMsQ0FBQztRQUVsRyxNQUFNLGdCQUFnQixHQUFHLE9BQU8sRUFBRSxNQUFNO1lBQ3RDLENBQUMsQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLDBCQUEwQixDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDO1lBQ3BELENBQUMsQ0FBQyxPQUFPLEVBQUUsUUFBUTtnQkFDakIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsNEJBQTRCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7Z0JBQ3RELENBQUMsQ0FBQyxPQUFPLEVBQUUsUUFBUTtvQkFDakIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsNEJBQTRCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7b0JBQ3RELENBQUMsQ0FBQyxPQUFPLEVBQUUsVUFBVTt3QkFDbkIsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsOEJBQThCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7d0JBQ3hELENBQUMsQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLG9CQUFvQixDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsR0FBRyxDQUFDLENBQUM7UUFDdkQsTUFBTSxlQUFlLEdBQUcsT0FBTyxFQUFFLE1BQU07WUFDckMsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMseUJBQXlCLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUM7WUFDbkQsQ0FBQyxDQUFDLE9BQU8sRUFBRSxRQUFRO2dCQUNqQixDQUFDLENBQUMsSUFBSSxDQUFDLEdBQUcsQ0FBQywyQkFBMkIsQ0FBQyxJQUFJLENBQUMsSUFBSSxDQUFDLEdBQUcsQ0FBQztnQkFDckQsQ0FBQyxDQUFDLE9BQU8sRUFBRSxRQUFRO29CQUNqQixDQUFDLENBQUMsSUFBSSxDQUFDLEdBQUcsQ0FBQywyQkFBMkIsQ0FBQyxJQUFJLENBQUMsSUFBSSxDQUFDLEdBQUcsQ0FBQztvQkFDckQsQ0FBQyxDQUFDLE9BQU8sRUFBRSxVQUFVO3dCQUNuQixDQUFDLENBQUMsSUFBSSxDQUFDLEdBQUcsQ0FBQyw2QkFBNkIsQ0FBQyxJQUFJLENBQUMsSUFBSSxDQUFDLEdBQUcsQ0FBQzt3QkFDdkQsQ0FBQyxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsbUJBQW1CLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLENBQUMsQ0FBQztRQUV0RCxNQUFNLEtBQUssR0FBRyxNQUFNLGdCQUFnQixDQUFDLElBQUksQ0FBQyx3QkFBd0IsQ0FBQyxDQUFDO1FBQ3BFLE9BQU8sTUFBTSxlQUFlLENBQUMsS0FBSyxFQUFFLElBQUkseUJBQVMsQ0FBQyxLQUFLLENBQUMsQ0FBQyxDQUFDO0lBQzVELENBQUM7SUFFRCxLQUFLLENBQUMsa0JBQWtCLENBQUMsT0FBaUM7UUFDeEQsTUFBTSxJQUFJLENBQUMsV0FBVyxFQUFFLENBQUM7UUFDekIsT0FBTyxPQUFPLEVBQUUsTUFBTTtZQUNwQixDQUFDLENBQUMsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLDBCQUEwQixDQUFDLElBQUksQ0FBQyx3QkFBd0IsQ0FBQztZQUMxRSxDQUFDLENBQUMsT0FBTyxFQUFFLFFBQVE7Z0JBQ2pCLENBQUMsQ0FBQyxNQUFNLElBQUksQ0FBQyxHQUFHLENBQUMsNEJBQTRCLENBQUMsSUFBSSxDQUFDLHdCQUF3QixDQUFDO2dCQUM1RSxDQUFDLENBQUMsT0FBTyxFQUFFLFFBQVE7b0JBQ2pCLENBQUMsQ0FBQyxNQUFNLElBQUksQ0FBQyxHQUFHLENBQUMsNEJBQTRCLENBQUMsSUFBSSxDQUFDLHdCQUF3QixDQUFDO29CQUM1RSxDQUFDLENBQUMsT0FBTyxFQUFFLFVBQVU7d0JBQ25CLENBQUMsQ0FBQyxNQUFNLElBQUksQ0FBQyxHQUFHLENBQUMsOEJBQThCLENBQUMsSUFBSSxDQUFDLHdCQUF3QixDQUFDO3dCQUM5RSxDQUFDLENBQUMsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLG9CQUFvQixDQUFDLElBQUksQ0FBQyx3QkFBd0IsQ0FBQyxDQUFDO0lBQy9FLENBQUM7SUFFRCwrQ0FBK0M7SUFDL0MsS0FBSyxDQUFDLG1CQUFtQixDQUFDLEVBQWU7UUFDdkMsTUFBTSxJQUFJLENBQUMsV0FBVyxFQUFFLENBQUM7UUFDekIsTUFBTSxLQUFLLEdBQUcsRUFBRSxJQUFJLENBQUMsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLDBCQUEwQixDQUFDLElBQUksQ0FBQyx3QkFBd0IsQ0FBQyxDQUFDLENBQUM7UUFDL0YsT0FBTyxNQUFNLElBQUksQ0FBQyxHQUFHLENBQUMsd0JBQXdCLENBQUMsSUFBSSxDQUFDLHdCQUF3QixFQUFFLElBQUkseUJBQVMsQ0FBQyxLQUFLLENBQUMsQ0FBQyxDQUFDO0lBQ3RHLENBQUM7SUFFRCw4SkFBOEo7SUFDOUosS0FBSyxDQUFDLCtCQUErQjtJQUNuQyw2REFBNkQ7SUFDN0QsTUFBa0I7SUFDbEIsNkRBQTZEO0lBQzdELGtCQUEwQjtRQUUxQixNQUFNLElBQUksQ0FBQyxXQUFXLEVBQUUsQ0FBQztRQUN6QixpSEFBaUg7UUFDakgsb0dBQW9HO1FBQ3BHLCtCQUErQjtRQUMvQix3R0FBd0c7UUFDeEcseUJBQXlCO1FBQ3pCLDZEQUE2RDtRQUM3RCxxR0FBcUc7UUFFckcsMkVBQTJFO1FBQzNFLDBCQUEwQjtRQUMxQixNQUFNLEtBQUssR0FBRyxNQUFNLElBQUksQ0FBQyxHQUFHLENBQUMsb0JBQW9CLENBQUMsSUFBSSxDQUFDLHdCQUF3QixDQUFDLENBQUM7UUFDakYsTUFBTSxFQUFFLEdBQUcsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLHVCQUF1QixDQUFDLEtBQUssQ0FBQyxDQUFDO1FBRXpELE9BQU87WUFDTCxzREFBc0Q7WUFDdEQsYUFBYSxFQUFFLEVBQUU7WUFDakIsVUFBVSxFQUFFLEVBQUUsQ0FBQyxHQUFHLENBQUMsRUFBRSxDQUFDLEVBQUUsQ0FBQyxFQUFFLENBQUMsUUFBUSxFQUFFLENBQUM7WUFDdkMsbUdBQW1HO1lBQ25HLHNHQUFzRztZQUN0RyxjQUFjO1lBQ2QsTUFBTSxFQUFFLEVBQUU7U0FDWCxDQUFDO0lBQ0osQ0FBQztJQUVELEtBQUssQ0FBQyxPQUFPO1FBQ1gsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLEVBQUUsQ0FBQztZQUNkLE9BQU87UUFDVCxDQUFDO1FBQ0QsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLE9BQU8sRUFBRSxDQUFDO0lBQzNCLENBQUM7Q0FDRjtBQTFKRCw0Q0EwSkM7QUFZRCxTQUFTLGtDQUFrQyxDQUN6QyxPQUFxQixFQUNyQixVQUF3QixFQUN4QixNQUFvQjtJQUVwQixNQUFNLEtBQUssR0FBK0IsRUFBRSxDQUFDO0lBQzdDLEtBQUssSUFBSSxDQUFDLEdBQUcsQ0FBQyxFQUFFLENBQUMsR0FBRyxPQUFPLENBQUMsTUFBTSxFQUFFLENBQUMsRUFBRSxFQUFFLENBQUM7UUFDeEMsTUFBTSxRQUFRLEdBQUcsT0FBTyxDQUFDLENBQUMsQ0FBQyxDQUFDO1FBQzVCLG9EQUFvRDtRQUNwRCxNQUFNLE9BQU8sR0FBRyxVQUFVLENBQUMsQ0FBQyxDQUFDLElBQUksTUFBTSxDQUFDLElBQUksQ0FBQyxFQUFFLENBQUMsQ0FBQztRQUNqRCwyRkFBMkY7UUFDM0YsTUFBTSxFQUFFLEdBQUcsTUFBTSxDQUFDLENBQUMsQ0FBQyxJQUFJLE1BQU0sQ0FBQyxJQUFJLENBQUMsRUFBRSxDQUFDLENBQUM7UUFDeEMsTUFBTSxZQUFZLEdBQUcsZ0JBQWdCLENBQUMsRUFBRSxDQUFDO1FBQ3pDLEtBQUssQ0FBQyxJQUFJLENBQUM7WUFDVCxRQUFRO1lBQ1IsT0FBTztZQUNQLEVBQUU7WUFDRixZQUFZO1NBQ2IsQ0FBQyxDQUFDO0lBQ0wsQ0FBQztJQUNELE9BQU8sSUFBSSxjQUFPLENBQUMsRUFBRSxVQUFVLEVBQUUsS0FBSyxFQUFFLENBQUMsQ0FBQyxJQUFJLENBQUMsS0FBSyxDQUFDLENBQUM7QUFDeEQsQ0FBQztBQUVELE1BQWEsa0JBQWtCO0lBUTdCLFlBQ1ksT0FBcUIsRUFDckIsVUFBMEIsRUFBRSxPQUFPLEVBQUUsQ0FBQyxFQUFFO1FBRHhDLFlBQU8sR0FBUCxPQUFPLENBQWM7UUFDckIsWUFBTyxHQUFQLE9BQU8sQ0FBaUM7SUFDakQsQ0FBQztJQUVKLGNBQWM7SUFDTixLQUFLLENBQUMsV0FBVztRQUN2QixJQUFJLENBQUMsSUFBSSxDQUFDLEdBQUcsRUFBRSxDQUFDO1lBQ2QsTUFBTSxHQUFHLEdBQUcsTUFBTSx1QkFBWSxDQUFDLEdBQUcsQ0FBQyxJQUFJLENBQUMsT0FBTyxDQUFDLENBQUM7WUFDakQsTUFBTSxHQUFHLENBQUMsZ0JBQWdCLEVBQUUsQ0FBQztZQUM3QixJQUFJLENBQUMsR0FBRyxHQUFHLEdBQUcsQ0FBQztRQUNqQixDQUFDO0lBQ0gsQ0FBQztJQUVELEtBQUssQ0FBQyxLQUFLLENBQUMsVUFBd0IsRUFBRSxTQUF1QixFQUFFO1FBQzdELElBQUksTUFBTSxDQUFDLE1BQU0sS0FBSyxDQUFDLElBQUksSUFBSSxDQUFDLE9BQU8sQ0FBQyxNQUFNLEtBQUssVUFBVSxDQUFDLE1BQU0sRUFBRSxDQUFDO1lBQ3JFLE1BQU0sSUFBSSx1QkFBdUIsQ0FBQyx1REFBdUQsQ0FBQyxDQUFDO1FBQzdGLENBQUM7UUFDRCxJQUFJLE1BQU0sQ0FBQyxNQUFNLEtBQUssQ0FBQyxJQUFJLE1BQU0sQ0FBQyxNQUFNLEtBQUssVUFBVSxDQUFDLE1BQU0sRUFBRSxDQUFDO1lBQy9ELGlGQUFpRjtZQUNqRixNQUFNLElBQUksdUJBQXVCLENBQUMsaURBQWlELENBQUMsQ0FBQztRQUN2RixDQUFDO1FBQ0QsTUFBTSxJQUFJLENBQUMsV0FBVyxFQUFFLENBQUM7UUFDekIsTUFBTSxZQUFZLEdBQUcsa0NBQWtDLENBQUMsSUFBSSxDQUFDLE9BQU8sRUFBRSxVQUFVLEVBQUUsTUFBTSxDQUFDLENBQUM7UUFDMUYsTUFBTSxVQUFVLEdBQUcsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLG9CQUFvQixDQUFDLFlBQVksQ0FBQyxDQUFDO1FBQ3JFLE1BQU0sQ0FBQyxLQUFLLEVBQUUsRUFBRSxDQUFDLEdBQUcsVUFBVSxDQUFDO1FBQy9CLElBQUksQ0FBQyxDQUFDLE1BQU0sSUFBSSxDQUFDLE1BQU0sQ0FBQyxLQUFLLEVBQUUsRUFBRSxDQUFDLENBQUMsRUFBRSxDQUFDO1lBQ3BDLE1BQU0sSUFBSSx1QkFBdUIsQ0FBQyw2REFBNkQsQ0FBQyxDQUFDO1FBQ25HLENBQUM7UUFDRCxPQUFPLFVBQVUsQ0FBQztJQUNwQixDQUFDO0lBRUQsS0FBSyxDQUFDLE1BQU0sQ0FBQyxLQUFpQixFQUFFLEVBQWM7UUFDNUMsTUFBTSxJQUFJLENBQUMsV0FBVyxFQUFFLENBQUM7UUFDekIsT0FBTyxJQUFJLENBQUMsR0FBRyxDQUFDLHFCQUFxQixDQUFDLEtBQUssRUFBRSxFQUFFLENBQUMsQ0FBQztJQUNuRCxDQUFDO0lBRUQsS0FBSyxDQUFDLEtBQUs7UUFDVCx1QkFBdUI7UUFDdkIsTUFBTSxJQUFJLENBQUMsV0FBVyxFQUFFLENBQUM7UUFDekIsTUFBTSxZQUFZLEdBQUcsa0NBQWtDLENBQUMsSUFBSSxDQUFDLE9BQU8sRUFBRSxFQUFFLEVBQUUsRUFBRSxDQUFDLENBQUM7UUFDOUUsTUFBTSxZQUFZLEdBQUcsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLG9CQUFvQixDQUFDLFlBQVksQ0FBQyxDQUFDO1FBQ3ZFLE9BQU8sc0JBQXNCLENBQUMsWUFBWSxDQUFDLENBQUM7SUFDOUMsQ0FBQztJQUVELEtBQUssQ0FBQyxPQUFPO1FBQ1gsSUFBSSxDQUFDLElBQUksQ0FBQyxHQUFHLEVBQUUsQ0FBQztZQUNkLE9BQU87UUFDVCxDQUFDO1FBQ0QsTUFBTSxJQUFJLENBQUMsR0FBRyxDQUFDLE9BQU8sRUFBRSxDQUFDO0lBQzNCLENBQUM7Q0FDRjtBQTNERCxnREEyREM7QUFFRCx5REFBeUQ7QUFDekQsU0FBUyxnQkFBZ0IsQ0FBQyxxQkFBNkI7SUFDckQsTUFBTSxrQkFBa0IsR0FBRyxZQUFZLENBQUMscUJBQXFCLENBQUMsQ0FBQztJQUMvRCxPQUFPLElBQUEsYUFBTSxFQUFDLGtCQUFrQixDQUFDLENBQUM7QUFDcEMsQ0FBQztBQUVELG1FQUFtRTtBQUNuRSxzRUFBc0U7QUFDdEUsU0FBUyxZQUFZLENBQUMsS0FBYTtJQUNqQyxJQUFJLE9BQU8sTUFBTSxLQUFLLFdBQVcsRUFBRSxDQUFDO1FBQ2xDLHNCQUFzQjtRQUN0QixNQUFNLENBQUMsR0FBRyxNQUFNLENBQUMsSUFBSSxDQUFDLEtBQUssRUFBRSxRQUFRLENBQUMsQ0FBQztRQUN2QyxPQUFPLElBQUksVUFBVSxDQUFDLENBQUMsQ0FBQyxNQUFNLEVBQUUsQ0FBQyxDQUFDLFVBQVUsRUFBRSxDQUFDLENBQUMsVUFBVSxDQUFDLENBQUM7SUFDOUQsQ0FBQztTQUFNLElBQUksT0FBTyxJQUFJLEtBQUssVUFBVSxFQUFFLENBQUM7UUFDdEMsc0JBQXNCO1FBQ3RCLE9BQU8sVUFBVSxDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsS0FBSyxDQUFDLEVBQUUsQ0FBQyxDQUFDLEVBQUUsQ0FBQyxDQUFDLENBQUMsVUFBVSxDQUFDLENBQUMsQ0FBQyxDQUFDLENBQUM7SUFDNUQsQ0FBQztTQUFNLENBQUM7UUFDTixNQUFNLElBQUksS0FBSyxDQUFDLDhDQUE4QyxDQUFDLENBQUM7SUFDbEUsQ0FBQztBQUNILENBQUMifQ==