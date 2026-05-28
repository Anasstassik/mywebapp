const request = require('supertest');
const { app, prisma } = require('../app');

jest.mock('@prisma/client', () => {
  const mPrismaClient = {
    $queryRaw: jest.fn(),
    note: {
      findMany: jest.fn(),
      create: jest.fn(),
      findUnique: jest.fn(),
    },
  };
  return { PrismaClient: jest.fn(() => mPrismaClient) };
});

describe('Web App Endpoints', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('GET /health/alive should return 200 OK', async () => {
    const res = await request(app).get('/health/alive');
    expect(res.statusCode).toBe(200);
    expect(res.text).toBe('OK');
  });

  test('GET /health/ready should return 200 when DB is ok', async () => {
    prisma.$queryRaw.mockResolvedValueOnce([{ '?column?': 1 }]);
    const res = await request(app).get('/health/ready');
    expect(res.statusCode).toBe(200);
    expect(res.text).toBe('OK');
  });

  test('GET /health/ready should return 500 when DB fails', async () => {
    prisma.$queryRaw.mockRejectedValueOnce(new Error('DB Error'));
    const res = await request(app).get('/health/ready');
    expect(res.statusCode).toBe(500);
  });

  test('GET /notes should return list of notes as JSON', async () => {
    const mockNotes = [{ id: 1, title: 'Test Note' }];
    prisma.note.findMany.mockResolvedValueOnce(mockNotes);

    const res = await request(app).get('/notes').set('Accept', 'application/json');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual(mockNotes);
  });
});