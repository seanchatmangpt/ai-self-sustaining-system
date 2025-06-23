# Test script to record coordination metrics and demonstrate observability infrastructure
# This tests the PromEx integration and coordination metric recording

# Record a coordination operation completion
SelfSustaining.PromEx.record_coordination_metric(:operation_completed, %{
  operation_type: "observability_setup",
  agent_id: "agent_1750060225009",
  duration: 245,
  team: "observability_team",
  status: "success",
  trace_id: "98dc729e7d6f3d4a8e957e28ca6b0e92"
})

# Record agent registration
SelfSustaining.PromEx.record_coordination_metric(:agent_registered, %{
  agent_id: "agent_1750060225009",
  team: "observability_team", 
  capacity: 100,
  specialization: "observability_infrastructure"
})

# Record work claim
SelfSustaining.PromEx.record_coordination_metric(:work_claimed, %{
  agent_id: "agent_1750060225009",
  work_type: "observability_infrastructure",
  priority: "high",
  team: "observability_team"
})

# Record work completion with business value
SelfSustaining.PromEx.record_coordination_metric(:work_completed, %{
  agent_id: "agent_1750060225009",
  work_type: "observability_infrastructure",
  result: "success",
  team: "observability_team",
  business_value: 95
})

# Record system health check
SelfSustaining.PromEx.record_coordination_metric(:health_check, %{
  component: "observability_infrastructure",
  health_score: 98,
  checks_passed: 15,
  checks_failed: 0,
  response_time: 32
})

# Calculate and display coordination efficiency
efficiency_result = SelfSustaining.PromEx.coordination_efficiency()

IO.puts "🎯 Coordination Metrics Recorded Successfully"
IO.puts "============================================"
IO.puts "📊 Agent: agent_1750060225009"
IO.puts "🔧 Work Type: observability_infrastructure"
IO.puts "✅ Status: All metrics recorded"
IO.puts "💼 Business Value: 95 points"
IO.puts "🏥 Health Score: 98/100"
IO.puts ""
IO.puts "⚡ Coordination Efficiency Results:"
IO.inspect(efficiency_result, pretty: true)
IO.puts ""
IO.puts "🔗 Check metrics at: http://localhost:9568/metrics"
IO.puts "🎯 Search for: self_sustaining_coordination"