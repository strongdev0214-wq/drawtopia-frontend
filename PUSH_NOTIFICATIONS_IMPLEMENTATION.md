# Push Notifications Implementation Guide

This document describes the complete scheduled delivery system with push notifications for Drawtopia.

## Overview

The system consists of three main components:

1. **Database Layer**: Supabase tables and pg_cron for scheduling
2. **Backend**: Supabase Edge Function for sending notifications
3. **Frontend**: Service Worker, subscription management, and notification display

## Architecture

```
┌─────────────────┐
│   pg_cron       │  Runs every minute
│   (Scheduler)   │  Checks for gifts ready to notify
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Edge Function  │  Sends Web Push notifications
│  (Backend)      │  Marks as sent in database
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Service Worker  │  Receives push notifications
│  (Frontend)     │  Shows notification to user
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   User Device   │  User sees notification badge
│  (Notification) │  Clicks to view gift
└─────────────────┘
```

## Database Schema

### Gifts Table Additions

```sql
-- New columns for push notifications
notification_sent BOOLEAN DEFAULT FALSE
notification_sent_at TIMESTAMP WITH TIME ZONE
notification_scheduled BOOLEAN DEFAULT FALSE
```

### Push Subscriptions Table

```sql
CREATE TABLE push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, endpoint)
);
```

## Setup Instructions

### 1. Database Setup

Run the SQL migrations in Supabase:

```bash
# In Supabase SQL Editor
# 1. Run push_notifications_migration.sql
# 2. Run pg_cron_setup.sql
```

### 2. Generate VAPID Keys

```bash
# Install web-push if not already installed
npm install -g web-push

# Generate VAPID keys
npx web-push generate-vapid-keys

# Output example:
# Public Key: BEl62iUYgUivxIkv69yViEuiBIa...
# Private Key: UUxI4O8TqEJZsafM5OfAWjv...
```

### 3. Set Supabase Environment Variables

In your Supabase project dashboard (Settings > Edge Functions > Secrets):

```
VAPID_PUBLIC_KEY=your_public_key_here
VAPID_PRIVATE_KEY=your_private_key_here
VAPID_SUBJECT=mailto:support@drawtopia.com
```

Optional (for FCM):
```
FCM_SERVER_KEY=your_fcm_server_key
```

### 4. Deploy Edge Function

```bash
cd drawtopia-backend

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Deploy the function
supabase functions deploy send-gift-notification
```

### 5. Configure pg_cron to Call Edge Function

Option A: Use pg_net (recommended):

```sql
-- Enable pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create cron job to call Edge Function
SELECT cron.schedule(
  'send-gift-notifications',
  '* * * * *',  -- Every minute
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-gift-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_ANON_KEY'
    ),
    body := jsonb_build_object('mode', 'batch')
  );
  $$
);
```

Option B: Let Edge Function poll (simpler):

The `process_scheduled_gift_notifications()` function marks gifts as scheduled, and you can call the Edge Function periodically from an external cron service (like GitHub Actions, Vercel Cron, etc.).

### 6. Frontend Environment Variables

Add to `drawtopia-frontend/.env`:

```env
VITE_VAPID_PUBLIC_KEY=your_public_key_here
```

### 7. Update Service Worker Registration

The service worker is automatically registered in `+layout.svelte`. Make sure the following files exist:

- `/static/sw.js` - Service worker (✓ created)
- `/static/offline.html` - Offline page (✓ created)
- `/static/manifest.json` - Web app manifest (✓ created)
- `/static/icon-192.png` - App icon (add your icon)
- `/static/badge-72.png` - Badge icon (add your icon)

### 8. Link Manifest in HTML

Add to `app.html` (or index.html):

```html
<head>
  <link rel="manifest" href="/manifest.json">
  <meta name="theme-color" content="#667eea">
</head>
```

## Usage

### For Users

1. **Enable Notifications**:
   - Go to Account Settings
   - Scroll to "Push Notifications" section
   - Click "Enable Notifications"
   - Allow notifications when prompted

2. **Receive Gift**:
   - Gift sender schedules delivery time
   - At delivery time, system sends push notification
   - User sees notification badge on app icon
   - User clicks notification to view gift

### For Developers

#### Create a Scheduled Gift

```typescript
import { createGift } from '$lib/database/gifts';

const gift = {
  status: 'generating',
  occasion: 'Birthday',
  relationship: 'Sister',
  delivery_time: '2025-12-25T09:00:00Z', // Christmas morning
  child_profile_id: 'child-id',
  special_msg: 'Happy Birthday!',
  delivery_email: 'recipient@example.com',
  child_name: 'Emma',
  age_group: '5-7'
};

await createGift(gift);
```

#### Manually Trigger Notification

```bash
# Call Edge Function directly
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-gift-notification \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"giftId": "gift-uuid", "mode": "single"}'
```

#### Check Notification Status

```sql
-- Pending notifications
SELECT id, child_name, delivery_time, notification_sent
FROM gifts
WHERE notification_sent = false
  AND status = 'completed'
  AND delivery_time <= NOW()
ORDER BY delivery_time;

-- Sent notifications
SELECT id, child_name, notification_sent_at
FROM gifts
WHERE notification_sent = true
ORDER BY notification_sent_at DESC
LIMIT 20;
```

