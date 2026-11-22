import { Readable } from 'stream';

export interface StorageService {
  save(filename: string, buffer: Buffer): Promise<string>;
  getReadStream(filename: string): Promise<Readable>;
  exists(filename: string): Promise<boolean>;
  checkHealth(): Promise<boolean>;
}
