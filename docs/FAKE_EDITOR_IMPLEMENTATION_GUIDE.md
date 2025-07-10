# Fast Track Editor Integration - Complete Implementation Guide

**Version**: 2.0  
**Date**: 09/07/2025  
**Audience**: Procurement platform developers integrating with Fast Track

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [OAuth2 Integration Flow](#oauth2-integration-flow)
4. [Implementation Options](#implementation-options)
5. [Node.js/Express Implementation](#nodejs-express-implementation)
6. [Rails Implementation](#rails-implementation)
7. [Frontend Integration](#frontend-integration)
8. [Redirect Flow Communication](#redirect-flow-communication)
9. [Security Considerations](#security-considerations)
10. [Testing & Debugging](#testing--debugging)
11. [Production Deployment](#production-deployment)
12. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Integration Flow Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Procurement   │    │   Fast Track    │    │   Procurement   │
│   Platform      │    │    System       │    │   Officer       │
│   (Your App)    │    │                 │    │   (End User)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │ 1. OAuth Authorization │                       │
         ├──────────────────────→│                       │
         │                       │                       │
         │ 2. Authorization Code  │                       │
         │←──────────────────────┤                       │
         │                       │                       │
         │ 3. Exchange for Token  │                       │
         ├──────────────────────→│                       │
         │                       │                       │
         │ 4. Access Token       │                       │
         │←──────────────────────┤                       │
         │                       │                       │
         │ 5. Redirect to Fast    │ 6. Configure Market  │
         │    Track with callback │ in full browser      │
         ├──────────────────────→├──────────────────────→│
         │                       │                       │
         │ 7. Callback redirect   │ 8. Market Configured  │
         │    with Fast Track ID  │←──────────────────────┤
         │←──────────────────────┤                       │
         │                       │                       │
         │ 9. Store Fast Track ID │                       │
         │   & Show confirmation  │                       │
         └─────────────────────────────────────────────────
```

### Key Components

1. **OAuth2 Client**: Handles authentication with Fast Track
2. **Redirect Manager**: Manages navigation to/from Fast Track
3. **Callback Handler**: Processes Fast Track redirect returns
4. **State Manager**: Maintains integration state and Fast Track IDs
5. **UI Components**: User interface for triggering Fast Track integration

---

## Prerequisites

### Fast Track Configuration

Before implementing your editor app, you need:

1. **Editor Registration**: Contact Fast Track admin to register your platform
2. **OAuth Credentials**: Obtain `client_id` and `client_secret`
3. **Callback URL**: Configure your callback endpoint
4. **Scopes**: Ensure you have `market_config` scope access

### Development Environment

- **Fast Track Instance**: Running at `http://localhost:3000`
- **Your Editor App**: Will run at `http://localhost:4000`
- **HTTPS**: Required for production (OAuth2 requirement)

### Test Credentials

For development, use these pre-configured credentials:

```
Client ID: f6b3c060e804cc030a16d3870178c2d5
Client Secret: e8a8fd976e241432d2a8325bcf456b386121cec2c16dad40eb27e9d618e90612
Callback URL: http://localhost:4000/auth/fasttrack/callback
Fast Track Base URL: http://localhost:3000
```

---

## OAuth2 Integration Flow

### Step 1: Authorization Request

Redirect user to Fast Track authorization endpoint:

```
GET http://localhost:3000/oauth/authorize?
  client_id=f6b3c060e804cc030a16d3870178c2d5&
  redirect_uri=http://localhost:4000/auth/fasttrack/callback&
  response_type=code&
  scope=market_config&
  state=random_csrf_token
```

### Step 2: Authorization Response

Fast Track redirects back with authorization code:

```
GET http://localhost:4000/auth/fasttrack/callback?
  code=authorization_code_here&
  state=random_csrf_token
```

### Step 3: Token Exchange

Exchange authorization code for access token:

```http
POST http://localhost:3000/oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "client_id": "f6b3c060e804cc030a16d3870178c2d5",
  "client_secret": "e8a8fd976e241432d2a8325bcf456b386121cec2c16dad40eb27e9d618e90612",
  "code": "authorization_code_here",
  "redirect_uri": "http://localhost:4000/auth/fasttrack/callback"
}
```

### Step 4: Token Response

Fast Track returns access token:

```json
{
  "access_token": "access_token_here",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "market_config",
  "created_at": 1625648400
}
```

---

## Implementation Options

### Technology Stack Choices

| Stack | Pros | Cons | Complexity |
|-------|------|------|------------|
| **Node.js + Express** | Simple, fast development | Single-threaded limitations | Low |
| **Rails** | Full-featured, convention over configuration | Heavier, learning curve | Medium |
| **Python + Django/Flask** | Clean syntax, good libraries | Performance considerations | Medium |
| **PHP + Laravel** | Wide hosting support, mature ecosystem | Legacy perception | Low |
| **ASP.NET Core** | Enterprise-ready, strong typing | Microsoft ecosystem dependency | High |

We'll provide detailed implementations for the two most common scenarios.

---

## Node.js/Express Implementation

### Project Setup

```bash
# Create new project
mkdir fasttrack-editor-demo
cd fasttrack-editor-demo
npm init -y

# Install dependencies
npm install express dotenv axios uuid express-session cors helmet
npm install --save-dev nodemon

# Create project structure
mkdir public views routes
touch app.js .env
```

### Environment Configuration

Create `.env` file:

```env
# Fast Track Configuration
FASTTRACK_BASE_URL=http://localhost:3000
FASTTRACK_CLIENT_ID=f6b3c060e804cc030a16d3870178c2d5
FASTTRACK_CLIENT_SECRET=e8a8fd976e241432d2a8325bcf456b386121cec2c16dad40eb27e9d618e90612
FASTTRACK_CALLBACK_URL=http://localhost:4000/auth/fasttrack/callback

# App Configuration
PORT=4000
SESSION_SECRET=your_super_secret_session_key
NODE_ENV=development
```

### Main Application File

Create `app.js`:

```javascript
const express = require('express');
const session = require('express-session');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const marketRoutes = require('./routes/markets');

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      connectSrc: ["'self'", process.env.FASTTRACK_BASE_URL]
    }
  }
}));

// CORS configuration
app.use(cors({
  origin: [process.env.FASTTRACK_BASE_URL, 'http://localhost:4000'],
  credentials: true
}));

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

// Static files
app.use(express.static('public'));

// View engine
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

// Routes
app.use('/auth', authRoutes);
app.use('/markets', marketRoutes);

// Home page
app.get('/', (req, res) => {
  res.render('index', {
    user: req.session.user,
    fastTrackToken: req.session.fastTrackToken
  });
});

// Start server
const port = process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`🚀 Editor Demo App running on http://localhost:${port}`);
  console.log(`📋 Fast Track URL: ${process.env.FASTTRACK_BASE_URL}`);
});

module.exports = app;
```

### OAuth Authentication Routes

Create `routes/auth.js`:

```javascript
const express = require('express');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();

// Initiate Fast Track OAuth flow
router.get('/fasttrack', (req, res) => {
  const state = uuidv4();
  req.session.oauthState = state;
  
  const authUrl = new URL('/oauth/authorize', process.env.FASTTRACK_BASE_URL);
  authUrl.searchParams.append('client_id', process.env.FASTTRACK_CLIENT_ID);
  authUrl.searchParams.append('redirect_uri', process.env.FASTTRACK_CALLBACK_URL);
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('scope', 'market_config');
  authUrl.searchParams.append('state', state);
  
  res.redirect(authUrl.toString());
});

// Handle Fast Track OAuth callback
router.get('/fasttrack/callback', async (req, res) => {
  const { code, state, error } = req.query;
  
  try {
    // Validate state parameter (CSRF protection)
    if (!state || state !== req.session.oauthState) {
      throw new Error('Invalid state parameter');
    }
    
    // Clear state from session
    delete req.session.oauthState;
    
    // Handle OAuth errors
    if (error) {
      throw new Error(`OAuth error: ${error}`);
    }
    
    if (!code) {
      throw new Error('No authorization code received');
    }
    
    // Exchange code for token
    const tokenResponse = await axios.post(
      `${process.env.FASTTRACK_BASE_URL}/oauth/token`,
      {
        grant_type: 'authorization_code',
        client_id: process.env.FASTTRACK_CLIENT_ID,
        client_secret: process.env.FASTTRACK_CLIENT_SECRET,
        code: code,
        redirect_uri: process.env.FASTTRACK_CALLBACK_URL
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }
      }
    );
    
    const tokenData = tokenResponse.data;
    
    // Store token in session
    req.session.fastTrackToken = {
      access_token: tokenData.access_token,
      token_type: tokenData.token_type,
      expires_in: tokenData.expires_in,
      expires_at: Date.now() + (tokenData.expires_in * 1000),
      scope: tokenData.scope
    };
    
    // Store user info (mock user for demo)
    req.session.user = {
      id: 'demo_user',
      name: 'Demo Procurement Officer',
      email: 'demo@procurement-platform.com'
    };
    
    res.redirect('/?auth=success');
    
  } catch (error) {
    console.error('OAuth callback error:', error.message);
    res.redirect('/?auth=error&message=' + encodeURIComponent(error.message));
  }
});

// Logout
router.post('/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      console.error('Session destruction error:', err);
    }
    res.redirect('/');
  });
});

// Check if token is valid
router.get('/status', (req, res) => {
  const token = req.session.fastTrackToken;
  
  if (!token) {
    return res.json({ authenticated: false });
  }
  
  if (Date.now() > token.expires_at) {
    delete req.session.fastTrackToken;
    return res.json({ authenticated: false, reason: 'token_expired' });
  }
  
  res.json({
    authenticated: true,
    user: req.session.user,
    token: {
      scope: token.scope,
      expires_at: token.expires_at
    }
  });
});

module.exports = router;
```

### Market Configuration Routes

Create `routes/markets.js`:

```javascript
const express = require('express');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();

// Mock database for storing markets
const markets = new Map();

// Middleware to check authentication
const requireAuth = (req, res, next) => {
  const token = req.session.fastTrackToken;
  
  if (!token || Date.now() > token.expires_at) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  next();
};

// List all markets
router.get('/', requireAuth, (req, res) => {
  const userMarkets = Array.from(markets.values()).map(market => ({
    id: market.id,
    title: market.title,
    fastTrackId: market.fastTrackId,
    status: market.status,
    createdAt: market.createdAt
  }));
  
  res.render('markets/index', { markets: userMarkets });
});

// Create new market form
router.get('/new', requireAuth, (req, res) => {
  res.render('markets/new');
});

// Initiate Fast Track configuration
router.post('/configure', requireAuth, (req, res) => {
  const { title, description } = req.body;
  
  if (!title) {
    return res.status(400).json({ error: 'Market title is required' });
  }
  
  // Create market record
  const marketId = uuidv4();
  const market = {
    id: marketId,
    title,
    description,
    status: 'configuring',
    createdAt: new Date().toISOString(),
    fastTrackId: null
  };
  
  markets.set(marketId, market);
  
  // Generate Fast Track configuration URL with callback
  const fastTrackUrl = new URL('/buyer/market_configurations/new', process.env.FASTTRACK_BASE_URL);
  fastTrackUrl.searchParams.append('access_token', req.session.fastTrackToken.access_token);
  
  // Add callback URL with state for security
  const callbackState = uuidv4();
  req.session.configurationStates = req.session.configurationStates || {};
  req.session.configurationStates[callbackState] = marketId;
  
  const callbackUrl = new URL('/markets/fasttrack-callback', `http://localhost:${process.env.PORT || 4000}`);
  callbackUrl.searchParams.append('state', callbackState);
  
  fastTrackUrl.searchParams.append('callback_url', callbackUrl.toString());
  
  res.json({
    success: true,
    marketId,
    fastTrackUrl: fastTrackUrl.toString()
  });
});

// Handle Fast Track completion callback
router.get('/fasttrack-callback', requireAuth, (req, res) => {
  const { fast_track_id, state, market_title, deadline, documents_count } = req.query;
  
  try {
    // Validate state parameter
    if (!state || !req.session.configurationStates || !req.session.configurationStates[state]) {
      throw new Error('Invalid state parameter');
    }
    
    const marketId = req.session.configurationStates[state];
    delete req.session.configurationStates[state];
    
    const market = markets.get(marketId);
    if (!market) {
      throw new Error('Market not found');
    }
    
    // Update market with Fast Track information
    market.fastTrackId = fast_track_id;
    market.status = 'configured';
    market.fastTrackData = {
      marketTitle: market_title,
      deadline: deadline,
      documentsCount: documents_count,
      configuredAt: new Date().toISOString()
    };
    
    markets.set(marketId, market);
    
    // Redirect to success page
    res.redirect(`/markets/${marketId}?configured=true`);
    
  } catch (error) {
    console.error('Fast Track callback error:', error.message);
    res.redirect('/markets?error=' + encodeURIComponent(error.message));
  }
});

// Get market details
router.get('/:id', requireAuth, (req, res) => {
  const market = markets.get(req.params.id);
  
  if (!market) {
    return res.status(404).render('404');
  }
  
  res.render('markets/show', { 
    market,
    configured: req.query.configured === 'true'
  });
});

module.exports = router;
```

### Frontend Views

Create `views/index.ejs`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Procurement Platform - Fast Track Integration Demo</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>🏢 Procurement Platform</h1>
            <p class="subtitle">Fast Track Integration Demo</p>
        </header>

        <% if (user) { %>
            <!-- Authenticated User Interface -->
            <div class="user-info">
                <h2>Welcome, <%= user.name %>!</h2>
                <p>You are authenticated with Fast Track</p>
                
                <div class="actions">
                    <a href="/markets" class="btn btn-primary">View Markets</a>
                    <a href="/markets/new" class="btn btn-secondary">Create New Market</a>
                    
                    <form action="/auth/logout" method="POST" style="display: inline;">
                        <button type="submit" class="btn btn-outline">Logout</button>
                    </form>
                </div>
            </div>

            <!-- Fast Track Integration Status -->
            <div class="integration-status">
                <h3>Fast Track Status</h3>
                <div id="integration-info">
                    <p>✅ Connected to Fast Track</p>
                    <p>🔐 OAuth Token Valid</p>
                    <p>📋 Scope: market_config</p>
                </div>
            </div>
        <% } else { %>
            <!-- Guest Interface -->
            <div class="welcome">
                <h2>Welcome to the Procurement Platform</h2>
                <p>This demo shows how to integrate with Fast Track for simplified public procurement.</p>
                
                <div class="features">
                    <div class="feature">
                        <h3>🚀 Fast Track Integration</h3>
                        <p>Configure markets quickly with our streamlined Fast Track process</p>
                    </div>
                    
                    <div class="feature">
                        <h3>📋 Document Management</h3>
                        <p>Automatic document requirements based on market type</p>
                    </div>
                    
                    <div class="feature">
                        <h3>🔐 Secure OAuth</h3>
                        <p>Industry-standard OAuth2 authentication with Fast Track</p>
                    </div>
                </div>
                
                <a href="/auth/fasttrack" class="btn btn-primary btn-large">
                    Connect with Fast Track
                </a>
            </div>
        <% } %>

        <!-- Authentication Status Messages -->
        <script>
            // Handle URL parameters for auth status
            const urlParams = new URLSearchParams(window.location.search);
            const authStatus = urlParams.get('auth');
            const message = urlParams.get('message');
            
            if (authStatus === 'success') {
                showNotification('Successfully connected to Fast Track!', 'success');
            } else if (authStatus === 'error') {
                showNotification(`Authentication failed: ${message || 'Unknown error'}`, 'error');
            }
            
            function showNotification(message, type) {
                const notification = document.createElement('div');
                notification.className = `notification ${type}`;
                notification.textContent = message;
                document.body.insertBefore(notification, document.body.firstChild);
                
                setTimeout(() => {
                    notification.remove();
                }, 5000);
            }
        </script>
    </div>
</body>
</html>
```

Create `views/markets/new.ejs`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Create New Market - Procurement Platform</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>Create New Market</h1>
            <a href="/markets" class="btn btn-outline">← Back to Markets</a>
        </header>

        <div class="market-form">
            <form id="market-form">
                <div class="form-group">
                    <label for="title">Market Title *</label>
                    <input type="text" id="title" name="title" required 
                           placeholder="e.g., Office Supplies Procurement 2025">
                </div>

                <div class="form-group">
                    <label for="description">Description</label>
                    <textarea id="description" name="description" rows="4"
                              placeholder="Brief description of the procurement requirements..."></textarea>
                </div>

                <div class="form-actions">
                    <button type="submit" class="btn btn-primary">
                        Configure with Fast Track
                    </button>
                </div>
            </form>
        </div>
    </div>

    <script>
        document.getElementById('market-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const formData = new FormData(e.target);
            const data = Object.fromEntries(formData);
            
            try {
                const response = await fetch('/markets/configure', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data)
                });
                
                const result = await response.json();
                
                if (result.success) {
                    // Redirect to Fast Track for configuration
                    window.location.href = result.fastTrackUrl;
                } else {
                    alert('Error: ' + result.error);
                }
            } catch (error) {
                alert('Network error: ' + error.message);
            }
        });
    </script>
