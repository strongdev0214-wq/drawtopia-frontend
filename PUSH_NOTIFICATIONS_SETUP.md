# Push Notifications Setup Guide

This guide will help you set up Web Push Notifications for the Drawtopia frontend.

## Prerequisites

- Node.js installed
- Supabase project configured
- `push_subscriptions` table created (see backend migration)

## Step 1: Generate VAPID Keys

VAPID keys are required for Web Push Notifications. Generate them using:

```bash
npx web-push generate-vapid-keys
```

This will output something like:
```
=======================================
Public Key:
BEl62iUYgUivxIkv69yViEuiBIa-Ib27SX6O7_lBMUf...

Private Key:
p6YrrGQK9JdbEkc8hUyKSG4WM0cW5-8jRvhPg7XyK...
=======================================
```

## Step 2: Configure Frontend Environment

Create a `.env` file in `drawtopia-frontend/` directory:

```env
# Supabase Configuration
VITE_SUPABASE_URL=your_supabase_url_here
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key_here

# Web Push Notifications - USE THE PUBLIC KEY FROM STEP 1
VITE_VAPID_PUBLIC_KEY=BEl62iUYgUivxIkv69yViEuiBIa-Ib27SX6O7_lBMUf...

# Stripe Configuration (if applicable)
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_...
VITE_STRIPE_PRICE_ID_MONTHLY=price_...
VITE_STRIPE_PRICE_ID_YEARLY=price_...

# Frontend URL
VITE_FRONTEND_URL=http://localhost:5173
```

## Step 3: Configure Backend (Supabase Edge Functions)

Set the VAPID keys as Supabase secrets for the edge functions:

```bash
# Navigate to backend directory
cd drawtopia-backend

# Set secrets (use the keys from Step 1)
supabase secrets set VAPID_PUBLIC_KEY="BEl62iUYgUivxIkv69yViEuiBIa-Ib27SX6O7_lBMUf..."
supabase secrets set VAPID_PRIVATE_KEY="p6YrrGQK9JdbEkc8hUyKSG4WM0cW5-8jRvhPg7XyK..."
supabase secrets set VAPID_SUBJECT="mailto:support@drawtopia.ai"
```

## Step 4: Create Database Table

Run the migration to create the `push_subscriptions` table:

### Option A: Using Supabase Dashboard
1. Go to SQL Editor in Supabase Dashboard
2. Copy the contents of `drawtopia-backend/scheduled_delivery_migration.sql`
3. Run the SQL

### Option B: Using Supabase CLI
```bash
cd drawtopia-backend
supabase db push
```

## Step 5: Restart Development Server

After setting up the `.env` file:

```bash
cd drawtopia-frontend
npm run dev
```

## Step 6: Test Push Notifications

1. Navigate to `/account` page
2. You should see "Notifications Disabled" status
3. Click "Enable Notifications"
4. Browser will prompt for permission - click "Allow"
5. Status should change to "Notifications Enabled"
6. Click "Send Test Notification" to verify it works

## Troubleshooting

### Issue: "Notifications are blocked"
- **Solution**: Go to browser settings and enable notifications for your site
- Chrome: Site settings → Notifications → Allow
- Firefox: Permissions → Notifications → Allow

### Issue: "Push notifications are not supported"
- **Solution**: Use a modern browser (Chrome, Firefox, Safari, Edge)
- Note: Some browsers on iOS have limited support

### Issue: Button doesn't work / Always shows "Disabled"
**Possible causes:**
1. Missing `VITE_VAPID_PUBLIC_KEY` in `.env` file
2. `push_subscriptions` table doesn't exist
3. Service worker not registered

**Solution:**
- Check browser console for errors
- Verify `.env` file exists and has VAPID key
- Run the database migration
- Clear browser cache and reload

### Issue: Database errors
**Solution:** Ensure `push_subscriptions` table exists:
```sql
SELECT * FROM push_subscriptions LIMIT 1;
```

If error, run the migration from `scheduled_delivery_migration.sql`

## Verification Checklist

- [ ] VAPID keys generated
- [ ] Frontend `.env` file created with `VITE_VAPID_PUBLIC_KEY`
- [ ] Backend Supabase secrets set (VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT)
- [ ] `push_subscriptions` table created in database
- [ ] Development server restarted
- [ ] Service worker registered (check browser DevTools → Application → Service Workers)
- [ ] Notifications permission granted in browser
- [ ] Test notification works

## Security Notes

⚠️ **IMPORTANT:**
- Never commit `.env` files to git
- Keep VAPID private key secret
- Only share public key with frontend
- Private key should only be in Supabase secrets (backend)

## Architecture

```
User Browser
    ↓ (subscribes)
Service Worker (sw.js)
    ↓ (saves subscription)
push_subscriptions table
    ↓ (reads subscriptions)
send-gift-notification Edge Function
    ↓ (sends notification)
Web Push Service (browser vendor)
    ↓ (delivers)
User Browser (notification appears)
```

## Related Files

- `src/components/PushNotificationSettings.svelte` - Settings UI
- `src/lib/pushNotifications.ts` - Push notification library
- `static/sw.js` - Service worker
- `supabase/functions/send-gift-notification/index.ts` - Backend function
- `scheduled_delivery_migration.sql` - Database schema

## Support

If you continue to have issues:
1. Check browser console for errors
2. Check Supabase logs for edge function errors
3. Verify all environment variables are set correctly
4. Ensure service worker is registered and active

