-- Email Queue Table Migration
-- Creates email_queue table for async email processing

-- Create email_queue table
CREATE TABLE IF NOT EXISTS public.email_queue (
    id BIGSERIAL PRIMARY KEY,
    email_type TEXT NOT NULL,
    to_email TEXT NOT NULL,
    email_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending',
    priority INTEGER NOT NULL DEFAULT 5,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 5,
    scheduled_for TIMESTAMPTZ,
    last_error TEXT,
    result JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    
    -- Add constraints
    CONSTRAINT email_queue_status_check CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    CONSTRAINT email_queue_priority_check CHECK (priority >= 1 AND priority <= 10),
    CONSTRAINT email_queue_retry_count_check CHECK (retry_count >= 0)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_email_queue_status ON public.email_queue(status);
CREATE INDEX IF NOT EXISTS idx_email_queue_priority ON public.email_queue(priority);
CREATE INDEX IF NOT EXISTS idx_email_queue_scheduled_for ON public.email_queue(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_email_queue_created_at ON public.email_queue(created_at);
CREATE INDEX IF NOT EXISTS idx_email_queue_to_email ON public.email_queue(to_email);
CREATE INDEX IF NOT EXISTS idx_email_queue_email_type ON public.email_queue(email_type);

-- Composite index for queue processing
CREATE INDEX IF NOT EXISTS idx_email_queue_processing 
ON public.email_queue(status, priority, created_at) 
WHERE status = 'pending';

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_email_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER email_queue_updated_at_trigger
    BEFORE UPDATE ON public.email_queue
    FOR EACH ROW
    EXECUTE FUNCTION update_email_queue_updated_at();

-- Add RLS (Row Level Security) policies
ALTER TABLE public.email_queue ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can do everything
CREATE POLICY "Service role can manage email queue"
    ON public.email_queue
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy: Authenticated users can view their own email queue entries (by email)
-- Note: This is optional - you may want to restrict this entirely to service role
CREATE POLICY "Users can view own email queue entries"
    ON public.email_queue
    FOR SELECT
    TO authenticated
    USING (
        to_email = auth.jwt() ->> 'email'
    );

-- Add comments for documentation
COMMENT ON TABLE public.email_queue IS 'Queue for asynchronous email processing';
COMMENT ON COLUMN public.email_queue.email_type IS 'Type of email: welcome, parental_consent, book_completion, payment_success, etc.';
COMMENT ON COLUMN public.email_queue.to_email IS 'Recipient email address';
COMMENT ON COLUMN public.email_queue.email_data IS 'JSON data for email template';
COMMENT ON COLUMN public.email_queue.status IS 'Job status: pending, processing, completed, failed';
COMMENT ON COLUMN public.email_queue.priority IS 'Priority level (1-10, 1 is highest)';
COMMENT ON COLUMN public.email_queue.retry_count IS 'Number of retry attempts';
COMMENT ON COLUMN public.email_queue.max_retries IS 'Maximum number of retries before giving up';
COMMENT ON COLUMN public.email_queue.scheduled_for IS 'Schedule email for future delivery (optional)';
COMMENT ON COLUMN public.email_queue.last_error IS 'Last error message if failed';
COMMENT ON COLUMN public.email_queue.result IS 'Result from email service';
COMMENT ON COLUMN public.email_queue.completed_at IS 'Timestamp when email was successfully sent';
COMMENT ON COLUMN public.email_queue.failed_at IS 'Timestamp when email permanently failed';

-- Grant permissions
GRANT ALL ON public.email_queue TO service_role;
GRANT SELECT ON public.email_queue TO authenticated;

