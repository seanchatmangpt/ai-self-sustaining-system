/**
 * Mock Services for Reactor E2E Testing
 * Provides realistic service mocks for comprehensive testing scenarios
 */

import { createServer, Server } from 'http';
import { WebSocketServer } from 'ws';
import { nanoid } from 'nanoid';

export interface MockServiceConfig {
  port: number;
  latency: {
    min: number;
    max: number;
  };
  errorRate: number; // 0-1
  memoryLeak: boolean;
  responseSize: 'small' | 'medium' | 'large';
}

export interface MockWebSocketConfig {
  port: number;
  messageRate: number; // messages per second
  connectionLimit: number;
  dropRate: number; // 0-1
}

/**
 * HTTP Mock Service for testing reactor integrations
 */
export class ReactorMockHttpService {
  private server: Server | null = null;
  private config: MockServiceConfig;
  private requestCount = 0;
  private errorCount = 0;
  private memoryLeakData: any[] = [];

  constructor(config: MockServiceConfig) {
    this.config = config;
  }

  async start(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.server = createServer((req, res) => {
        this.handleRequest(req, res);
      });

      this.server.listen(this.config.port, () => {
        console.log(`Mock HTTP service started on port ${this.config.port}`);
        resolve();
      });

      this.server.on('error', reject);
    });
  }

  async stop(): Promise<void> {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          console.log(`Mock HTTP service stopped on port ${this.config.port}`);
          resolve();
        });
      } else {
        resolve();
      }
    });
  }

  private async handleRequest(req: any, res: any): Promise<void> {
    this.requestCount++;
    
    // Add realistic latency
    const latency = Math.random() * (this.config.latency.max - this.config.latency.min) + this.config.latency.min;
    await new Promise(resolve => setTimeout(resolve, latency));

    // Memory leak simulation
    if (this.config.memoryLeak) {
      this.memoryLeakData.push({
        id: nanoid(),
        timestamp: Date.now(),
        data: new Array(1000).fill(Math.random()),
        request: { 
          url: req.url, 
          method: req.method,
          headers: req.headers 
        }
      });
    }

    // Error simulation
    if (Math.random() < this.config.errorRate) {
      this.errorCount++;
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        error: 'Simulated service error',
        code: 'MOCK_ERROR',
        timestamp: new Date().toISOString(),
        requestId: nanoid()
      }));
      return;
    }

    // Handle different endpoints
    const url = new URL(req.url, `http://localhost:${this.config.port}`);
    const path = url.pathname;

    let responseData: any;

    if (path === '/api/health') {
      responseData = this.getHealthResponse();
    } else if (path === '/api/reactor/execute') {
      responseData = await this.getReactorExecuteResponse(req);
    } else if (path === '/api/data/process') {
      responseData = this.getDataProcessResponse();
    } else if (path === '/api/stress/memory') {
      responseData = this.getMemoryStressResponse();
    } else if (path === '/api/stress/cpu') {
      responseData = await this.getCpuStressResponse();
    } else {
      responseData = this.getDefaultResponse(path);
    }

    // Add response size variation
    responseData = this.adjustResponseSize(responseData);

    res.writeHead(200, { 
      'Content-Type': 'application/json',
      'X-Mock-Service': 'reactor-e2e',
      'X-Request-Count': this.requestCount.toString(),
      'X-Error-Count': this.errorCount.toString(),
      'X-Response-Time': latency.toString()
    });
    res.end(JSON.stringify(responseData));
  }

  private getHealthResponse(): any {
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      requestCount: this.requestCount,
      errorCount: this.errorCount,
      errorRate: this.requestCount > 0 ? this.errorCount / this.requestCount : 0,
      memoryUsage: process.memoryUsage(),
      config: {
        port: this.config.port,
        errorRate: this.config.errorRate,
        memoryLeak: this.config.memoryLeak
      }
    };
  }

  private async getReactorExecuteResponse(req: any): Promise<any> {
    // Simulate reactor execution
    const executionId = nanoid();
    const steps = ['validate', 'process', 'transform', 'output'];
    const stepResults = [];

    for (const step of steps) {
      // Simulate step execution time
      await new Promise(resolve => setTimeout(resolve, Math.random() * 50));
      
      stepResults.push({
        step,
        status: Math.random() > 0.1 ? 'completed' : 'failed',
        duration: Math.random() * 100,
        timestamp: new Date().toISOString()
      });
    }

    return {
      executionId,
      status: stepResults.every(s => s.status === 'completed') ? 'completed' : 'failed',
      steps: stepResults,
      totalDuration: stepResults.reduce((sum, s) => sum + s.duration, 0),
      timestamp: new Date().toISOString()
    };
  }

  private getDataProcessResponse(): any {
    const dataSize = this.config.responseSize === 'large' ? 1000 : 
                    this.config.responseSize === 'medium' ? 100 : 10;

    return {
      processed: true,
      timestamp: new Date().toISOString(),
      dataSize,
      data: Array.from({ length: dataSize }, (_, i) => ({
        id: i,
        value: Math.random(),
        processed: true,
        metadata: {
          processingTime: Math.random() * 10,
          algorithm: 'mock-processor-v1'
        }
      }))
    };
  }

  private getMemoryStressResponse(): any {
    // Generate large response to stress memory
    const largeData = Array.from({ length: 10000 }, (_, i) => ({
      id: i,
      data: new Array(100).fill(Math.random()),
      timestamp: Date.now(),
      metadata: {
        chunkSize: 100,
        totalChunks: 10000
      }
    }));

    return {
      type: 'memory-stress',
      generated: largeData.length,
      totalSize: JSON.stringify(largeData).length,
      timestamp: new Date().toISOString(),
      data: largeData
    };
  }

  private async getCpuStressResponse(): Promise<any> {
    // Simulate CPU-intensive operation
    const iterations = 100000;
    let result = 0;
    
    const startTime = process.hrtime.bigint();
    
    for (let i = 0; i < iterations; i++) {
      result += Math.sqrt(i) * Math.sin(i) * Math.cos(i);
    }
    
    const endTime = process.hrtime.bigint();
    const duration = Number(endTime - startTime) / 1000000; // Convert to milliseconds

    return {
      type: 'cpu-stress',
      iterations,
      result,
      duration,
      timestamp: new Date().toISOString()
    };
  }

  private getDefaultResponse(path: string): any {
    return {
      path,
      timestamp: new Date().toISOString(),
      requestCount: this.requestCount,
      message: 'Mock service response'
    };
  }

  private adjustResponseSize(data: any): any {
    if (this.config.responseSize === 'large') {
      data.padding = new Array(10000).fill('padding-data-to-increase-response-size');
    } else if (this.config.responseSize === 'medium') {
      data.padding = new Array(1000).fill('padding-data');
    }
    // Small responses have no padding
    
    return data;
  }

  getStats(): any {
    return {
      requestCount: this.requestCount,
      errorCount: this.errorCount,
      errorRate: this.requestCount > 0 ? this.errorCount / this.requestCount : 0,
      memoryLeakSize: this.memoryLeakData.length,
      uptime: process.uptime()
    };
  }
}

