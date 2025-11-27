# Cloudflare Worker for SweetWeb Email Service

This worker handles all email notifications for SweetWeb using the Resend API, deployed on Cloudflare's free tier (100,000 requests/day).

## Why Cloudflare Workers?

- ✅ **100% Free tier** - 100,000 requests per day, no credit card required
- ✅ **No Firebase Blaze plan needed** - Works with Firebase Spark (free) plan
- ✅ **Instant deployment** - No build process, copy/paste code
- ✅ **Global edge network** - Fast email delivery worldwide
- ✅ **Secure** - API key stored as encrypted environment variable

## Quick Deployment (5 minutes)

### Step 1: Create Cloudflare Account
1. Go to https://dash.cloudflare.com/sign-up
2. Sign up with email (no credit card required)
3. Verify your email

### Step 2: Create Worker
1. Go to https://dash.cloudflare.com
2. Click **Workers & Pages** in left sidebar
3. Click **Create application**
4. Click **Create Worker**
5. Name it: `sweetweb-email-service`
6. Click **Deploy**

### Step 3: Add Code
1. Click **Edit code** button
2. **Delete all existing code**
3. Copy entire content of `worker.js`
4. Paste into the editor
5. Click **Save and Deploy**

### Step 4: Add Resend API Key
1. Click **Settings** tab
2. Scroll to **Environment Variables**
3. Click **Add variable**
4. Enter:
   - **Variable name**: `RESEND_API_KEY`
   - **Value**: `re_M2UEqUWF_QEJGCDgmP1mFpLi1DTNL3758`
   - Click **Encrypt** (recommended)
5. Click **Save and deploy**

### Step 5: Get Your Worker URL
Your worker is now deployed at:
```
https://sweetweb-email-service.YOUR_SUBDOMAIN.workers.dev
```

**Copy this URL** - you'll need it for the Flutter app configuration.

## Configure Flutter App

Edit `lib/core/config/email_config.dart`:

```dart
static const String workerUrl = 'https://sweetweb-email-service.YOUR_SUBDOMAIN.workers.dev';
```

Replace `YOUR_SUBDOMAIN` with your actual Cloudflare subdomain.

## Test the Worker

Test with curl:

### Test Merchant Notification
```bash
curl -X POST https://sweetweb-email-service.YOUR_SUBDOMAIN.workers.dev \
  -H "Content-Type: application/json" \
  -d '{
    "action": "order-notification",
    "data": {
      "orderNo": "A-001",
      "table": "5",
      "items": [{"name": "Test Item", "qty": 2, "price": 1.5}],
      "subtotal": 3.0,
      "timestamp": "2025-11-27 10:30 AM",
      "merchantName": "Test Restaurant",
      "dashboardUrl": "https://sweets-c4f6b.web.app/merchant",
      "toEmail": "merchant@example.com"
    }
  }'
```

### Test Customer Confirmation
```bash
curl -X POST https://sweetweb-email-service.YOUR_SUBDOMAIN.workers.dev \
  -H "Content-Type: application/json" \
  -d '{
    "action": "customer-confirmation",
    "data": {
      "orderNo": "A-001",
      "table": "5",
      "items": [{"name": "Chocolate Cake", "qty": 2, "price": 1.5, "note": "Extra chocolate"}],
      "subtotal": 3.0,
      "timestamp": "2025-11-27 10:30 AM",
      "merchantName": "Sweet Shop",
      "estimatedTime": "15-20 minutes",
      "toEmail": "customer@example.com"
    }
  }'
```

Expected response:
```json
{"success": true, "messageId": "..."}
```

## API Documentation

### POST /

**Headers:**
- `Content-Type: application/json`

**Body:**
```json
{
  "action": "order-notification" | "customer-confirmation" | "report",
  "data": { ... }
}
```

### Actions

#### 1. `order-notification` - Merchant Order Alert
```json
{
  "action": "order-notification",
  "data": {
    "orderNo": "A-001",
    "table": "5",
    "items": [
      {
        "name": "Product Name",
        "qty": 2,
        "price": 1.500,
        "note": "Optional note"
      }
    ],
    "subtotal": 3.000,
    "timestamp": "2025-11-27 10:30 AM",
    "merchantName": "Store Name",
    "dashboardUrl": "https://sweets-c4f6b.web.app/merchant",
    "toEmail": "merchant@example.com"
  }
}
```

