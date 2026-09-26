const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const path = require('path');

const app = express();

// Proxy API requests to backend
app.use('/api', createProxyMiddleware({ 
    target: 'https://easy-claim-frontend.pages.dev', 
    changeOrigin: true 
}));

// Serve static files from Flutter web build
app.use(express.static(path.join(__dirname, 'build/web')));

// Handle client-side routing by serving index.html for unknown routes
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'build/web/index.html'));
});

const PORT = 8081;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server listening on port ${PORT}`);
});