## Components Overview

### Backend Components

1. **`push_notifications_migration.sql`**
   - Adds notification columns to gifts table
   - Creates push_subscriptions table
   - Sets up RLS policies

2. **`pg_cron_setup.sql`**
   - Enables pg_cron extension
   - Creates scheduled job
   - Defines helper functions

3. **`supabase/functions/send-gift-notification/index.ts`**
   - Supabase Edge Function
   - Sends Web Push notifications
   - Handles VAPID authentication
   - Supports FCM fallback

### Frontend Components

1. **`src/lib/pushNotifications.ts`**
   - Core push notification utilities
   - Subscription management
   - Service worker registration

2. **`src/lib/stores/giftNotifications.ts`**
   - Global notification state
   - Badge count management
   - Service worker communication

3. **`src/components/PushNotificationSettings.svelte`**
   - UI for managing push subscriptions
   - Enable/disable notifications
   - Test notifications
   - View active devices

4. **`src/components/NotificationComponent.svelte`**
   - Notification bell icon with badge
   - Dropdown showing received gifts
   - Mark as read functionality

5. **`static/sw.js`**
   - Service Worker
   - Handles push events
   - Shows notifications
   - Updates badge count

## Testing

### Test Notification Flow

1. **Create a test gift** with delivery_time in 1-2 minutes
2. **Wait for cron job** to run (every minute)
3. **Check database** - notification_scheduled should be true
4. **Edge Function runs** and sends notification
5. **Check database** - notification_sent should be true
6. **User receives** push notification on device

### Test Push Subscription

```typescript
import { subscribeToPushNotifications, showLocalNotification } from '$lib/pushNotifications';

// Subscribe
const subscription = await subscribeToPushNotifications();
console.log('Subscribed:', subscription);

// Test notification
await showLocalNotification('Test', {
  body: 'This is a test notification',
  icon: '/icon-192.png'
});
```

### Monitor Cron Jobs

```sql
-- View cron jobs
SELECT * FROM cron.job;

-- View job run history
SELECT 
  jobid,
  runid,
  job_pid,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;
```

## Troubleshooting

### Notifications Not Received

1. **Check browser permissions**: Ensure notifications are allowed
2. **Check subscription**: Verify user has active push subscription in database
3. **Check service worker**: Open DevTools > Application > Service Workers
4. **Check Edge Function logs**: Supabase Dashboard > Edge Functions > Logs
5. **Check cron job**: Query `cron.job_run_details` for errors

### Service Worker Not Registering

1. **HTTPS required**: Service workers only work on HTTPS (or localhost)
2. **Check scope**: Service worker scope must include the pages
3. **Clear cache**: DevTools > Application > Storage > Clear site data
4. **Check console**: Look for service worker errors in console

### Cron Job Not Running

1. **Check if enabled**: `SELECT * FROM cron.job WHERE jobname = 'process-gift-notifications'`
2. **Check schedule**: Verify cron expression is valid
3. **Check logs**: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10`
4. **Manual test**: Run `SELECT process_scheduled_gift_notifications()` directly

### VAPID Errors

1. **Verify keys**: Check that VAPID keys are set correctly in Supabase secrets
2. **Key format**: Ensure keys are base64 URL-safe encoded
3. **Subject**: VAPID subject must be a valid mailto: or https: URL

## Browser Support

- ✅ Chrome/Edge 50+
- ✅ Firefox 44+
- ✅ Safari 16+ (iOS 16.4+)
- ✅ Opera 37+
- ❌ Internet Explorer (not supported)

## Security Considerations

1. **RLS Policies**: Push subscriptions are user-specific with RLS enabled
2. **Service Role Key**: Edge Function uses service role to bypass RLS when sending
3. **VAPID Keys**: Keep private key secret, never expose in frontend
4. **Endpoint Security**: Push endpoints are encrypted and signed
5. **Subscription Cleanup**: Invalid subscriptions (410 Gone) are automatically removed

## Performance

- **Cron frequency**: Every 1 minute (adjustable)
- **Batch size**: 50 gifts per run (configurable)
- **Edge Function**: ~100-500ms per notification batch
- **Database**: Indexed queries for fast lookups
- **Frontend**: Polling every 30 seconds for new notifications

## Future Enhancements

1. **Rich Notifications**: Add images, actions, and interactive elements
2. **Notification History**: Store notification history in database
3. **User Preferences**: Allow users to customize notification types
4. **Delivery Window**: Support specific delivery time windows (e.g., 9am-10am)
5. **Retry Logic**: Retry failed notifications with exponential backoff
6. **Analytics**: Track notification open rates and engagement

## Resources

- [Web Push API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/Push_API)
- [Service Worker Guide](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [VAPID Specification](https://tools.ietf.org/html/rfc8292)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [pg_cron Documentation](https://github.com/citusdata/pg_cron)

## Support

For issues or questions:
1. Check this documentation
2. Review Supabase Edge Function logs
3. Check browser console for errors
4. Verify database configuration
5. Test with manual API calls

## License

This implementation is part of the Drawtopia project.

