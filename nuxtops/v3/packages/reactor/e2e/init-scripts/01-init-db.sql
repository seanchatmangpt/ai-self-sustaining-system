-- E2E Test Database Initialization
-- Create reactor-specific schemas and test data

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create reactor execution tracking table
CREATE TABLE IF NOT EXISTS reactor_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reactor_id VARCHAR(255) NOT NULL,
    execution_id VARCHAR(255) NOT NULL UNIQUE,
    state VARCHAR(50) NOT NULL,
    input_data JSONB,
    output_data JSONB,
    error_data JSONB,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,
    step_count INTEGER DEFAULT 0,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create reactor step tracking table
CREATE TABLE IF NOT EXISTS reactor_steps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    execution_id UUID REFERENCES reactor_executions(id) ON DELETE CASCADE,
    step_name VARCHAR(255) NOT NULL,
    step_order INTEGER NOT NULL,
    state VARCHAR(50) NOT NULL,
    input_data JSONB,
    output_data JSONB,
    error_data JSONB,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,
    retry_count INTEGER DEFAULT 0,
    compensation_applied BOOLEAN DEFAULT FALSE,
    telemetry_span_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create performance metrics table
CREATE TABLE IF NOT EXISTS reactor_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    execution_id UUID REFERENCES reactor_executions(id) ON DELETE CASCADE,
    metric_name VARCHAR(255) NOT NULL,
    metric_value NUMERIC NOT NULL,
    metric_unit VARCHAR(50),
    metric_tags JSONB,
    measured_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create test scenarios table
CREATE TABLE IF NOT EXISTS test_scenarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scenario_name VARCHAR(255) NOT NULL UNIQUE,
    scenario_type VARCHAR(100) NOT NULL,
    priority VARCHAR(20) DEFAULT 'medium',
    coverage_category VARCHAR(50) NOT NULL, -- 'critical_80' or 'edge_20'
    expected_outcome VARCHAR(100),
    test_data JSONB,
    validation_rules JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create test execution results table
CREATE TABLE IF NOT EXISTS test_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scenario_id UUID REFERENCES test_scenarios(id) ON DELETE CASCADE,
    execution_id UUID REFERENCES reactor_executions(id) ON DELETE CASCADE,
    test_run_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    assertions_passed INTEGER DEFAULT 0,
    assertions_failed INTEGER DEFAULT 0,
    performance_score NUMERIC,
    memory_usage_mb NUMERIC,
    execution_time_ms INTEGER,
    error_details JSONB,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_reactor_executions_reactor_id ON reactor_executions(reactor_id);
CREATE INDEX IF NOT EXISTS idx_reactor_executions_state ON reactor_executions(state);
CREATE INDEX IF NOT EXISTS idx_reactor_executions_started_at ON reactor_executions(started_at);
CREATE INDEX IF NOT EXISTS idx_reactor_steps_execution_id ON reactor_steps(execution_id);
CREATE INDEX IF NOT EXISTS idx_reactor_steps_step_name ON reactor_steps(step_name);
CREATE INDEX IF NOT EXISTS idx_reactor_steps_state ON reactor_steps(state);
CREATE INDEX IF NOT EXISTS idx_reactor_metrics_execution_id ON reactor_metrics(execution_id);
CREATE INDEX IF NOT EXISTS idx_reactor_metrics_metric_name ON reactor_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_test_scenarios_coverage_category ON test_scenarios(coverage_category);
CREATE INDEX IF NOT EXISTS idx_test_executions_test_run_id ON test_executions(test_run_id);
CREATE INDEX IF NOT EXISTS idx_test_executions_status ON test_executions(status);

-- Insert 80/20 test scenarios
INSERT INTO test_scenarios (scenario_name, scenario_type, priority, coverage_category, expected_outcome, test_data, validation_rules) VALUES
-- Critical 80% scenarios
('basic_input_output', 'functional', 'high', 'critical_80', 'completed', 
 '{"input": "test_data", "expected_steps": 3}', 
 '{"min_duration_ms": 1, "max_duration_ms": 100, "required_state": "completed"}'),

('parallel_processing', 'performance', 'high', 'critical_80', 'completed',
 '{"concurrent_tasks": 5, "data_size": 1000}',
 '{"min_duration_ms": 10, "max_duration_ms": 200, "min_throughput": 100}'),

