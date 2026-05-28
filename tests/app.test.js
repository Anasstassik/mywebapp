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
  });

  test('GET /health/ready should return 500 when DB fails', async () => {
    prisma.$queryRaw.mockRejectedValueOnce(new Error('DB Error'));
    const res = await request(app).get('/health/ready');
    expect(res.statusCode).toBe(500);
  });

  test('GET / should return HTML list of endpoints', async () => {
    const res = await request(app).get('/').set('Accept', 'text/html');
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain('API Endpoints');
  });

  test('GET / should return 406 if HTML is not accepted', async () => {
    const res = await request(app).get('/').set('Accept', 'text/plain');
    expect(res.statusCode).toBe(406);
  });

  test('GET /notes should return list of notes as JSON', async () => {
    const mockNotes = [{ id: 1, title: 'Test Note' }];
    prisma.note.findMany.mockResolvedValueOnce(mockNotes);

    const res = await request(app).get('/notes').set('Accept', 'application/json');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual(mockNotes);
  });

  test('GET /notes should return HTML table', async () => {
    const mockNotes = [{ id: 1, title: 'Test Note' }];
    prisma.note.findMany.mockResolvedValueOnce(mockNotes);

    const res = await request(app).get('/notes').set('Accept', 'text/html');
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain('<table');
  });

  test('POST /notes should return 400 if title or content missing', async () => {
    const res = await request(app).post('/notes').send({ title: 'No content' });
    expect(res.statusCode).toBe(400);
  });

  test('GET /notes/:id should return 404 if not found', async () => {
    prisma.note.findUnique.mockResolvedValueOnce(null);
    const res = await request(app).get('/notes/999');
    expect(res.statusCode).toBe(404);
  });
});