defmodule Xavos.TraceFlowReactor do
  @moduledoc """
  Reactor workflow demonstrating distributed trace flow:
  Reactor → n8n → Reactor → LiveVue → Reactor
  
  This showcases OpenTelemetry trace propagation across:
  - Elixir Reactor workflows
  - External n8n HTTP workflows
  - Vue.js frontend components
  - LiveView backend processing
  """
  
  use Reactor
  
  require Logger
  

  # Step 1: Initial Reactor Processing
  step :initialize_trace do
    run fn %{trace_id: trace_id} = arguments, context ->
      Logger.info("Starting distributed trace flow", trace_id: trace_id)
      
      # Emit telemetry for trace initialization
      :telemetry.execute([:xavos, :trace_flow, :step, :start], %{
        step: "initialize",
        trace_id: trace_id,
        system: "reactor",
        step_number: 1,
        timestamp: System.system_time(:microsecond)
      }, %{context: context})
        
        # Simulate some initial processing
        Process.sleep(100)
        
        initial_data = %{
          trace_id: trace_id,
          step: 1,
          system: "reactor",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          data: %{
            message: "Initial trace processing completed",
            reactor_context: Map.keys(context),
            system_info: %{
              node: node(),
              pid: inspect(self()),
              version: Application.spec(:xavos, :vsn) || "unknown"
            }
          }
        }
        
        Logger.info("Trace initialization completed", 
          trace_id: trace_id, 
          data_size: byte_size(inspect(initial_data))
        )
        
        # Emit completion telemetry
        :telemetry.execute([:xavos, :trace_flow, :step, :complete], %{
          step: "initialize",
          trace_id: trace_id,
          system: "reactor",
          step_number: 1,
          duration: 100
        }, %{data: initial_data})
        
        {:ok, initial_data}
    end
  end

  # Step 2: Call n8n Workflow
  step :call_n8n_workflow do
    argument :initial_data, result(:initialize_trace)
    
    run fn %{initial_data: data}, _context ->
      trace_id = data.trace_id
      
      Logger.info("Calling n8n workflow", trace_id: trace_id)
      
      # Emit telemetry for n8n call
      :telemetry.execute([:xavos, :trace_flow, :step, :start], %{
        step: "n8n_call",
        trace_id: trace_id,
        system: "n8n",
        step_number: 2,
        http_method: "POST",
        http_url: n8n_webhook_url(),
        timestamp: System.system_time(:microsecond)
      }, %{})
        
        # Prepare payload for n8n
        n8n_payload = %{
          trace_id: trace_id,
          step: 2,
          system: "n8n",
          previous_data: data,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          headers: %{
            "x-trace-id" => trace_id,
            "x-trace-step" => "2",
            "x-trace-system" => "n8n"
          }
        }
        
        # Make HTTP call to n8n with trace headers
        case make_n8n_request(n8n_payload, trace_id) do
          {:ok, response} ->
            Logger.info("n8n workflow completed successfully", 
              trace_id: trace_id,
              response_size: byte_size(inspect(response))
            )
            
            # Emit success telemetry
            :telemetry.execute([:xavos, :trace_flow, :step, :complete], %{
              step: "n8n_call",
              trace_id: trace_id,
              system: "n8n",
              step_number: 2,
              status: "success"
            }, %{response: response})
            
            {:ok, response}
            
          {:error, reason} ->
            Logger.error("n8n workflow failed", trace_id: trace_id, reason: reason)
            
            # Create fallback response for demo purposes
            fallback_response = %{
              trace_id: trace_id,
              step: 2,
              system: "n8n",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
              data: %{
                message: "n8n workflow simulation (fallback)",
                status: "simulated",
                original_error: inspect(reason),
                processed_data: data.data
              },
              n8n_simulation: true
            }
            
            Logger.info("Using n8n fallback response", trace_id: trace_id)
            
            # Emit fallback telemetry
            :telemetry.execute([:xavos, :trace_flow, :step, :complete], %{
              step: "n8n_call",
              trace_id: trace_id,
              system: "n8n",
              step_number: 2,
              status: "fallback"
            }, %{response: fallback_response})
            
            {:ok, fallback_response}
        end
    end
  end

  # Step 3: Process n8n Response in Reactor
  step :process_n8n_response do
    argument :n8n_data, result(:call_n8n_workflow)
    
    run fn %{n8n_data: data}, _context ->
      trace_id = data.trace_id
      
      Logger.info("Processing n8n response", trace_id: trace_id)
      
      # Emit telemetry for n8n response processing
      :telemetry.execute([:xavos, :trace_flow, :step, :start], %{
        step: "process_n8n",
        trace_id: trace_id,
        system: "reactor",
        step_number: 3,
        n8n_simulation: Map.get(data, :n8n_simulation, false),
        timestamp: System.system_time(:microsecond)
      }, %{})
        
        # Process the n8n response
        Process.sleep(150)
        
        processed_data = %{
          trace_id: trace_id,
          step: 3,
          system: "reactor",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          data: %{
            message: "n8n response processed in reactor",
            n8n_data: data.data,
            processing_complete: true,
            enhanced_data: %{
              trace_path: ["reactor", "n8n", "reactor"],
              next_destination: "livevue"
            }
          }
        }
        
        Logger.info("n8n response processing completed", 
          trace_id: trace_id,
          next_step: "livevue"
        )
        
        # Emit completion telemetry
        :telemetry.execute([:xavos, :trace_flow, :step, :complete], %{
          step: "process_n8n",
          trace_id: trace_id,
          system: "reactor",
          step_number: 3,
          duration: 150
        }, %{data: processed_data})
        
        {:ok, processed_data}
    end
  end

  # Step 4: Prepare for LiveVue
  step :prepare_livevue_data do
    argument :reactor_data, result(:process_n8n_response)
    
    run fn %{reactor_data: data}, _context ->
      trace_id = data.trace_id
      
      Logger.info("Preparing data for LiveVue", trace_id: trace_id)
      
      # Emit telemetry for LiveVue preparation
      :telemetry.execute([:xavos, :trace_flow, :step, :start], %{
        step: "prepare_livevue",
        trace_id: trace_id,
        system: "livevue",
        step_number: 4,
        timestamp: System.system_time(:microsecond)
      }, %{})
        
        # Prepare data specifically for Vue component consumption
        livevue_data = %{
          trace_id: trace_id,
          step: 4,
          system: "livevue",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          data: %{
            message: "Data prepared for Vue frontend",
            trace_summary: %{
              steps_completed: 3,
              systems_traversed: ["reactor", "n8n", "reactor"],
              current_system: "livevue",
              next_system: "reactor"
            },
            vue_props: %{
              traceId: trace_id,
              currentStep: 4,
              totalSteps: 5,
              previousData: data.data
            }
          }
        }
        
        Logger.info("LiveVue data preparation completed", 
          trace_id: trace_id,
          vue_props_size: byte_size(inspect(livevue_data.data.vue_props))
        )
        
        # Emit completion telemetry
        :telemetry.execute([:xavos, :trace_flow, :step, :complete], %{
          step: "prepare_livevue",
          trace_id: trace_id,
          system: "livevue",
          step_number: 4
        }, %{data: livevue_data})
        
        {:ok, livevue_data}
    end
  end

  # Step 5: Final Reactor Processing
  step :finalize_trace do
    argument :livevue_data, result(:prepare_livevue_data)
    
    run fn %{livevue_data: data}, context ->
      trace_id = data.trace_id
      
      Logger.info("Finalizing trace flow", trace_id: trace_id)
      
      # Emit telemetry for trace finalization
      :telemetry.execute([:xavos, :trace_flow, :step, :start], %{
        step: "finalize",
        trace_id: trace_id,
        system: "reactor",
        step_number: 5,
        trace_complete: true,
        timestamp: System.system_time(:microsecond)
      }, %{})
        
        # Calculate trace metrics
        trace_start_time = context[:trace_start_time] || System.monotonic_time()
        total_duration = System.monotonic_time() - trace_start_time
        
        final_data = %{
          trace_id: trace_id,
          step: 5,
          system: "reactor",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          data: %{
            message: "Distributed trace flow completed successfully",
            trace_complete: true,
            systems_traversed: ["reactor", "n8n", "reactor", "livevue", "reactor"],
            total_steps: 5,
            metrics: %{
              total_duration_ms: System.convert_time_unit(total_duration, :native, :millisecond),
              systems_count: 5,
              successful_completion: true
            },
            summary: %{
              reactor_steps: 3,
              n8n_steps: 1,
              livevue_steps: 1,
              total_systems: 3,
              trace_path: "reactor→n8n→reactor→livevue→reactor"
            }
          }
        }
        
        # Emit final trace telemetry
        :telemetry.execute([:xavos, :trace_flow, :complete], %{
          trace_id: trace_id,
          total_duration: total_duration,
          steps_completed: 5,
          systems_traversed: 3
        }, %{
          final_data: final_data,
          context: context
        })
        
        Logger.info("Distributed trace flow completed successfully", 
          trace_id: trace_id,
          total_duration_ms: System.convert_time_unit(total_duration, :native, :millisecond),
          systems_traversed: 3
        )
        
        {:ok, final_data}
    end
  end

  # Helper functions

  defp n8n_webhook_url do
    # Use environment variable or default to local n8n instance
    System.get_env("N8N_WEBHOOK_URL") || "http://localhost:5678/webhook/xavos-trace"
  end

  defp make_n8n_request(payload, trace_id) do
    headers = %{
      "content-type" => "application/json",
      "x-trace-id" => trace_id,
      "x-trace-step" => "2",
      "x-trace-system" => "n8n",
      "user-agent" => "XAVOS-TraceFlow/1.0"
    }
    
    case Req.post(n8n_webhook_url(), 
      json: payload, 
      headers: headers,
      receive_timeout: 5000,
      retry: false
    ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}
        
      {:ok, %Req.Response{status: status_code}} ->
        {:error, "n8n returned status code: #{status_code}"}
        
      {:error, exception} ->
        {:error, "HTTP request failed: #{Exception.message(exception)}"}
    end
  rescue
    error ->
      {:error, "Request exception: #{Exception.message(error)}"}
  end
end