/**
 * WebSocket Mock Service for real-time testing
 */
export class ReactorMockWebSocketService {
  private wss: WebSocketServer | null = null;
  private config: MockWebSocketConfig;
  private connections: Set<any> = new Set();
  private messageCount = 0;
  private intervalId: NodeJS.Timeout | null = null;

  constructor(config: MockWebSocketConfig) {
    this.config = config;
  }

  async start(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.wss = new WebSocketServer({ 
        port: this.config.port,
        maxPayload: 1024 * 1024 // 1MB max payload
      });

      this.wss.on('connection', (ws) => {
        this.handleConnection(ws);
      });

      this.wss.on('listening', () => {
        console.log(`Mock WebSocket service started on port ${this.config.port}`);
        this.startMessageBroadcast();
        resolve();
      });

      this.wss.on('error', reject);
    });
  }

  async stop(): Promise<void> {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }

    if (this.wss) {
      this.wss.close();
      console.log(`Mock WebSocket service stopped on port ${this.config.port}`);
    }
  }

  private handleConnection(ws: any): void {
    if (this.connections.size >= this.config.connectionLimit) {
      ws.close(1013, 'Connection limit exceeded');
      return;
    }

    this.connections.add(ws);
    console.log(`WebSocket connection established (${this.connections.size}/${this.config.connectionLimit})`);

    ws.on('message', (data: Buffer) => {
      this.handleMessage(ws, data);
    });

    ws.on('close', () => {
      this.connections.delete(ws);
      console.log(`WebSocket connection closed (${this.connections.size}/${this.config.connectionLimit})`);
    });

    ws.on('error', (error: Error) => {
      console.error('WebSocket error:', error);
      this.connections.delete(ws);
    });

    // Send welcome message
    this.sendMessage(ws, {
      type: 'welcome',
      timestamp: new Date().toISOString(),
      connectionId: nanoid()
    });
  }

  private handleMessage(ws: any, data: Buffer): void {
    try {
      const message = JSON.parse(data.toString());
      
      // Echo message back with processing info
      const response = {
        type: 'echo',
        original: message,
        processed: new Date().toISOString(),
        messageId: nanoid()
      };

      this.sendMessage(ws, response);
      
    } catch (error) {
      this.sendMessage(ws, {
        type: 'error',
        message: 'Invalid JSON message',
        timestamp: new Date().toISOString()
      });
    }
  }

  private sendMessage(ws: any, message: any): void {
    // Simulate message drop rate
    if (Math.random() < this.config.dropRate) {
      return; // Drop message
    }

    try {
      ws.send(JSON.stringify(message));
      this.messageCount++;
    } catch (error) {
      console.error('Failed to send WebSocket message:', error);
    }
  }

  private startMessageBroadcast(): void {
    const interval = 1000 / this.config.messageRate; // Convert to milliseconds
    
    this.intervalId = setInterval(() => {
      const message = {
        type: 'broadcast',
        timestamp: new Date().toISOString(),
        messageId: nanoid(),
        data: {
          randomValue: Math.random(),
          connectionCount: this.connections.size,
          messageCount: this.messageCount
        }
      };

      this.connections.forEach((ws) => {
        this.sendMessage(ws, message);
      });
    }, interval);
  }

  getStats(): any {
    return {
      connectionCount: this.connections.size,
      messageCount: this.messageCount,
      connectionLimit: this.config.connectionLimit,
      messageRate: this.config.messageRate,
      dropRate: this.config.dropRate
    };
  }
}

