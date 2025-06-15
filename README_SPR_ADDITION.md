# SPR Compression System - Addition to README.md

Insert this section after line 185 in README.md:

## 🗜️ SPR Compression System

### Sparse Priming Representation (SPR) using Reactor Workflows
The system includes comprehensive SPR compression/decompression running through actual Elixir Reactor workflows:

```bash
# Using Mix tasks (recommended)
cd phoenix_app
mix spr compress document.txt standard 0.1
mix spr decompress document.spr detailed medium
mix spr roundtrip document.txt minimal comprehensive
mix spr validate document.spr
mix spr metrics document.spr

# Using Elixir Reactor CLI directly
elixir spr_reactor_cli.exs compress document.txt standard 0.1
elixir spr_reactor_cli.exs decompress document.spr detailed medium

# Using shell scripts (Reactor integration)
./spr_pipeline.sh compress document.txt standard 0.1
./spr_pipeline.sh decompress document.spr detailed medium
```

### SPR Formats and Compression Ratios
- **minimal**: Ultra-compressed (3-7 words/statement, ~5% of original)
- **standard**: Balanced compression (8-15 words/statement, ~10% of original)  
- **extended**: Context-preserved (10-25 words/statement, ~20% of original)

### Reactor Integration Features
```bash
# All SPR operations include:
# - Nanosecond-precision agent coordination
# - OpenTelemetry distributed tracing  
# - Full telemetry integration and monitoring
# - Atomic state transitions with compensation logic
# - Integration with existing agent coordination system

# View trace information
mix spr compress document.txt standard 0.1 | grep "Trace ID"
```

### Unix-Style Pipeline Support
```bash
# Pipe content through SPR compression (via Reactor)
echo "Complex text content..." | ./spr_compress.sh /dev/stdin minimal 0.2

# Chain with other Unix tools
find . -name "*.txt" -exec ./spr_pipeline.sh compress {} standard 0.1 \;

# Real-time SPR processing
tail -f logs.txt | ./spr_compress.sh /dev/stdin minimal 0.15
```

### SPR Integration Components
- `phoenix_app/lib/mix/tasks/spr.ex` - Mix task for Reactor-based SPR operations
- `spr_reactor_cli.exs` - Direct Elixir CLI using actual Reactor workflows
- `spr_compress.sh` - Shell wrapper that executes Reactor workflows
- `spr_decompress.sh` - Shell wrapper for SPR decompression via Reactor
- `spr_pipeline.sh` - Complete SPR workflow management
- `test_spr_cli.sh` - Test suite for SPR CLI functionality

### Core Reactor Workflows
The SPR system uses these actual Reactor workflows:
- **SelfSustaining.Workflows.SPRCompressionReactor** - 7-stage compression pipeline
- **Agent Coordination**: Nanosecond-precision work claiming and tracking
- **Telemetry Middleware**: OpenTelemetry tracing for all SPR operations
- **Compensation Logic**: Automatic error handling and rollback mechanisms

### Performance and Monitoring
```bash
# View SPR operation telemetry
curl http://localhost:4000/api/telemetry/spans | grep spr-compression

# Monitor agent coordination for SPR tasks
curl http://localhost:4000/api/coordination/status | grep spr

# Track SPR performance metrics
mix spr metrics document.spr
```

---

Also update the key directories section to include:

```
- **SPR Compression System** - Reactor-based compression/decompression
  - `phoenix_app/lib/mix/tasks/spr.ex` - Mix task integration
  - `spr_reactor_cli.exs` - Direct Reactor CLI interface
  - `spr_compress.sh` - Shell wrapper using Reactor workflows
  - `spr_decompress.sh` - Shell wrapper for decompression
  - `spr_pipeline.sh` - Complete workflow management
  - `test_spr_cli.sh` - SPR CLI test suite
  - `phoenix_app/lib/self_sustaining/workflows/spr_compression_reactor.ex` - Core Reactor workflow
```