</body>
</html>
```

Create `views/markets/show.ejs`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Market Details - Procurement Platform</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>Market Details</h1>
            <a href="/markets" class="btn btn-outline">← Back to Markets</a>
        </header>

        <% if (configured) { %>
            <div class="success-message">
                <h2>✅ Market Successfully Configured!</h2>
                <p>Your market has been configured with Fast Track and is ready for candidates.</p>
            </div>
        <% } %>

        <div class="market-details">
            <div class="market-info">
                <h2><%= market.title %></h2>
                <p><%= market.description %></p>
                
                <div class="market-meta">
                    <p><strong>Status:</strong> <%= market.status %></p>
                    <p><strong>Created:</strong> <%= new Date(market.createdAt).toLocaleDateString() %></p>
                    
                    <% if (market.fastTrackId) { %>
                        <p><strong>Fast Track ID:</strong> 
                            <code><%= market.fastTrackId %></code>
                            <button onclick="copyToClipboard('<%= market.fastTrackId %>')">Copy</button>
                        </p>
                    <% } %>
                </div>
            </div>

            <% if (market.fastTrackData) { %>
                <div class="fasttrack-data">
                    <h3>Fast Track Configuration</h3>
                    <p><strong>Market Title:</strong> <%= market.fastTrackData.marketTitle %></p>
                    <p><strong>Deadline:</strong> <%= market.fastTrackData.deadline %></p>
                    <p><strong>Documents Count:</strong> <%= market.fastTrackData.documentsCount %></p>
                    <p><strong>Configured At:</strong> <%= new Date(market.fastTrackData.configuredAt).toLocaleString() %></p>
                </div>
            <% } %>
        </div>

        <script>
            function copyToClipboard(text) {
                navigator.clipboard.writeText(text).then(() => {
                    alert('Fast Track ID copied to clipboard!');
                });
            }
        </script>
    </div>
</body>
</html>
```