/**
 * Mock Service Manager for coordinating multiple services
 */
export class MockServiceManager {
  private httpServices: ReactorMockHttpService[] = [];
  private wsServices: ReactorMockWebSocketService[] = [];

  async startCritical80Services(): Promise<void> {
    console.log('Starting Critical 80% mock services...');

    // High-reliability, low-latency service
    const criticalHttp = new ReactorMockHttpService({
      port: 3100,
      latency: { min: 10, max: 50 },
      errorRate: 0.01, // 1% error rate
      memoryLeak: false,
      responseSize: 'small'
    });

    const criticalWs = new ReactorMockWebSocketService({
      port: 3101,
      messageRate: 10,
      connectionLimit: 100,
      dropRate: 0.001 // 0.1% drop rate
    });

    await criticalHttp.start();
    await criticalWs.start();

    this.httpServices.push(criticalHttp);
    this.wsServices.push(criticalWs);
  }

  async startEdge20Services(): Promise<void> {
    console.log('Starting Edge 20% mock services...');

    // Unreliable, high-latency service for stress testing
    const edgeHttp = new ReactorMockHttpService({
      port: 3200,
      latency: { min: 500, max: 2000 },
      errorRate: 0.15, // 15% error rate
      memoryLeak: true,
      responseSize: 'large'
    });

    const edgeWs = new ReactorMockWebSocketService({
      port: 3201,
      messageRate: 50,
      connectionLimit: 10,
      dropRate: 0.1 // 10% drop rate
    });

    await edgeHttp.start();
    await edgeWs.start();

    this.httpServices.push(edgeHttp);
    this.wsServices.push(edgeWs);
  }

  async stopAllServices(): Promise<void> {
    console.log('Stopping all mock services...');

    const stopPromises = [
      ...this.httpServices.map(service => service.stop()),
      ...this.wsServices.map(service => service.stop())
    ];

    await Promise.all(stopPromises);

    this.httpServices = [];
    this.wsServices = [];
  }

  getServicesStats(): any {
    return {
      http: this.httpServices.map(service => service.getStats()),
      websocket: this.wsServices.map(service => service.getStats())
    };
  }
}

// Export singleton instance
export const mockServiceManager = new MockServiceManager();