-- pg_cron setup for scheduled gift notifications
-- Run this SQL in your Supabase SQL Editor

-- 1. Enable pg_cron extension (if not already enabled)
-- Note: pg_cron is typically pre-enabled in Supabase projects
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Grant necessary permissions
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- 3. Create a function to check and send scheduled notifications
CREATE OR REPLACE FUNCTION process_scheduled_gift_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  gift_record RECORD;
  edge_function_url TEXT;
  api_key TEXT;
  response TEXT;
BEGIN
  -- Get your Edge Function URL and anon key from environment or set here
  -- You'll need to replace these with your actual values
  edge_function_url := current_setting('app.settings.edge_function_url', true);
  api_key := current_setting('app.settings.supabase_anon_key', true);
  
  -- Find gifts that need notification:
  -- 1. delivery_time is in the past or current
  -- 2. notification_sent is false
  -- 3. status is 'completed' (gift generation is done)
  -- 4. to_user_id is not null (recipient is a registered user)
  FOR gift_record IN
    SELECT 
      g.id,
      g.to_user_id,
      g.child_name,
      g.occasion,
      g.delivery_time,
      g.from_user_id,
      u.email as recipient_email
    FROM gifts g
    LEFT JOIN auth.users u ON g.to_user_id = u.id
    WHERE 
      g.notification_sent = false
      AND g.status = 'completed'
      AND g.to_user_id IS NOT NULL
      AND g.delivery_time <= NOW()
    ORDER BY g.delivery_time ASC
    LIMIT 50  -- Process in batches to avoid timeout
  LOOP
    BEGIN
      -- Call the Edge Function using HTTP request
      -- Note: This requires the http extension and proper configuration
      -- Alternative: Use Supabase's built-in scheduler or external cron service
      
      -- For now, we'll just mark as scheduled and let the Edge Function poll
      -- or use Supabase's Realtime/Webhooks
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
END;
$$;

-- 4. Schedule the cron job to run every minute
-- This will check for gifts that need notifications
SELECT cron.schedule(
  'process-gift-notifications',        -- Job name
  '* * * * *',                         -- Cron expression (every minute)
  $$SELECT process_scheduled_gift_notifications();$$
);

-- 5. Alternative: Run every 5 minutes (more efficient for production)
-- Uncomment the following and comment out the above if you prefer:
-- SELECT cron.schedule(
--   'process-gift-notifications',
--   '*/5 * * * *',                     -- Every 5 minutes
--   $$SELECT process_scheduled_gift_notifications();$$
-- );

-- 6. View scheduled jobs
-- SELECT * FROM cron.job;

-- 7. Unschedule job (if needed)
-- SELECT cron.unschedule('process-gift-notifications');

-- 8. View job run history
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- Additional: Create a helper function to mark notification as sent
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION process_scheduled_gift_notifications() TO postgres;
GRANT EXECUTE ON FUNCTION mark_notification_sent(UUID) TO postgres;
GRANT EXECUTE ON FUNCTION mark_notification_sent(UUID) TO service_role;

