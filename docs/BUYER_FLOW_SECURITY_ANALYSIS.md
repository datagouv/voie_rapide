# Buyer Flow Security Analysis

## Overview

The buyer/market creation flow in Fast Track implements a secure OAuth2-based authentication system for editor platforms to create and configure public markets. This document analyzes the complete security implementation.

## Security Architecture

### 1. OAuth2 Implementation

The system uses **Doorkeeper** for OAuth2 provider functionality with the following configuration:

- **Grant Type**: Authorization Code flow only (most secure)
- **Token Expiration**: 
  - Authorization code: 5 minutes
  - Access token: 1 hour
- **Scopes**: `market_config`, `market_read`, `application_read`
- **Token Methods**: Bearer authorization, access token param, bearer param

### 2. Authentication Flow

#### Step 1: Editor Platform Authentication
1. Editor platform initiates OAuth flow by redirecting to:
   ```
   /oauth/authorize?client_id=X&redirect_uri=Y&response_type=code&scope=market_config&state=Z
   ```

2. Fast Track validates:
   - Client ID exists and matches an authorized editor
   - Redirect URI matches registered callback URL
   - State parameter for CSRF protection

#### Step 2: Authorization Code Exchange
1. After user authorization, Fast Track redirects back with:
   ```
   callback_url?code=AUTH_CODE&state=STATE
   ```

2. Editor exchanges code for access token:
   ```
   POST /oauth/token
   {
     "grant_type": "authorization_code",
     "client_id": "...",
     "client_secret": "...",
     "code": "...",
     "redirect_uri": "..."
   }
   ```

#### Step 3: Authenticated Access
1. Editor redirects to Fast Track with access token:
   ```
   /buyer/market_configurations/new?access_token=TOKEN&callback_url=URL&state=STATE
   ```

2. Fast Track stores token in session for subsequent requests

### 3. Security Layers

#### Authentication & Authorization
```ruby
# BaseController enforces authentication
before_action :authenticate_editor!
before_action :ensure_editor_authorized!

def authenticate_editor!
  doorkeeper_authorize!  # Validates OAuth token
end

def ensure_editor_authorized!
  return if current_editor&.authorized_and_active?
  render json: { error: 'Editor not authorized' }, status: :forbidden
end
```

#### Token Validation
The system validates tokens through multiple methods:
1. **Session token**: Stored after initial OAuth redirect
2. **API token**: Passed via Bearer header or parameter
3. **Token expiration**: Checked on each request
4. **Token revocation**: Verified against Doorkeeper tables

#### State Parameter Protection
```ruby
# Callback parameter storage with CSRF protection
def store_callback_params
  return if params[:callback_url].blank?
  
  session[:platform_callback] = {
    url: params[:callback_url],
    state: params[:state]  # CSRF token from editor
  }
end
```

### 4. Editor Context Maintenance

The system maintains editor context throughout the flow:

1. **OAuth Token Storage**:
   ```ruby
   # Token stored in session after redirect
   session[:oauth_access_token] = params[:access_token]
   ```

2. **Editor Identification**:
   ```ruby
   def current_editor
     @current_editor ||= find_current_editor
   end

   def find_current_editor
     return nil unless doorkeeper_token
     application = doorkeeper_token.application
     Editor.find_by(client_id: application.uid) if application
   end
   ```

3. **Audit Trail**:
   ```ruby
   def log_buyer_action(action, details = {})
     Rails.logger.info({
       buyer_action: action,
       editor_id: current_editor&.id,
       editor_name: current_editor&.name,
       timestamp: Time.current,
       details: details
     }.to_json)
   end
   ```

### 5. Callback Mechanism

The callback system ensures secure return to the editor platform:

1. **Callback URL Storage**:
   - Stored in session with state parameter
   - Validated against editor's registered callback URL

2. **Callback Execution**:
   ```ruby
   def handle_platform_callback
     callback_data = session[:platform_callback]
     
     if valid_callback_data?(callback_data)
       callback_url = build_callback_url(callback_data)
       redirect_to callback_url.to_s, allow_other_host: true
     end
   end
   ```

3. **Callback Parameters**:
   - `fast_track_id`: Generated market identifier
   - `state`: Original CSRF token from editor
   - `market_title`, `deadline`, `documents_count`: Market details

### 6. Security Vulnerabilities & Mitigations

#### Potential Vulnerabilities

1. **Open Redirect**: 
   - **Risk**: Callback URL could redirect to malicious site
   - **Mitigation**: Callback URL must match registered editor callback

2. **Token Leakage**:
   - **Risk**: Access token in URL parameters
   - **Mitigation**: Token cleared from URL after storage in session

3. **Session Fixation**:
   - **Risk**: Attacker could set session before OAuth
   - **Mitigation**: New session created after authentication

4. **CSRF**:
   - **Risk**: Forged requests during OAuth flow
   - **Mitigation**: State parameter validation

#### Security Best Practices Implemented

1. **Token Handling**:
   - Tokens hashed in database (configurable)
   - Short expiration times
   - Secure session storage
   - HTTPS enforcement in production

2. **Editor Validation**:
   - Must be authorized AND active
   - Client credentials verified
   - Doorkeeper application synchronized

3. **Audit Logging**:
   - All buyer actions logged
   - Token usage tracked
   - Error conditions recorded

### 7. Flow Security Pattern

The complete secure flow:

1. **Editor App** → OAuth authorize request with state
2. **Fast Track** → Validates editor, shows authorization
3. **User** → Approves authorization
4. **Fast Track** → Redirects with code and state
5. **Editor App** → Exchanges code for token
6. **Editor App** → Redirects to Fast Track with token & callback
7. **Fast Track** → Validates token, stores in session
8. **User** → Configures market in Fast Track
9. **Fast Track** → Redirects to callback with results & state
10. **Editor App** → Validates state, processes results

## Key Security Features

1. **No Direct API Access**: All access through OAuth flow
2. **Editor Isolation**: Each editor only sees their own data
3. **Token Scope Limitation**: Specific scopes for different operations
4. **Comprehensive Logging**: Full audit trail of all operations
5. **Session Security**: HTTP-only cookies, secure flag in production
6. **CSRF Protection**: State parameters throughout flow
7. **Authorization Checks**: Multiple layers of permission validation

## Implementation Guidelines for Candidate Flow

To apply the same security pattern to the candidate flow:

1. **OAuth Integration**: Use similar Doorkeeper configuration
2. **State Management**: Implement CSRF tokens for all redirects
3. **Session Handling**: Store tokens securely in session
4. **Callback Security**: Validate all callback URLs
5. **Audit Logging**: Track all candidate actions
6. **Token Validation**: Check expiration and revocation
7. **Context Preservation**: Maintain editor context throughout

## Security Checklist

- [x] OAuth2 authorization code flow
- [x] CSRF protection via state parameter
- [x] Token expiration handling
- [x] Secure session management
- [x] Callback URL validation
- [x] Editor authorization checks
- [x] Comprehensive audit logging
- [x] Error handling without information leakage
- [x] HTTPS enforcement (production)
- [x] Token scope limitations