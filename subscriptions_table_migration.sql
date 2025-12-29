-- =====================================================
-- SUBSCRIPTIONS TABLE MIGRATION
-- =====================================================
-- This migration creates the subscriptions table for storing
-- Stripe subscription data.
-- Run this in your Supabase SQL editor.
-- =====================================================

-- Create subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    stripe_customer_id TEXT NOT NULL,
    stripe_subscription_id TEXT UNIQUE NOT NULL,
    customer_email TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    plan_type TEXT DEFAULT 'monthly', -- 'monthly' or 'yearly'
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    last_payment_date TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_customer_id ON public.subscriptions(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_subscription_id ON public.subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);

-- Enable Row Level Security
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can view their own subscriptions
CREATE POLICY "Users can view own subscriptions"
    ON public.subscriptions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can do everything (for webhooks)
CREATE POLICY "Service role has full access"
    ON public.subscriptions
    FOR ALL
    USING (auth.role() = 'service_role');

-- Allow inserts from authenticated users for linking
CREATE POLICY "Authenticated users can insert subscriptions"
    ON public.subscriptions
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Users can update their own subscriptions
CREATE POLICY "Users can update own subscriptions"
    ON public.subscriptions
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Create a function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update updated_at
DROP TRIGGER IF EXISTS subscriptions_updated_at_trigger ON public.subscriptions;
CREATE TRIGGER subscriptions_updated_at_trigger
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_subscriptions_updated_at();

-- Create a view for active subscriptions
CREATE OR REPLACE VIEW public.active_subscriptions AS
SELECT 
    s.*,
    u.email as user_email_from_auth
FROM public.subscriptions s
LEFT JOIN auth.users u ON s.user_id = u.id
WHERE s.status = 'active' 
  AND (s.current_period_end IS NULL OR s.current_period_end > NOW());

-- Grant permissions
GRANT SELECT ON public.subscriptions TO authenticated;
GRANT SELECT ON public.active_subscriptions TO authenticated;

-- =====================================================
-- NOTES:
-- =====================================================
-- 1. Make sure to set up the Stripe webhook in your Stripe dashboard:
--    - Go to Developers > Webhooks
--    - Add endpoint: https://your-backend-url/api/stripe/webhook
--    - Select events: 
--      * checkout.session.completed
--      * customer.subscription.created
--      * customer.subscription.updated
--      * customer.subscription.deleted
--      * invoice.payment_succeeded
--      * invoice.payment_failed
--
-- 2. Create Stripe products and prices:
--    - Go to Products in Stripe dashboard
--    - Create a product for "Drawtopia Family Subscription"
--    - Add monthly price ($14.99/month)
--    - Add yearly price ($179.88/year)
--    - Copy the price IDs to your .env file
--
-- 3. Test with Stripe test mode first before going live
-- =====================================================

