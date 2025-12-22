-- pg_cron setup for scheduled gift notifications
-- Run this SQL in your Supabase SQL Editor

-- Note: pg_cron is pre-enabled in Supabase projects, no need to create it
-- If you need to check: SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- 1. Grant necessary permissions (skip if already granted)
-- GRANT USAGE ON SCHEMA cron TO postgres;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- 2. Create a function to check and send scheduled notifications
CREATE OR REPLACE FUNCTION process_scheduled_gift_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  gift_record RECORD;
  http_request_id INTEGER;
  response_status INTEGER;
BEGIN
  -- Find gifts that need notification:
  -- 1. delivery_time is in the past or current
  -- 2. notification_sent is false OR null
  -- 3. notification_scheduled is false OR null
  -- 4. status is 'completed' (gift generation is done)
  -- 5. to_user_id is not null (recipient is a registered user)
  FOR gift_record IN
    SELECT 
      g.id,
      g.to_user_id,
      g.child_name,
      g.occasion,
      g.delivery_time,
      g.from_user_id
    FROM gifts g
    WHERE 
      (g.notification_sent = false OR g.notification_sent IS NULL)
      AND (g.notification_scheduled = false OR g.notification_scheduled IS NULL)
      AND g.status = 'completed'
      AND g.to_user_id IS NOT NULL
      AND g.delivery_time <= NOW()
    ORDER BY g.delivery_time ASC
    LIMIT 50  -- Process in batches to avoid timeout
  LOOP
    BEGIN
      -- Mark as scheduled to prevent duplicate processing
      UPDATE gifts
      SET notification_scheduled = true
      WHERE id = gift_record.id;
      
      -- Log the scheduling
      RAISE NOTICE 'Scheduled notification for gift % to user %', 
        gift_record.id, gift_record.to_user_id;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to schedule notification for gift %: %', 
        gift_record.id, SQLERRM;
    END;
  END LOOP;
  
  -- After marking gifts as scheduled, call the Edge Function
  -- The Edge Function will process all notification_scheduled = true gifts
  -- Note: Requires http extension (CREATE EXTENSION http;)
  -- This is a simplified version - in production, use pg_net or similar
  
  RAISE NOTICE 'Processed % gifts for notification', (SELECT COUNT(*) FROM gifts WHERE notification_scheduled = true AND notification_sent = false);
END;
$$;

-- 3. Create function to call the Edge Function
-- IMPORTANT: Replace YOUR_SERVICE_ROLE_KEY_HERE with your actual service role key
-- Find it at: https://supabase.com/dashboard/project/mnnoucvlyxridktelpxs/settings/api
-- Look for "service_role" under Project API keys (starts with eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...)
CREATE OR REPLACE FUNCTION call_send_gift_notification_edge_function()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  request_id BIGINT;
  service_key TEXT := 'YOUR_SERVICE_ROLE_KEY_HERE'; -- REPLACE THIS WITH YOUR ACTUAL KEY
BEGIN
  -- Call the Edge Function using pg_net extension
  -- Make sure pg_net extension is enabled: CREATE EXTENSION IF NOT EXISTS pg_net;
  
  SELECT net.http_post(
    url := 'https://mnnoucvlyxridktelpxs.supabase.co/functions/v1/send-gift-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object('mode', 'batch')
  ) INTO request_id;
  
  RAISE NOTICE 'Called edge function with request_id: %', request_id;
  
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to call edge function: %', SQLERRM;
END;
$$;

-- 4. Schedule the cron job to mark gifts as scheduled (runs every minute)
SELECT cron.schedule(
  'mark-gifts-scheduled',               -- Job name
  '* * * * *',                          -- Cron expression (every minute)
  $$SELECT process_scheduled_gift_notifications();$$
);

-- 5. Schedule the cron job to call edge function (runs every 2 minutes)
SELECT cron.schedule(
  'send-gift-notifications',            -- Job name
  '*/2 * * * *',                        -- Cron expression (every 2 minutes)
  $$SELECT call_send_gift_notification_edge_function();$$
);

-- 6. Alternative: Run every 5 minutes (more efficient for production)
-- Uncomment and adjust if you prefer less frequent checks:
-- SELECT cron.unschedule('mark-gifts-scheduled');
-- SELECT cron.unschedule('send-gift-notifications');
-- SELECT cron.schedule('mark-gifts-scheduled', '*/5 * * * *', $$SELECT process_scheduled_gift_notifications();$$);
-- SELECT cron.schedule('send-gift-notifications', '*/5 * * * *', $$SELECT call_send_gift_notification_edge_function();$$);

-- 7. Enable pg_net extension for HTTP requests (required for calling Edge Functions)
-- Note: pg_net might already be enabled in your Supabase project
-- Check first: SELECT * FROM pg_extension WHERE extname = 'pg_net';
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    CREATE EXTENSION pg_net;
  END IF;
END $$;

-- 8. View scheduled jobs
-- SELECT * FROM cron.job;

-- 9. Unschedule jobs (if needed)
-- SELECT cron.unschedule('mark-gifts-scheduled');
-- SELECT cron.unschedule('send-gift-notifications');

-- 10. View job run history
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- 11. View pg_net requests
-- SELECT * FROM net.http_request_queue ORDER BY id DESC LIMIT 10;

-- 12. Additional: Create a helper function to mark notification as sent
CREATE OR REPLACE FUNCTION mark_notification_sent(gift_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE gifts
  SET 
    notification_sent = true,
    notification_sent_at = NOW()
  WHERE id = gift_id;
END;
$$;

-- 13. Grant execute permissions
GRANT EXECUTE ON FUNCTION process_scheduled_gift_notifications() TO postgres;
GRANT EXECUTE ON FUNCTION call_send_gift_notification_edge_function() TO postgres;
GRANT EXECUTE ON FUNCTION mark_notification_sent(UUID) TO postgres;
GRANT EXECUTE ON FUNCTION mark_notification_sent(UUID) TO service_role;