#### 2. `customer-confirmation` - Customer Order Confirmation
```json
{
  "action": "customer-confirmation",
  "data": {
    "orderNo": "A-001",
    "table": "5",
    "items": [
      {
        "name": "Product Name",
        "qty": 2,
        "price": 1.500,
        "note": "Optional note"
      }
    ],
    "subtotal": 3.000,
    "timestamp": "2025-11-27 10:30 AM",
    "merchantName": "Store Name",
    "estimatedTime": "15-20 minutes",
    "toEmail": "customer@example.com"
  }
}
```

#### 3. `report` - Sales Report
```json
{
  "action": "report",
  "data": {
    "merchantName": "Store Name",
    "dateRange": "11/01/2025 - 11/27/2025",
    "totalOrders": 50,
    "totalRevenue": 150.500,
    "servedOrders": 45,
    "cancelledOrders": 5,
    "averageOrder": 3.344,
    "topItems": [
      {"name": "Item 1", "count": 20, "revenue": 60.0},
      {"name": "Item 2", "count": 15, "revenue": 45.0}
    ],
    "ordersByStatus": [
      {"status": "served", "count": 45},
      {"status": "cancelled", "count": 5}
    ],
    "toEmail": "merchant@example.com"
  }
}
```

## Email Templates

### Merchant Notification (Purple theme)
- Purple gradient header (#667eea → #764ba2)
- Bell icon 🔔
- Order details with status badge
- Items list with notes
- Link to merchant dashboard

### Customer Confirmation (Green theme)
- Green gradient header (#10b981 → #059669)
- Checkmark icon ✅
- Order details with estimated time
- Items list with notes
- "Being prepared" status
- Thank you message

### Sales Report (Purple theme)
- Purple gradient header
- 4 metric cards (Revenue, Orders, Avg, Cancelled)
- Top 5 selling items table
- Orders by status with progress bars
- Professional layout

## Monitoring

### View Logs
1. Go to Cloudflare Dashboard
2. Workers & Pages > Your Worker
3. Click **Logs** tab
4. See real-time requests and errors

### Check Usage
1. Workers & Pages > Your Worker
2. Click **Analytics** tab
3. View request count, errors, latency

**Free Tier Limit:** 100,000 requests/day

## Troubleshooting

### Emails not sending
- **Check worker logs** for errors
- **Verify API key** is set correctly
- **Test with curl** to isolate issue
- **Check Resend dashboard** for API errors

### Worker not responding
- **Check worker URL** is correct
- **Verify CORS** - check browser console
- **Test with curl** to bypass CORS

### Rate limiting
- Free tier: 100k requests/day
- Typical usage: 10-100/day
- If exceeded, upgrade to Workers Paid ($5/month for 10M requests)

## Production Recommendations

### Before Going Live

1. **Custom Email Domain**
   - Add your domain to Resend
   - Replace `onboarding@resend.dev` with `noreply@yourdomain.com`
   - Verify domain in Resend dashboard

2. **Worker Authentication** (Optional)
   - Add Firebase Auth token validation
   - Prevent unauthorized email sending

3. **Rate Limiting**
   - Implement per-merchant limits
   - Prevent abuse

4. **Error Monitoring**
   - Add Sentry integration
   - Track email failures

5. **Usage Tracking**
   - Log email sends to Firestore
   - Monitor monthly usage vs Resend limits

### Upgrading

**Resend:**
- Free: 3,000 emails/month
- Pro: $20/month for 50,000 emails/month
- Business: $85/month for 200,000 emails/month

**Cloudflare Workers:**
- Free: 100,000 requests/day
- Paid: $5/month for 10M requests/month

## Support

- **Cloudflare Docs**: https://developers.cloudflare.com/workers/
- **Resend Docs**: https://resend.com/docs
- **Issues**: https://github.com/anthropics/claude-code/issues

## Security

✅ API key stored as encrypted environment variable
✅ CORS enabled for Flutter web app
✅ No API key in client code
✅ HTTPS only (enforced by Cloudflare)
⚠️ Consider adding authentication for production