### Styling

Create `public/css/style.css`:

```css
/* Fast Track Editor Demo Styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f5f7fa;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

/* Header */
.header {
    text-align: center;
    margin-bottom: 3rem;
    padding-bottom: 2rem;
    border-bottom: 1px solid #e1e8ed;
}

.header h1 {
    font-size: 2.5rem;
    color: #1a202c;
    margin-bottom: 0.5rem;
}

.subtitle {
    font-size: 1.2rem;
    color: #718096;
}

/* Buttons */
.btn {
    display: inline-block;
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 0.5rem;
    text-decoration: none;
    font-weight: 600;
    text-align: center;
    cursor: pointer;
    transition: all 0.2s;
    font-size: 1rem;
}

.btn-primary {
    background-color: #3182ce;
    color: white;
}

.btn-primary:hover {
    background-color: #2c5aa0;
}

.btn-secondary {
    background-color: #718096;
    color: white;
}

.btn-secondary:hover {
    background-color: #4a5568;
}

.btn-outline {
    background-color: transparent;
    color: #3182ce;
    border: 2px solid #3182ce;
}

.btn-outline:hover {
    background-color: #3182ce;
    color: white;
}

.btn-large {
    padding: 1rem 2rem;
    font-size: 1.2rem;
}

/* User Info */
.user-info {
    background: white;
    padding: 2rem;
    border-radius: 0.75rem;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    margin-bottom: 2rem;
}

.user-info h2 {
    color: #1a202c;
    margin-bottom: 0.5rem;
}

.actions {
    margin-top: 1.5rem;
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
}

/* Integration Status */
.integration-status {
    background: #f0fff4;
    border: 1px solid #9ae6b4;
    border-radius: 0.75rem;
    padding: 1.5rem;
    margin-bottom: 2rem;
}

.integration-status h3 {
    color: #276749;
    margin-bottom: 1rem;
}

.integration-status p {
    color: #2f855a;
    margin-bottom: 0.5rem;
}

/* Welcome Section */
.welcome {
    text-align: center;
    background: white;
    padding: 3rem;
    border-radius: 0.75rem;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

.welcome h2 {
    color: #1a202c;
    margin-bottom: 1rem;
}

.features {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 2rem;
    margin: 2rem 0 3rem 0;
}

.feature {
    padding: 1.5rem;
    background: #f7fafc;
    border-radius: 0.5rem;
    border: 1px solid #e2e8f0;
}

.feature h3 {
    color: #2d3748;
    margin-bottom: 0.5rem;
}

.feature p {
    color: #4a5568;
    font-size: 0.9rem;
}

/* Form Styles */
.market-form {
    background: white;
    padding: 2rem;
    border-radius: 0.75rem;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    max-width: 600px;
    margin: 0 auto;
}

.form-group {
    margin-bottom: 1.5rem;
}

.form-group label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 600;
    color: #2d3748;
}

.form-group input,
.form-group textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #cbd5e0;
    border-radius: 0.375rem;
    font-size: 1rem;
    transition: border-color 0.2s;
}

.form-group input:focus,
.form-group textarea:focus {
    outline: none;
    border-color: #3182ce;
    box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.1);
}

.form-actions {
    margin-top: 2rem;
    text-align: center;
}

/* Market Details */
.market-details {
    background: white;
    padding: 2rem;
    border-radius: 0.75rem;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

.market-info h2 {
    color: #1a202c;
    margin-bottom: 1rem;
}

.market-meta {
    margin-top: 1.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid #e2e8f0;
}

.market-meta p {
    margin-bottom: 0.5rem;
}

.fasttrack-data {
    margin-top: 2rem;
    padding-top: 2rem;
    border-top: 1px solid #e2e8f0;
}

.fasttrack-data h3 {
    color: #276749;
    margin-bottom: 1rem;
}

/* Success Message */
.success-message {
    background: #f0fff4;
    border: 1px solid #9ae6b4;
    border-radius: 0.75rem;
    padding: 1.5rem;
    margin-bottom: 2rem;
    text-align: center;
}

.success-message h2 {
    color: #276749;
    margin-bottom: 0.5rem;
}

.success-message p {
    color: #2f855a;
}

/* Notifications */
.notification {
    position: fixed;
    top: 20px;
    right: 20px;
    padding: 1rem 1.5rem;
    border-radius: 0.5rem;
    color: white;
    font-weight: 600;
    max-width: 400px;
    z-index: 1001;
    animation: slideIn 0.3s ease-out;
}

.notification.success {
    background-color: #38a169;
}

.notification.error {
    background-color: #e53e3e;
}

@keyframes slideIn {
    from {
        transform: translateX(100%);
        opacity: 0;
    }
    to {
        transform: translateX(0);
        opacity: 1;
    }
}

/* Responsive Design */
@media (max-width: 768px) {
    .container {
        padding: 1rem;
    }
    
    .header h1 {
        font-size: 2rem;
    }
    
    .actions {
        flex-direction: column;
    }
    
    .btn {
        text-align: center;
    }
    
    .features {
        grid-template-columns: 1fr;
    }
}
```

