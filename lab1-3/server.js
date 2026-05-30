const fs = require('fs');
const { app } = require('./app');

const configPath = fs.existsSync('/etc/mywebapp/config.json') ? '/etc/mywebapp/config.json' : './config.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

const port = process.env.PORT || config.port || 5000;

app.listen(port, () => {
    console.log(`MyWebApp is running on port ${port}`);
});