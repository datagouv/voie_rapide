# Fast Track Editor Integration - Complete Implementation Guide

**Version**: 1.0  
**Date**: 07/07/2025  
**Audience**: Procurement platform developers integrating with Fast Track

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [OAuth2 Integration Flow](#oauth2-integration-flow)
4. [Implementation Options](#implementation-options)
5. [Node.js/Express Implementation](#nodejs-express-implementation)
6. [Rails Implementation](#rails-implementation)
7. [Frontend Integration](#frontend-integration)
8. [PostMessage Communication](#postmessage-communication)
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
         │ 5. Open iFrame/Popup   │ 6. Configure Market  │
         ├──────────────────────→├──────────────────────→│
         │                       │                       │
         │ 7. PostMessage with    │ 8. Market Configured  │
         │    Fast Track ID       │←──────────────────────┤
         │←──────────────────────┤                       │
         │                       │                       │
         │ 9. Store Fast Track ID │                       │
         │   & Close Integration  │                       │
         └─────────────────────────────────────────────────
```

### Key Components

1. **OAuth2 Client**: Handles authentication with Fast Track
2. **iFrame/Popup Manager**: Manages embedded Fast Track interface
3. **Message Handler**: Processes PostMessage communications
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
      frameSrc: ["'self'", process.env.FASTTRACK_BASE_URL],
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
  
  // Generate Fast Track configuration URL
  const fastTrackUrl = new URL('/buyer/market_configurations/new', process.env.FASTTRACK_BASE_URL);
  fastTrackUrl.searchParams.append('access_token', req.session.fastTrackToken.access_token);
  
  res.json({
    success: true,
    marketId,
    fastTrackUrl: fastTrackUrl.toString()
  });
});

// Handle Fast Track completion callback
router.post('/fasttrack-complete', requireAuth, (req, res) => {
  const { marketId, fastTrackId, marketTitle, deadline, documentsCount } = req.body;
  
  const market = markets.get(marketId);
  if (!market) {
    return res.status(404).json({ error: 'Market not found' });
  }
  
  // Update market with Fast Track information
  market.fastTrackId = fastTrackId;
  market.status = 'configured';
  market.fastTrackData = {
    marketTitle,
    deadline,
    documentsCount,
    configuredAt: new Date().toISOString()
  };
  
  markets.set(marketId, market);
  
  res.json({ success: true });
});

// Get market details
router.get('/:id', requireAuth, (req, res) => {
  const market = markets.get(req.params.id);
  
  if (!market) {
    return res.status(404).render('404');
  }
  
  res.render('markets/show', { market });
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

        <!-- Fast Track Integration Modal -->
        <div id="fasttrack-modal" class="modal" style="display: none;">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Fast Track Configuration</h3>
                    <span class="close" onclick="closeFastTrackModal()">&times;</span>
                </div>
                <div class="modal-body">
                    <p>Configuring your market with Fast Track...</p>
                    <iframe id="fasttrack-iframe" src="" width="100%" height="600"></iframe>
                </div>
            </div>
        </div>
    </div>

    <script src="/js/fasttrack-integration.js"></script>
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
                    openFastTrackConfiguration(result.marketId, result.fastTrackUrl);
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

### Fast Track Integration JavaScript

Create `public/js/fasttrack-integration.js`:

```javascript
// Fast Track Integration Manager
class FastTrackIntegration {
    constructor() {
        this.currentMarketId = null;
        this.modal = null;
        this.iframe = null;
        
        // Listen for PostMessage from Fast Track
        window.addEventListener('message', this.handleMessage.bind(this));
    }
    
    openConfiguration(marketId, fastTrackUrl) {
        this.currentMarketId = marketId;
        this.modal = document.getElementById('fasttrack-modal');
        this.iframe = document.getElementById('fasttrack-iframe');
        
        if (!this.modal || !this.iframe) {
            console.error('Fast Track modal elements not found');
            return;
        }
        
        // Set iframe source
        this.iframe.src = fastTrackUrl;
        
        // Show modal
        this.modal.style.display = 'block';
        
        // Handle iframe load events
        this.iframe.onload = () => {
            console.log('Fast Track configuration loaded');
        };
        
        this.iframe.onerror = () => {
            console.error('Failed to load Fast Track configuration');
            this.showError('Failed to load Fast Track. Please try again.');
        };
    }
    
    handleMessage(event) {
        // Verify origin for security
        const fastTrackOrigin = new URL(window.FASTTRACK_BASE_URL || 'http://localhost:3000').origin;
        if (event.origin !== fastTrackOrigin) {
            console.warn('Ignoring message from unknown origin:', event.origin);
            return;
        }
        
        const message = event.data;
        console.log('Received Fast Track message:', message);
        
        switch (message.type) {
            case 'fasttrack:loaded':
                this.handleLoaded(message);
                break;
                
            case 'fasttrack:loading':
                this.handleLoading(message);
                break;
                
            case 'fasttrack:completed':
                this.handleCompleted(message);
                break;
                
            case 'fasttrack:error':
                this.handleError(message);
                break;
                
            default:
                console.log('Unknown message type:', message.type);
        }
    }
    
    handleLoaded(message) {
        console.log('Fast Track loaded successfully');
        
        // Adjust iframe height if provided
        if (message.height && this.iframe) {
            this.iframe.style.height = message.height + 'px';
        }
    }
    
    handleLoading(message) {
        console.log('Fast Track is loading...');
        // Could show loading spinner here
    }
    
    async handleCompleted(message) {
        console.log('Fast Track configuration completed:', message);
        
        const { fastTrackId, marketTitle, deadline, documentsCount } = message;
        
        try {
            // Notify our backend about the completion
            const response = await fetch('/markets/fasttrack-complete', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    marketId: this.currentMarketId,
                    fastTrackId,
                    marketTitle,
                    deadline,
                    documentsCount
                })
            });
            
            const result = await response.json();
            
            if (result.success) {
                this.showSuccess(`Market configured successfully! Fast Track ID: ${fastTrackId}`);
                
                // Close modal after delay
                setTimeout(() => {
                    this.closeModal();
                    // Redirect to markets list
                    window.location.href = '/markets';
                }, 2000);
            } else {
                this.showError('Failed to save Fast Track configuration');
            }
            
        } catch (error) {
            console.error('Error processing Fast Track completion:', error);
            this.showError('Network error while saving configuration');
        }
    }
    
    handleError(message) {
        console.error('Fast Track error:', message);
        this.showError(message.error || 'An error occurred in Fast Track');
    }
    
    closeModal() {
        if (this.modal) {
            this.modal.style.display = 'none';
        }
        
        if (this.iframe) {
            this.iframe.src = '';
        }
        
        this.currentMarketId = null;
    }
    
    showSuccess(message) {
        this.showNotification(message, 'success');
    }
    
    showError(message) {
        this.showNotification(message, 'error');
    }
    
    showNotification(message, type) {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        // Add close button
        const closeBtn = document.createElement('span');
        closeBtn.className = 'notification-close';
        closeBtn.innerHTML = '&times;';
        closeBtn.onclick = () => notification.remove();
        notification.appendChild(closeBtn);
        
        document.body.insertBefore(notification, document.body.firstChild);
        
        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, 5000);
    }
}

// Initialize Fast Track integration
const fastTrack = new FastTrackIntegration();

// Global functions for easy access
function openFastTrackConfiguration(marketId, fastTrackUrl) {
    fastTrack.openConfiguration(marketId, fastTrackUrl);
}

function closeFastTrackModal() {
    fastTrack.closeModal();
}

// Set Fast Track base URL for PostMessage origin verification
window.FASTTRACK_BASE_URL = 'http://localhost:3000';
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

/* Modal Styles */
.modal {
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    overflow: auto;
    background-color: rgba(0, 0, 0, 0.5);
}

.modal-content {
    background-color: white;
    margin: 2% auto;
    padding: 0;
    border-radius: 0.75rem;
    width: 90%;
    max-width: 1000px;
    max-height: 90vh;
    overflow: hidden;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
}

.modal-header {
    padding: 1.5rem;
    border-bottom: 1px solid #e2e8f0;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.modal-header h3 {
    margin: 0;
    color: #1a202c;
}

.close {
    color: #a0aec0;
    font-size: 2rem;
    font-weight: bold;
    cursor: pointer;
    transition: color 0.2s;
}

.close:hover {
    color: #2d3748;
}

.modal-body {
    padding: 1.5rem;
    max-height: calc(90vh - 100px);
    overflow: auto;
}

.modal-body iframe {
    border: none;
    border-radius: 0.375rem;
    background: white;
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

.notification-close {
    margin-left: 1rem;
    cursor: pointer;
    font-size: 1.2rem;
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
    
    .modal-content {
        width: 95%;
        margin: 5% auto;
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
  "version": "1.0.0",
  "description": "Demo editor app integrating with Fast Track",
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

class FastTrackOauthService
  include Rails.application.routes.url_helpers

  attr_reader :client

  def initialize
    @client = OAuth2::Client.new(
      ENV['FASTTRACK_CLIENT_ID'],
      ENV['FASTTRACK_CLIENT_SECRET'],
      site: ENV['FASTTRACK_BASE_URL'],
      authorize_url: '/oauth/authorize',
      token_url: '/oauth/token'
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
    client.auth_code.get_token(
      code,
      redirect_uri: ENV['FASTTRACK_CALLBACK_URL']
    )
  rescue OAuth2::Error => e
    Rails.logger.error "OAuth token exchange failed: #{e.message}"
    raise StandardError, "Authentication failed: #{e.description}"
  end

  def configuration_url(access_token)
    "#{ENV['FASTTRACK_BASE_URL']}/buyer/market_configurations/new?access_token=#{access_token}"
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
  end

  def configure
    market_params = params.require(:market).permit(:title, :description)
    
    @market = Market.create!(
      title: market_params[:title],
      description: market_params[:description],
      status: 'configuring'
    )

    fast_track_url = @oauth_service.configuration_url(
      session[:fast_track_token]['access_token']
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

  def fasttrack_complete
    completion_params = params.permit(:market_id, :fast_track_id, :market_title, :deadline, :documents_count)
    
    market = Market.find(completion_params[:market_id])
    
    market.update!(
      fast_track_id: completion_params[:fast_track_id],
      status: 'configured',
      fast_track_data: {
        market_title: completion_params[:market_title],
        deadline: completion_params[:deadline],
        documents_count: completion_params[:documents_count],
        configured_at: Time.current.iso8601
      }
    )

    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Market not found' }, status: :not_found
  end

  private

  def require_authentication
    token = session[:fast_track_token]
    
    unless token && (!token['expires_at'] || Time.current.to_i < token['expires_at'])
      render json: { error: 'Authentication required' }, status: :unauthorized
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
      post :fasttrack_complete
    end
  end
end
```

---

## PostMessage Communication

### Message Types

Fast Track sends the following PostMessage events:

#### 1. `fasttrack:loaded`
Sent when Fast Track interface is fully loaded.

```javascript
{
  type: 'fasttrack:loaded',
  height: 800  // Suggested iframe height
}
```

#### 2. `fasttrack:loading`
Sent during loading states.

```javascript
{
  type: 'fasttrack:loading'
}
```

#### 3. `fasttrack:completed`
Sent when market configuration is completed.

```javascript
{
  type: 'fasttrack:completed',
  fastTrackId: 'abc123def456',
  marketTitle: 'Office Supplies Procurement 2025',
  deadline: '2025-12-31T23:59:59Z',
  documentsCount: 7
}
```

#### 4. `fasttrack:error`
Sent when an error occurs.

```javascript
{
  type: 'fasttrack:error',
  error: 'Configuration failed',
  details: 'Token expired'
}
```

### Implementation Best Practices

#### Origin Validation

```javascript
window.addEventListener('message', (event) => {
  // CRITICAL: Always validate origin
  const allowedOrigin = 'http://localhost:3000'; // Fast Track origin
  if (event.origin !== allowedOrigin) {
    console.warn('Ignoring message from unauthorized origin:', event.origin);
    return;
  }
  
  handleFastTrackMessage(event.data);
});
```

#### Message Handling

```javascript
function handleFastTrackMessage(message) {
  switch (message.type) {
    case 'fasttrack:completed':
      handleConfigurationComplete(message);
      break;
      
    case 'fasttrack:error':
      handleConfigurationError(message);
      break;
      
    case 'fasttrack:loaded':
      adjustIframeHeight(message.height);
      break;
      
    default:
      console.log('Unhandled message type:', message.type);
  }
}
```

#### Error Handling

```javascript
async function handleConfigurationComplete(message) {
  try {
    const response = await fetch('/markets/fasttrack-complete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        marketId: currentMarketId,
        fastTrackId: message.fastTrackId,
        marketTitle: message.marketTitle,
        deadline: message.deadline,
        documentsCount: message.documentsCount
      })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const result = await response.json();
    
    if (result.success) {
      showSuccess('Market configured successfully!');
      closeFastTrackModal();
      redirectToMarkets();
    } else {
      throw new Error(result.error || 'Unknown error');
    }
    
  } catch (error) {
    console.error('Failed to process configuration completion:', error);
    showError('Failed to save configuration: ' + error.message);
  }
}
```

---

## Security Considerations

### OAuth2 Security

#### State Parameter Validation

```javascript
// Generate cryptographically secure state
function generateState() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

// Store state in session/localStorage
const state = generateState();
sessionStorage.setItem('oauth_state', state);

// Validate on callback
const receivedState = urlParams.get('state');
const storedState = sessionStorage.getItem('oauth_state');

if (receivedState !== storedState) {
  throw new Error('Invalid state parameter - possible CSRF attack');
}
```

#### Token Storage

```javascript
// Secure token storage
class TokenManager {
  static store(token) {
    // Use sessionStorage for temporary storage
    sessionStorage.setItem('fast_track_token', JSON.stringify({
      access_token: token.access_token,
      expires_at: Date.now() + (token.expires_in * 1000),
      scope: token.scope
    }));
  }
  
  static get() {
    const stored = sessionStorage.getItem('fast_track_token');
    if (!stored) return null;
    
    const token = JSON.parse(stored);
    
    // Check expiration
    if (Date.now() > token.expires_at) {
      this.clear();
      return null;
    }
    
    return token;
  }
  
  static clear() {
    sessionStorage.removeItem('fast_track_token');
  }
}
```

### Cross-Domain Security

#### Content Security Policy

```html
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'unsafe-inline';
  style-src 'self' 'unsafe-inline';
  frame-src 'self' http://localhost:3000;
  connect-src 'self' http://localhost:3000;
">
```

#### PostMessage Origin Validation

```javascript
const ALLOWED_ORIGINS = [
  'http://localhost:3000',           // Development
  'https://fasttrack.gouv.fr'        // Production
];

window.addEventListener('message', (event) => {
  if (!ALLOWED_ORIGINS.includes(event.origin)) {
    console.warn('Blocked message from unauthorized origin:', event.origin);
    return;
  }
  
  // Process message
  handleFastTrackMessage(event.data);
});
```

### Input Validation

```javascript
function validateFastTrackMessage(message) {
  // Validate message structure
  if (!message || typeof message !== 'object') {
    throw new Error('Invalid message format');
  }
  
  // Validate required fields
  if (!message.type || typeof message.type !== 'string') {
    throw new Error('Missing or invalid message type');
  }
  
  // Validate specific message types
  switch (message.type) {
    case 'fasttrack:completed':
      if (!message.fastTrackId || typeof message.fastTrackId !== 'string') {
        throw new Error('Invalid Fast Track ID');
      }
      if (!message.marketTitle || typeof message.marketTitle !== 'string') {
        throw new Error('Invalid market title');
      }
      break;
      
    case 'fasttrack:error':
      if (!message.error || typeof message.error !== 'string') {
        throw new Error('Invalid error message');
      }
      break;
  }
  
  return true;
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
- [ ] iFrame loads Fast Track correctly
- [ ] Modal displays properly
- [ ] PostMessage communication works
- [ ] Configuration completion is processed
- [ ] Error handling works
- [ ] Modal closes after completion

#### UI/UX
- [ ] Loading states are shown
- [ ] Error messages are clear
- [ ] Success feedback is provided
- [ ] Responsive design works
- [ ] Accessibility requirements met

### Debugging Tools

#### Browser DevTools

```javascript
// Enable debug logging
window.FASTTRACK_DEBUG = true;

// Enhanced message handler with debugging
function handleMessage(event) {
  if (window.FASTTRACK_DEBUG) {
    console.group('🔄 Fast Track Message');
    console.log('Origin:', event.origin);
    console.log('Data:', event.data);
    console.log('Timestamp:', new Date().toISOString());
    console.groupEnd();
  }
  
  // Process message...
}
```

#### Network Monitoring

```javascript
// Log all Fast Track API calls
const originalFetch = window.fetch;
window.fetch = function(...args) {
  const [url, options] = args;
  
  if (url.includes('fasttrack') || url.includes('oauth')) {
    console.log('🌐 Fast Track API Call:', {
      url,
      method: options?.method || 'GET',
      headers: options?.headers,
      body: options?.body
    });
  }
  
  return originalFetch.apply(this, args);
};
```

#### Integration Testing Script

```javascript
// Automated integration test
async function testFastTrackIntegration() {
  console.log('🧪 Testing Fast Track Integration...');
  
  try {
    // Test 1: Check authentication status
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
      console.log('📋 Market ID:', marketData.marketId);
      console.log('🔗 Fast Track URL:', marketData.fastTrackUrl);
    }
    
  } catch (error) {
    console.error('❌ Test Failed:', error.message);
  }
}

// Run test
testFastTrackIntegration();
```

### Common Issues & Solutions

#### Issue: CORS Errors

**Problem**: Browser blocks requests due to CORS policy.

**Solution**:
```javascript
// Server-side CORS configuration (Express)
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:4000'],
  credentials: true
}));

// Rails CORS configuration
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:3000', 'localhost:4000'
    resource '*', 
      headers: :any, 
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

#### Issue: PostMessage Not Received

**Problem**: iFrame PostMessage events not reaching parent window.

**Solution**:
```javascript
// Check iframe loading
iframe.onload = function() {
  console.log('✅ iFrame loaded successfully');
};

iframe.onerror = function() {
  console.error('❌ iFrame failed to load');
};

// Verify event listener
window.addEventListener('message', function(event) {
  console.log('📨 Message received from:', event.origin);
  console.log('📨 Message data:', event.data);
});
```

#### Issue: OAuth Token Expired

**Problem**: Access token expires during configuration.

**Solution**:
```javascript
// Token refresh mechanism
async function ensureValidToken() {
  const token = getStoredToken();
  
  if (!token || isTokenExpired(token)) {
    // Redirect to re-authenticate
    window.location.href = '/auth/fasttrack';
    return false;
  }
  
  return true;
}

// Check before opening Fast Track
async function openFastTrack() {
  if (await ensureValidToken()) {
    // Proceed with Fast Track integration
    showFastTrackModal();
  }
}
```

#### Issue: Modal Not Closing

**Problem**: Fast Track modal doesn't close after completion.

**Solution**:
```javascript
// Auto-close with timeout fallback
function closeFastTrackModal() {
  const modal = document.getElementById('fasttrack-modal');
  const iframe = document.getElementById('fasttrack-iframe');
  
  // Clear iframe source
  if (iframe) {
    iframe.src = '';
  }
  
  // Hide modal
  if (modal) {
    modal.style.display = 'none';
  }
  
  // Clear any stored state
  currentMarketId = null;
}

// Auto-close fallback
function openFastTrackModal() {
  // ... show modal code ...
  
  // Fallback auto-close after 10 minutes
  setTimeout(() => {
    if (document.getElementById('fasttrack-modal').style.display !== 'none') {
      console.warn('Auto-closing Fast Track modal due to timeout');
      closeFastTrackModal();
    }
  }, 10 * 60 * 1000); // 10 minutes
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

#### Docker Configuration

Create `Dockerfile`:

```dockerfile
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Change ownership
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Start application
CMD ["npm", "start"]
```

#### Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  editor-app:
    build: .
    ports:
      - "4000:4000"
    environment:
      - NODE_ENV=production
      - FASTTRACK_BASE_URL=https://fasttrack.gouv.fr
      - FASTTRACK_CLIENT_ID=${FASTTRACK_CLIENT_ID}
      - FASTTRACK_CLIENT_SECRET=${FASTTRACK_CLIENT_SECRET}
      - FASTTRACK_CALLBACK_URL=https://your-platform.com/auth/fasttrack/callback
      - SESSION_SECRET=${SESSION_SECRET}
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      - postgres
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=editor_app_production
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - editor-app
    restart: unless-stopped

volumes:
  postgres_data:
```

### Security Hardening

#### HTTPS Configuration

```nginx
# nginx.conf
server {
    listen 443 ssl http2;
    server_name your-platform.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://editor-app:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name your-platform.com;
    return 301 https://$server_name$request_uri;
}
```

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
      frameSrc: ["'self'", "https://fasttrack.gouv.fr"],
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

// Session security
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: true, // HTTPS only
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict'
  },
  name: 'sessionId' // Don't use default name
}));
```

### Monitoring & Logging

#### Application Monitoring

```javascript
// Health check endpoint
app.get('/health', (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {
      database: 'healthy', // Check DB connection
      fasttrack: 'healthy', // Check Fast Track connectivity
      memory: process.memoryUsage(),
    }
  };
  
  res.json(health);
});

// Error logging
app.use((error, req, res, next) => {
  console.error('Application Error:', {
    message: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    timestamp: new Date().toISOString()
  });
  
  res.status(500).json({
    error: 'Internal server error',
    requestId: req.id
  });
});
```

#### Structured Logging

```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'editor-app' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Usage
logger.info('Fast Track integration initiated', {
  userId: req.session.user?.id,
  marketId: marketId,
  fastTrackUrl: fastTrackUrl
});

logger.error('OAuth token exchange failed', {
  error: error.message,
  clientId: process.env.FASTTRACK_CLIENT_ID,
  redirectUri: process.env.FASTTRACK_CALLBACK_URL
});
```

---

## Troubleshooting

### Common Integration Issues

#### 1. OAuth Authorization Fails

**Symptoms**: User gets redirected to Fast Track but sees error page.

**Possible Causes**:
- Invalid client credentials
- Incorrect redirect URI
- Missing required scopes

**Debugging**:
```bash
# Check OAuth configuration
curl -X POST http://localhost:3000/oauth/authorize \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "redirect_uri=YOUR_REDIRECT_URI" \
  -d "response_type=code" \
  -d "scope=market_config"
```

**Solutions**:
- Verify client ID and secret with Fast Track admin
- Ensure redirect URI exactly matches registered URL
- Check that your editor is authorized and active

#### 2. Token Exchange Fails

**Symptoms**: Callback receives code but token exchange returns error.

**Debugging**:
```javascript
// Log token exchange request
console.log('Token exchange request:', {
  url: '/oauth/token',
  method: 'POST',
  body: {
    grant_type: 'authorization_code',
    client_id: clientId,
    client_secret: '[REDACTED]',
    code: code,
    redirect_uri: redirectUri
  }
});
```

**Solutions**:
- Check authorization code hasn't expired (5 minutes)
- Verify client secret is correct
- Ensure redirect URI matches exactly

#### 3. iFrame Doesn't Load

**Symptoms**: Fast Track modal shows but iFrame is blank or shows error.

**Debugging**:
```javascript
iframe.onload = function() {
  console.log('iFrame loaded successfully');
  console.log('iFrame URL:', this.src);
  console.log('iFrame content window:', this.contentWindow);
};

iframe.onerror = function(e) {
  console.error('iFrame load error:', e);
  console.error('iFrame URL:', this.src);
};
```

**Solutions**:
- Check access token is valid and not expired
- Verify CORS headers allow iframe embedding
- Ensure CSP headers allow frame-src from Fast Track domain

#### 4. PostMessage Not Received

**Symptoms**: Market configuration completes but parent window doesn't receive notification.

**Debugging**:
```javascript
// Debug all messages
window.addEventListener('message', function(event) {
  console.log('Message received:', {
    origin: event.origin,
    data: event.data,
    source: event.source
  });
}, true);

// Check iframe reference
console.log('iFrame element:', document.getElementById('fasttrack-iframe'));
console.log('iFrame content window:', iframe.contentWindow);
```

**Solutions**:
- Verify origin validation allows Fast Track domain
- Check iframe is fully loaded before expecting messages
- Ensure message event listener is attached before iframe loads

### Performance Optimization

#### 1. Preload Fast Track Resources

```html
<!-- Preload Fast Track domain -->
<link rel="preconnect" href="https://fasttrack.gouv.fr">
<link rel="dns-prefetch" href="https://fasttrack.gouv.fr">
```

#### 2. Optimize Modal Loading

```javascript
// Lazy load modal content
function openFastTrackModal() {
  if (!document.getElementById('fasttrack-modal')) {
    createFastTrackModal();
  }
  
  // Show modal
  const modal = document.getElementById('fasttrack-modal');
  modal.style.display = 'block';
  
  // Load iframe after modal is visible
  setTimeout(() => {
    const iframe = document.getElementById('fasttrack-iframe');
    iframe.src = fastTrackUrl;
  }, 100);
}
```

#### 3. Token Caching

```javascript
// Cache valid tokens to avoid unnecessary OAuth flows
class TokenCache {
  static set(token) {
    const cacheData = {
      token: token,
      expires: Date.now() + (token.expires_in * 1000) - 60000 // 1 minute buffer
    };
    
    sessionStorage.setItem('ft_token_cache', JSON.stringify(cacheData));
  }
  
  static get() {
    const cached = sessionStorage.getItem('ft_token_cache');
    if (!cached) return null;
    
    const data = JSON.parse(cached);
    if (Date.now() > data.expires) {
      this.clear();
      return null;
    }
    
    return data.token;
  }
  
  static clear() {
    sessionStorage.removeItem('ft_token_cache');
  }
}
```

### Support & Documentation

For additional support:

1. **Fast Track Documentation**: Available at `/docs` endpoint
2. **OAuth2 Specification**: [RFC 6749](https://tools.ietf.org/html/rfc6749)
3. **PostMessage API**: [MDN Documentation](https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage)
4. **CORS Configuration**: [MDN CORS Guide](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)

---

## Conclusion

This comprehensive guide provides everything needed to integrate your procurement platform with Fast Track's buyer flow. The implementation ensures security, reliability, and excellent user experience while maintaining compliance with OAuth2 standards and web security best practices.

Key takeaways:

- **OAuth2 Integration**: Secure authentication flow with proper state validation
- **iFrame/Popup Support**: Seamless embedded experience with PostMessage communication
- **Error Handling**: Robust error handling and recovery mechanisms
- **Security**: CSRF protection, origin validation, and secure token storage
- **Production Ready**: Complete deployment and monitoring setup

Follow this guide step-by-step to create a production-quality editor app that integrates seamlessly with Fast Track.