### Package.json Scripts

Update `package.json`:

```json
{
  "name": "fasttrack-editor-demo",
  "version": "2.0.0",
  "description": "Demo editor app integrating with Fast Track using redirect flow",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "dotenv": "^16.3.1",
    "axios": "^1.5.0",
    "uuid": "^9.0.0",
    "express-session": "^1.17.3",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "ejs": "^3.1.9"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

---

## Rails Implementation

### Project Setup

```bash
# Create new Rails app
rails new fasttrack_editor_demo --skip-test --database=postgresql
cd fasttrack_editor_demo

# Add gems to Gemfile
echo '
# OAuth2 client
gem "oauth2"

# HTTP client
gem "faraday"

# Environment variables
gem "dotenv-rails"

# CORS handling
gem "rack-cors"
' >> Gemfile

bundle install
```

### Environment Configuration

Create `.env`:

```env
FASTTRACK_BASE_URL=http://localhost:3000
FASTTRACK_CLIENT_ID=f6b3c060e804cc030a16d3870178c2d5
FASTTRACK_CLIENT_SECRET=e8a8fd976e241432d2a8325bcf456b386121cec2c16dad40eb27e9d618e90612
FASTTRACK_CALLBACK_URL=http://localhost:4000/auth/fasttrack/callback
```

### OAuth Service

Create `app/services/fast_track_oauth_service.rb`:

```ruby
# frozen_string_literal: true

