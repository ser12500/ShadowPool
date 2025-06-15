import { NetCrs, NetGrumpkinCrs } from '../net_crs.js';
import { closeSync, mkdirSync, openSync, readFileSync, readSync, writeFileSync, createWriteStream } from 'fs';
import { stat } from 'fs/promises';
import { Readable } from 'stream';
import { homedir } from 'os';
import { finished } from 'stream/promises';
import { createDebugLogger } from '../../log/index.js';
/**
 * Generic CRS finder utility class.
 */
export class Crs {
    constructor(numPoints, path, logger = createDebugLogger('crs')) {
        this.numPoints = numPoints;
        this.path = path;
        this.logger = logger;
    }
    static async new(numPoints, crsPath = homedir() + '/.bb-crs', logger = createDebugLogger('crs')) {
        const crs = new Crs(numPoints, crsPath, logger);
        await crs.init();
        return crs;
    }
    async init() {
        mkdirSync(this.path, { recursive: true });
        const g1FileSize = await stat(this.path + '/bn254_g1.dat')
            .then(stats => stats.size)
            .catch(() => 0);
        const g2FileSize = await stat(this.path + '/bn254_g2.dat')
            .then(stats => stats.size)
            .catch(() => 0);
        if (g1FileSize >= this.numPoints * 64 && g1FileSize % 64 == 0 && g2FileSize == 128) {
            this.logger(`Using cached CRS of size ${g1FileSize / 64}`);
            return;
        }
        this.logger(`Downloading CRS of size ${this.numPoints} into ${this.path}`);
        const crs = new NetCrs(this.numPoints);
        const [g1, g2] = await Promise.all([crs.streamG1Data(), crs.streamG2Data()]);
        await Promise.all([
            finished(Readable.fromWeb(g1).pipe(createWriteStream(this.path + '/bn254_g1.dat'))),
            finished(Readable.fromWeb(g2).pipe(createWriteStream(this.path + '/bn254_g2.dat'))),
        ]);
    }
    /**
     * G1 points data for prover key.
     * @returns The points data.
     */
    getG1Data() {
        // Ensure length > 0, otherwise we might read a huge file.
        // This is a backup.
        const length = Math.max(this.numPoints, 1) * 64;
        const fd = openSync(this.path + '/bn254_g1.dat', 'r');
        const buffer = new Uint8Array(length);
        readSync(fd, buffer, 0, length, 0);
        closeSync(fd);
        return buffer;
    }
    /**
     * G2 points data for verification key.
     * @returns The points data.
     */
    getG2Data() {
        return readFileSync(this.path + '/bn254_g2.dat');
    }
}
/**
 * Generic Grumpkin CRS finder utility class.
 */
