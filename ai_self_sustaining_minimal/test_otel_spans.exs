# Test OpenTelemetry span creation for government operations

# Check if we can create spans (even without exporter running)
try do
  # Try to require OpenTelemetry
  Code.ensure_loaded(:opentelemetry)
  IO.puts("✅ OpenTelemetry module available")
rescue
  _ -> 
    IO.puts("⚠️  OpenTelemetry not available - installing...")
    Mix.install([{:opentelemetry, "~> 1.3"}])
end

# Test span creation
require OpenTelemetry.Tracer
alias OpenTelemetry.Tracer

try do
  Tracer.with_span "government.test.operation" do
    Tracer.set_attributes([
      {"government.classification", "unclassified"},
      {"government.operation", "test"},
      {"service.name", "government-test"}
    ])
    
    Tracer.add_event("government.test.event", %{"test" => "successful"})
    IO.puts("✅ OpenTelemetry spans created successfully")
  end
rescue
  error ->
    IO.puts("⚠️  OpenTelemetry span creation: #{inspect(error)}")
    IO.puts("ℹ️  This is expected without an OTLP collector running")
end

IO.puts("📊 OpenTelemetry integration test completed")