require 'cgi'

class FastTrackOauthService
  include Rails.application.routes.url_helpers

  attr_reader :client

  def initialize
    @client = OAuth2::Client.new(
      ENV['FASTTRACK_CLIENT_ID'],
      ENV['FASTTRACK_CLIENT_SECRET'],
      site: ENV['FASTTRACK_BASE_URL'],
      authorize_url: '/oauth/authorize',
      token_url: '/oauth/token',
      token_method: :post,
      connection_opts: {
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      }
    )
  end

  def authorization_url(state)
    client.auth_code.authorize_url(
      redirect_uri: ENV['FASTTRACK_CALLBACK_URL'],
      scope: 'market_config',
      state: state
    )
  end

  def exchange_code_for_token(code)
    Rails.logger.info "Exchanging code for token: #{code}"
    Rails.logger.info "Redirect URI: #{ENV['FASTTRACK_CALLBACK_URL']}"
    
    token = client.auth_code.get_token(
      code,
      redirect_uri: ENV['FASTTRACK_CALLBACK_URL']
    )
    
    Rails.logger.info "Token obtained successfully: #{token.token}"
    token
  rescue OAuth2::Error => e
    Rails.logger.error "OAuth token exchange failed: #{e.message}"
    raise StandardError, "Authentication failed: #{e.description}"
  rescue => e
    Rails.logger.error "Unexpected error during token exchange: #{e.message}"
    raise StandardError, "Authentication failed: #{e.message}"
  end

  def configuration_url(access_token, callback_url)
    url = "#{ENV['FASTTRACK_BASE_URL']}/buyer/market_configurations/new"
    params = {
      access_token: access_token,
      callback_url: callback_url
    }
    
    "#{url}?#{URI.encode_www_form(params)}"
  end