('error_recovery', 'resilience', 'high', 'critical_80', 'completed',
 '{"failure_mode": "retry", "max_retries": 3}',
 '{"compensation_applied": true, "final_state": "completed"}'),

('resource_management', 'performance', 'high', 'critical_80', 'completed',
 '{"memory_limit_mb": 100, "concurrent_limit": 10}',
 '{"max_memory_mb": 100, "no_memory_leaks": true}'),

-- Edge 20% scenarios
('memory_stress', 'stress', 'medium', 'edge_20', 'completed',
 '{"data_size": 1000000, "concurrent_tasks": 20}',
 '{"max_memory_mb": 500, "max_duration_ms": 10000}'),

('cascading_failure', 'resilience', 'medium', 'edge_20', 'failed',
 '{"failure_cascade": true, "recovery_mode": "compensation"}',
 '{"compensation_count": 3, "rollback_success": true}'),

('timeout_exhaustion', 'stress', 'low', 'edge_20', 'failed',
 '{"timeout_ms": 100, "slow_tasks": true}',
 '{"timeout_triggered": true, "cleanup_successful": true}'),

('high_concurrency', 'performance', 'medium', 'edge_20', 'completed',
 '{"concurrent_tasks": 100, "resource_contention": true}',
 '{"no_deadlocks": true, "fair_scheduling": true}');

-- Insert performance benchmarks
INSERT INTO reactor_metrics (execution_id, metric_name, metric_value, metric_unit, metric_tags) 
SELECT 
    uuid_generate_v4(), 
    'baseline_performance', 
    value, 
    unit,
    tags::jsonb
FROM (VALUES 
    (100, 'ops_per_second', '{"category": "throughput", "baseline": true}'),
    (50, 'ms', '{"category": "latency", "percentile": "p95", "baseline": true}'),
    (10, 'mb', '{"category": "memory", "type": "heap_used", "baseline": true}'),
    (80, 'percent', '{"category": "coverage", "type": "critical_path", "baseline": true}')
) AS benchmarks(value, unit, tags);

-- Create function to calculate coverage score
CREATE OR REPLACE FUNCTION calculate_coverage_score(test_run_id_param VARCHAR)
RETURNS NUMERIC AS $$
DECLARE
    total_critical INTEGER;
    passed_critical INTEGER;
    total_edge INTEGER;
    passed_edge INTEGER;
    coverage_score NUMERIC;
BEGIN
    -- Count critical scenarios
    SELECT COUNT(*) INTO total_critical
    FROM test_executions te
    JOIN test_scenarios ts ON te.scenario_id = ts.id
    WHERE te.test_run_id = test_run_id_param 
    AND ts.coverage_category = 'critical_80';
    
    SELECT COUNT(*) INTO passed_critical
    FROM test_executions te
    JOIN test_scenarios ts ON te.scenario_id = ts.id
    WHERE te.test_run_id = test_run_id_param 
    AND ts.coverage_category = 'critical_80' 
    AND te.status = 'passed';
    
    -- Count edge scenarios
    SELECT COUNT(*) INTO total_edge
    FROM test_executions te
    JOIN test_scenarios ts ON te.scenario_id = ts.id
    WHERE te.test_run_id = test_run_id_param 
    AND ts.coverage_category = 'edge_20';
    
    SELECT COUNT(*) INTO passed_edge
    FROM test_executions te
    JOIN test_scenarios ts ON te.scenario_id = ts.id
    WHERE te.test_run_id = test_run_id_param 
    AND ts.coverage_category = 'edge_20' 
    AND te.status = 'passed';
    
    -- Calculate weighted 80/20 score
    IF total_critical > 0 AND total_edge > 0 THEN
        coverage_score := (passed_critical::NUMERIC / total_critical * 0.8) + 
                         (passed_edge::NUMERIC / total_edge * 0.2);
    ELSIF total_critical > 0 THEN
        coverage_score := passed_critical::NUMERIC / total_critical;
    ELSE
        coverage_score := 0;
    END IF;
    
    RETURN ROUND(coverage_score * 100, 2);
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_reactor_executions_timestamp
    BEFORE UPDATE ON reactor_executions
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_test_scenarios_timestamp
    BEFORE UPDATE ON test_scenarios
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO reactor_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO reactor_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO reactor_user;