export class GrumpkinCrs {
    constructor(numPoints, path, logger = createDebugLogger('crs')) {
        this.numPoints = numPoints;
        this.path = path;
        this.logger = logger;
    }
    static async new(numPoints, crsPath = homedir() + '/.bb-crs', logger = createDebugLogger('crs')) {
        const crs = new GrumpkinCrs(numPoints, crsPath, logger);
        await crs.init();
        return crs;
    }
    async init() {
        mkdirSync(this.path, { recursive: true });
        const g1FileSize = await stat(this.path + '/grumpkin_g1.flat.dat')
            .then(stats => stats.size)
            .catch(() => 0);
        if (g1FileSize >= this.numPoints * 64 && g1FileSize % 64 == 0) {
            this.logger(`Using cached Grumpkin CRS of size ${g1FileSize / 64}`);
            return;
        }
        this.logger(`Downloading Grumpkin CRS of size ${this.numPoints} into ${this.path}`);
        const crs = new NetGrumpkinCrs(this.numPoints);
        const stream = await crs.streamG1Data();
        await finished(Readable.fromWeb(stream).pipe(createWriteStream(this.path + '/grumpkin_g1.flat.dat')));
        writeFileSync(this.path + '/grumpkin_size', String(crs.numPoints));
    }
    /**
     * G1 points data for prover key.
     * @returns The points data.
     */
    getG1Data() {
        return readFileSync(this.path + '/grumpkin_g1.flat.dat');
    }
}
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiaW5kZXguanMiLCJzb3VyY2VSb290IjoiIiwic291cmNlcyI6WyIuLi8uLi8uLi8uLi9zcmMvY3JzL25vZGUvaW5kZXgudHMiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IkFBQUEsT0FBTyxFQUFFLE1BQU0sRUFBRSxjQUFjLEVBQUUsTUFBTSxlQUFlLENBQUM7QUFDdkQsT0FBTyxFQUFFLFNBQVMsRUFBRSxTQUFTLEVBQUUsUUFBUSxFQUFFLFlBQVksRUFBRSxRQUFRLEVBQUUsYUFBYSxFQUFFLGlCQUFpQixFQUFFLE1BQU0sSUFBSSxDQUFDO0FBQzlHLE9BQU8sRUFBRSxJQUFJLEVBQUUsTUFBTSxhQUFhLENBQUM7QUFDbkMsT0FBTyxFQUFFLFFBQVEsRUFBRSxNQUFNLFFBQVEsQ0FBQztBQUNsQyxPQUFPLEVBQUUsT0FBTyxFQUFFLE1BQU0sSUFBSSxDQUFDO0FBQzdCLE9BQU8sRUFBRSxRQUFRLEVBQUUsTUFBTSxpQkFBaUIsQ0FBQztBQUMzQyxPQUFPLEVBQUUsaUJBQWlCLEVBQUUsTUFBTSxvQkFBb0IsQ0FBQztBQUV2RDs7R0FFRztBQUNILE1BQU0sT0FBTyxHQUFHO0lBQ2QsWUFDa0IsU0FBaUIsRUFDakIsSUFBWSxFQUNYLFNBQWdDLGlCQUFpQixDQUFDLEtBQUssQ0FBQztRQUZ6RCxjQUFTLEdBQVQsU0FBUyxDQUFRO1FBQ2pCLFNBQUksR0FBSixJQUFJLENBQVE7UUFDWCxXQUFNLEdBQU4sTUFBTSxDQUFrRDtJQUN4RSxDQUFDO0lBRUosTUFBTSxDQUFDLEtBQUssQ0FBQyxHQUFHLENBQ2QsU0FBaUIsRUFDakIsT0FBTyxHQUFHLE9BQU8sRUFBRSxHQUFHLFVBQVUsRUFDaEMsU0FBZ0MsaUJBQWlCLENBQUMsS0FBSyxDQUFDO1FBRXhELE1BQU0sR0FBRyxHQUFHLElBQUksR0FBRyxDQUFDLFNBQVMsRUFBRSxPQUFPLEVBQUUsTUFBTSxDQUFDLENBQUM7UUFDaEQsTUFBTSxHQUFHLENBQUMsSUFBSSxFQUFFLENBQUM7UUFDakIsT0FBTyxHQUFHLENBQUM7SUFDYixDQUFDO0lBRUQsS0FBSyxDQUFDLElBQUk7UUFDUixTQUFTLENBQUMsSUFBSSxDQUFDLElBQUksRUFBRSxFQUFFLFNBQVMsRUFBRSxJQUFJLEVBQUUsQ0FBQyxDQUFDO1FBRTFDLE1BQU0sVUFBVSxHQUFHLE1BQU0sSUFBSSxDQUFDLElBQUksQ0FBQyxJQUFJLEdBQUcsZUFBZSxDQUFDO2FBQ3ZELElBQUksQ0FBQyxLQUFLLENBQUMsRUFBRSxDQUFDLEtBQUssQ0FBQyxJQUFJLENBQUM7YUFDekIsS0FBSyxDQUFDLEdBQUcsRUFBRSxDQUFDLENBQUMsQ0FBQyxDQUFDO1FBQ2xCLE1BQU0sVUFBVSxHQUFHLE1BQU0sSUFBSSxDQUFDLElBQUksQ0FBQyxJQUFJLEdBQUcsZUFBZSxDQUFDO2FBQ3ZELElBQUksQ0FBQyxLQUFLLENBQUMsRUFBRSxDQUFDLEtBQUssQ0FBQyxJQUFJLENBQUM7YUFDekIsS0FBSyxDQUFDLEdBQUcsRUFBRSxDQUFDLENBQUMsQ0FBQyxDQUFDO1FBRWxCLElBQUksVUFBVSxJQUFJLElBQUksQ0FBQyxTQUFTLEdBQUcsRUFBRSxJQUFJLFVBQVUsR0FBRyxFQUFFLElBQUksQ0FBQyxJQUFJLFVBQVUsSUFBSSxHQUFHLEVBQUUsQ0FBQztZQUNuRixJQUFJLENBQUMsTUFBTSxDQUFDLDRCQUE0QixVQUFVLEdBQUcsRUFBRSxFQUFFLENBQUMsQ0FBQztZQUMzRCxPQUFPO1FBQ1QsQ0FBQztRQUVELElBQUksQ0FBQyxNQUFNLENBQUMsMkJBQTJCLElBQUksQ0FBQyxTQUFTLFNBQVMsSUFBSSxDQUFDLElBQUksRUFBRSxDQUFDLENBQUM7UUFDM0UsTUFBTSxHQUFHLEdBQUcsSUFBSSxNQUFNLENBQUMsSUFBSSxDQUFDLFNBQVMsQ0FBQyxDQUFDO1FBQ3ZDLE1BQU0sQ0FBQyxFQUFFLEVBQUUsRUFBRSxDQUFDLEdBQUcsTUFBTSxPQUFPLENBQUMsR0FBRyxDQUFDLENBQUMsR0FBRyxDQUFDLFlBQVksRUFBRSxFQUFFLEdBQUcsQ0FBQyxZQUFZLEVBQUUsQ0FBQyxDQUFDLENB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