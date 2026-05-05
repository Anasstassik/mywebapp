const express = require('express');
const fs = require('fs');
const { PrismaClient } = require('@prisma/client');

const configPath = fs.existsSync('/etc/mywebapp/config.json') ? '/etc/mywebapp/config.json' : './config.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

const prisma = new PrismaClient();

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/health/alive', (req, res) => {
    res.status(200).send('OK');
});

app.get('/health/ready', async (req, res) => {
    try {
        await prisma.$queryRaw`SELECT 1`;
        res.status(200).send('OK');
    } catch (error) {
        res.status(500).send('Database connection failed');
    }
});

app.get('/', (req, res) => {
    const accepts = req.accepts('html');
    if (accepts) {
        res.send(`
            <!DOCTYPE html>
            <html>
            <head><title>API Endpoints</title></head>
            <body>
                <ul>
                    <li>GET /notes</li>
                    <li>POST /notes</li>
                    <li>GET /notes/&lt;id&gt;</li>
                </ul>
            </body>
            </html>
        `);
    } else {
        res.status(406).send('Not Acceptable');
    }
});

app.get('/notes', async (req, res) => {
    const notes = await prisma.note.findMany({
        select: { id: true, title: true }
    });
    
    if (req.accepts('html')) {
        let html = '<table border="1"><tr><th>ID</th><th>Title</th></tr>';
        notes.forEach(n => {
            html += `<tr><td>${n.id}</td><td>${n.title}</td></tr>`;
        });
        html += '</table>';
        res.send(html);
    } else if (req.accepts('json')) {
        res.json(notes);
    } else {
        res.status(406).send('Not Acceptable');
    }
});

app.post('/notes', async (req, res) => {
    const { title, content } = req.body;
    
    if (!title || !content) {
        return res.status(400).send('Title and content required');
    }

    const note = await prisma.note.create({
        data: { title, content }
    });
    
    if (req.accepts('html')) {
        res.redirect(`/notes/${note.id}`);
    } else if (req.accepts('json')) {
        res.status(201).json(note);
    } else {
        res.status(406).send('Not Acceptable');
    }
});

app.get('/notes/:id', async (req, res) => {
    const id = parseInt(req.params.id);
    const note = await prisma.note.findUnique({
        where: { id }
    });
    
    if (!note) return res.status(404).send('Not found');

    if (req.accepts('html')) {
        let html = '<table border="1"><tr><th>ID</th><th>Title</th><th>Created At</th><th>Content</th></tr>';
        html += `<tr><td>${note.id}</td><td>${note.title}</td><td>${note.created_at}</td><td>${note.content}</td></tr></table>`;
        res.send(html);
    } else if (req.accepts('json')) {
        res.json(note);
    } else {
        res.status(406).send('Not Acceptable');
    }
});

const port = process.env.PORT || config.port || 5000;
app.listen(port, () => {
    console.log(`MyWebApp is running on port ${port}`);
});