end
```

### Controllers

Create `app/controllers/auth_controller.rb`:

```ruby
# frozen_string_literal: true

class AuthController < ApplicationController
  before_action :initialize_oauth_service

  def fasttrack
    state = SecureRandom.hex(16)
    session[:oauth_state] = state
    
    authorization_url = @oauth_service.authorization_url(state)
    redirect_to authorization_url, allow_other_host: true
  end

  def fasttrack_callback
    handle_oauth_callback
  rescue StandardError => e
    Rails.logger.error "OAuth callback error: #{e.message}"
    redirect_to root_path, alert: "Authentication failed: #{e.message}"
  end

  def logout
    session.clear
    redirect_to root_path, notice: 'Successfully logged out'
  end

  def status
    if authenticated?
      render json: {
        authenticated: true,
        user: session[:user],
        token: session[:fast_track_token]&.except('access_token')
      }
    else
      render json: { authenticated: false }
    end
  end

  private

  def initialize_oauth_service
    @oauth_service = FastTrackOauthService.new
  end

  def handle_oauth_callback
    validate_oauth_state!
    
    code = params[:code]
    raise StandardError, 'No authorization code received' unless code

    token = @oauth_service.exchange_code_for_token(code)
    
    store_authentication_data(token)
    
    redirect_to root_path, notice: 'Successfully connected to Fast Track!'
  end

  def validate_oauth_state!
    state = params[:state]
    stored_state = session.delete(:oauth_state)
    
    raise StandardError, 'Invalid state parameter' if state != stored_state
    raise StandardError, 'OAuth error' if params[:error]
  end

  def store_authentication_data(token)
    session[:fast_track_token] = {
      'access_token' => token.token,
      'token_type' => 'Bearer',
      'expires_in' => token.expires_in,
      'expires_at' => token.expires_at,
      'scope' => 'market_config'
    }

    session[:user] = {
      'id' => 'demo_user',
      'name' => 'Demo Procurement Officer',
      'email' => 'demo@procurement-platform.com'
    }
  end

  def authenticated?
    token = session[:fast_track_token]
    return false unless token
    return false if token['expires_at'] && Time.current.to_i > token['expires_at']
    
    true
  end
end
```

Create `app/controllers/markets_controller.rb`:

```ruby
# frozen_string_literal: true

