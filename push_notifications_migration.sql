-- Migration script for push notifications
-- Run this SQL in your Supabase SQL Editor

-- 1. Add push notification tracking columns to gifts table
ALTER TABLE gifts 
ADD COLUMN IF NOT EXISTS notification_sent BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS notification_sent_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS notification_scheduled BOOLEAN DEFAULT FALSE;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_gifts_notification_sent ON gifts(notification_sent);
CREATE INDEX IF NOT EXISTS idx_gifts_delivery_time ON gifts(delivery_time);
CREATE INDEX IF NOT EXISTS idx_gifts_notification_scheduled ON gifts(notification_scheduled);

-- Add comments to document the fields
COMMENT ON COLUMN gifts.notification_sent IS 'Whether the push notification has been sent to the recipient';
COMMENT ON COLUMN gifts.notification_sent_at IS 'Timestamp when the push notification was sent';
COMMENT ON COLUMN gifts.notification_scheduled IS 'Whether this gift has been scheduled for notification delivery';

-- 2. Create push_subscriptions table for storing Web Push subscriptions
CREATE TABLE IF NOT EXISTS push_subscriptions (
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

-- Add indexes for push_subscriptions
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint ON push_subscriptions(endpoint);

-- Add RLS policies for push_subscriptions
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own subscriptions
CREATE POLICY "Users can view their own subscriptions" ON push_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own subscriptions" ON push_subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions" ON push_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own subscriptions" ON push_subscriptions
  FOR DELETE USING (auth.uid() = user_id);

-- Add comment to document the table
COMMENT ON TABLE push_subscriptions IS 'Stores Web Push notification subscriptions for users';
COMMENT ON COLUMN push_subscriptions.endpoint IS 'Push service endpoint URL';
COMMENT ON COLUMN push_subscriptions.p256dh IS 'P-256 ECDH public key for encryption';
COMMENT ON COLUMN push_subscriptions.auth IS 'Authentication secret for encryption';
COMMENT ON COLUMN push_subscriptions.user_agent IS 'Browser/device user agent string';