class MarketsController < ApplicationController
  before_action :require_authentication
  before_action :initialize_oauth_service
  before_action :set_market, only: [:show]

  def index
    @markets = Market.all.order(created_at: :desc)
  end

  def new
    @market = Market.new
  end

  def show
    @configured = params[:configured] == 'true'
  end

  def configure
    market_params = params.require(:market).permit(:title, :description)
    
    @market = Market.create!(
      title: market_params[:title],
      description: market_params[:description],
      status: 'configuring'
    )

    # Generate callback URL with state
    callback_state = SecureRandom.hex(16)
    session[:configuration_states] ||= {}
    session[:configuration_states][callback_state] = @market.id
    
    callback_url = markets_fasttrack_callback_url(state: callback_state)
    
    fast_track_url = @oauth_service.configuration_url(
      session[:fast_track_token]['access_token'],
      callback_url
    )

    render json: {
      success: true,
      market_id: @market.id,
      fast_track_url: fast_track_url
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { 
      success: false, 
      error: e.record.errors.full_messages.join(', ') 
    }, status: :unprocessable_entity
  end

  def fasttrack_callback
    callback_params = params.permit(:fast_track_id, :state, :market_title, :deadline, :documents_count)
    
    # Validate state parameter
    state = callback_params[:state]
    unless state && session[:configuration_states] && session[:configuration_states][state]
      redirect_to markets_path, alert: 'Invalid callback state'
      return
    end
    
    market_id = session[:configuration_states][state]
    session[:configuration_states].delete(state)
    
    market = Market.find(market_id)
    
    market.update!(
      fast_track_id: callback_params[:fast_track_id],
      status: 'configured',
      fast_track_data: {
        market_title: callback_params[:market_title],
        deadline: callback_params[:deadline],
        documents_count: callback_params[:documents_count],
        configured_at: Time.current.iso8601
      }
    )

    redirect_to market_path(market, configured: true)
  rescue ActiveRecord::RecordNotFound
    redirect_to markets_path, alert: 'Market not found'
  end

  private

  def require_authentication
    token = session[:fast_track_token]
    
    unless token && (!token['expires_at'] || Time.current.to_i < token['expires_at'])
      redirect_to root_path, alert: 'Authentication required'
    end
  end

  def initialize_oauth_service
    @oauth_service = FastTrackOauthService.new
  end

  def set_market
    @market = Market.find(params[:id])
  end
end
```

### Market Model

Create `app/models/market.rb`:

```ruby
# frozen_string_literal: true

class Market < ApplicationRecord
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[configuring configured] }

  scope :configured, -> { where(status: 'configured') }
  scope :configuring, -> { where(status: 'configuring') }

  def configured?
    status == 'configured'
  end

  def fast_track_configured?
    fast_track_id.present?
  end
end
```

### Database Migration

Create migration:

```bash
rails generate migration CreateMarkets title:string description:text status:string fast_track_id:string fast_track_data:json
rails db:migrate
```

### Routes

Update `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  root 'home#index'

  # Authentication routes
  scope :auth do
    get 'fasttrack', to: 'auth#fasttrack'
    get 'fasttrack/callback', to: 'auth#fasttrack_callback'
    delete 'logout', to: 'auth#logout'
    get 'status', to: 'auth#status'
  end

  # Market routes
  resources :markets, only: [:index, :new, :show] do
    collection do
      post :configure
      get :fasttrack_callback
    end
  end
end
```

---

## Redirect Flow Communication

### Flow Sequence

The redirect flow eliminates the complexity of PostMessage communication:

1. **Configuration Initiation**: Editor creates market and redirects to Fast Track
2. **User Configuration**: User completes configuration in Fast Track
3. **Callback Redirect**: Fast Track redirects back to editor with results
4. **Processing**: Editor processes the callback and updates market status

### Key Benefits

- **Simpler Security**: No cross-domain messaging concerns
- **Better UX**: Full browser window for configuration
- **Easier Debugging**: Standard HTTP requests and responses
- **Mobile Friendly**: No iframe constraints

### State Management

Use cryptographically secure state parameters to prevent CSRF attacks:

```javascript
// Generate secure state
const state = require('crypto').randomBytes(16).toString('hex');

// Store in session
req.session.configurationStates = req.session.configurationStates || {};
req.session.configurationStates[state] = marketId;

// Validate on callback
if (!req.session.configurationStates[receivedState]) {
  throw new Error('Invalid state parameter');
}
```

---

## Security Considerations

### OAuth2 Security

#### State Parameter Validation

```javascript
// Generate cryptographically secure state
function generateState() {
  return require('crypto').randomBytes(16).toString('hex');
}

// Validate state on callback
function validateState(receivedState, sessionStates) {
  return sessionStates && sessionStates[receivedState];
}
```

#### Token Storage

```javascript
// Secure token storage in session
req.session.fastTrackToken = {
  access_token: token.access_token,
  expires_at: Date.now() + (token.expires_in * 1000),
  scope: token.scope
};

// Token validation
function isTokenValid(token) {
  return token && Date.now() < token.expires_at;
}
```

### Callback URL Security

#### URL Validation

```javascript
// Validate callback URLs against whitelist
const ALLOWED_CALLBACK_DOMAINS = [
  'localhost:4000',
  'your-platform.com'
];

function validateCallbackUrl(url) {
  const parsedUrl = new URL(url);
  return ALLOWED_CALLBACK_DOMAINS.includes(parsedUrl.host);
}
```

#### Parameter Sanitization

```javascript
// Sanitize callback parameters
function sanitizeCallbackParams(params) {
  const sanitized = {};
  
  // Only allow expected parameters
  const allowedParams = ['fast_track_id', 'state', 'market_title', 'deadline', 'documents_count'];
  
  allowedParams.forEach(param => {
    if (params[param]) {
      sanitized[param] = String(params[param]).trim();
    }
  });
  
  return sanitized;
}
```

---

## Testing & Debugging

### Manual Testing Checklist

#### OAuth Flow
- [ ] Authorization redirect works correctly
- [ ] Callback handles success case
- [ ] Callback handles error case (user denies)
- [ ] State parameter prevents CSRF
- [ ] Token exchange works
- [ ] Token expiration is handled

#### Fast Track Integration
- [ ] Redirect to Fast Track works
- [ ] Configuration completes successfully
- [ ] Callback URL receives correct parameters
- [ ] Market status updates properly
- [ ] Error handling works

#### UI/UX
- [ ] Loading states are shown
- [ ] Error messages are clear
- [ ] Success feedback is provided
- [ ] Responsive design works
- [ ] Mobile experience is good

### Debugging Tools

#### Enhanced Logging

```javascript
// Debug logging for OAuth flow
function logOAuthStep(step, data) {
  if (process.env.DEBUG_OAUTH) {
    console.log(`🔐 OAuth ${step}:`, {
      timestamp: new Date().toISOString(),
      data: data
    });
  }
}

// Usage
logOAuthStep('authorization_started', { state: state });
logOAuthStep('token_received', { scope: token.scope, expires_in: token.expires_in });
```

#### Integration Testing

```javascript
// Test redirect flow
async function testRedirectFlow() {
  console.log('🧪 Testing Fast Track Redirect Flow...');
  
  try {
    // Test 1: Check authentication
    const authResponse = await fetch('/auth/status');
    const authData = await authResponse.json();
    console.log('✅ Auth Status:', authData.authenticated ? 'Authenticated' : 'Not authenticated');
    
    if (!authData.authenticated) {
      console.log('⚠️ Need to authenticate first');
      return;
    }
    
    // Test 2: Create test market
    const marketResponse = await fetch('/markets/configure', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: 'Test Market Integration',
        description: 'Automated test market'
      })
    });
    
    const marketData = await marketResponse.json();
    console.log('✅ Market Creation:', marketData.success ? 'Success' : 'Failed');
    
    if (marketData.success) {
      console.log('📋 Market ID:', marketData.market_id);
      console.log('🔗 Fast Track URL:', marketData.fast_track_url);
      
      // Test 3: Validate callback URL
      const callbackUrl = new URL(marketData.fast_track_url);
      const callbackParam = callbackUrl.searchParams.get('callback_url');
      console.log('🔄 Callback URL:', callbackParam);
    }
    
  } catch (error) {
    console.error('❌ Test Failed:', error.message);
  }
}
```

---

## Production Deployment

### Environment Configuration

#### Production Environment Variables

```env
# Production Fast Track URL
FASTTRACK_BASE_URL=https://fasttrack.gouv.fr

# OAuth credentials (obtain from Fast Track admin)
FASTTRACK_CLIENT_ID=your_production_client_id
FASTTRACK_CLIENT_SECRET=your_production_client_secret
FASTTRACK_CALLBACK_URL=https://your-platform.com/auth/fasttrack/callback

# Security
SESSION_SECRET=your_secure_session_secret
NODE_ENV=production

# Database
DATABASE_URL=postgresql://user:password@host:port/database

# SSL/TLS
FORCE_HTTPS=true
```

### Security Hardening

#### Application Security

```javascript
// Production security middleware
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});

app.use(limiter);

// Security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      connectSrc: ["'self'", "https://fasttrack.gouv.fr"],
      imgSrc: ["'self'", "data:", "https:"],
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

---

## Troubleshooting

### Common Issues

#### 1. OAuth Authorization Fails

**Symptoms**: User gets redirected to Fast Track but sees error page.

**Solutions**:
- Verify client ID and secret with Fast Track admin
- Ensure callback URL exactly matches registered URL
- Check that your editor is authorized and active

#### 2. Token Exchange Fails

**Symptoms**: Callback receives code but token exchange returns error.

**Solutions**:
- Check authorization code hasn't expired (5 minutes)
- Verify client secret is correct
- Ensure callback URL matches exactly

#### 3. Callback Not Received

**Symptoms**: Fast Track configuration completes but callback doesn't arrive.

**Solutions**:
- Verify callback URL is accessible
- Check for network/firewall issues
- Ensure callback endpoint is implemented correctly

#### 4. State Parameter Validation Fails

**Symptoms**: Callback returns "Invalid state parameter" error.

**Solutions**:
- Ensure state generation is cryptographically secure
- Verify state storage in session
- Check state parameter isn't modified in transit

---

## Conclusion

This redirect-based integration provides a simpler, more secure, and user-friendly approach to Fast Track integration. The elimination of iframe complexity results in better mobile experience, easier debugging, and more maintainable code.

Key advantages:
- **Simplified Architecture**: No PostMessage complexity
- **Better Security**: Standard OAuth2 flow with state validation
- **Improved UX**: Full browser window experience
- **Mobile Friendly**: No iframe constraints
- **Easier Debugging**: Standard HTTP requests and responses

Follow this guide to implement a robust, production-ready editor integration with Fast Track using the redirect flow pattern.