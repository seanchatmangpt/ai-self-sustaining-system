defmodule XavosWeb.TraceFlowLive do
  use XavosWeb, :live_view
  use LiveVue.Components
  
  require Logger
  
  alias Xavos.TraceFlowReactor

  @impl true
  def mount(_params, _session, socket) do
    # Initialize trace flow state
    socket = 
      socket
      |> assign(:current_trace_id, nil)
      |> assign(:is_running, false)
      |> assign(:steps, initialize_steps())
      |> assign(:trace_history, [])
      |> assign(:error_message, nil)
    
    Logger.info("TraceFlowLive mounted")
    
    {:ok, socket}
  end

  @impl true
  def handle_event("startTrace", _params, socket) do
    if socket.assigns.is_running do
      {:noreply, socket}
    else
      trace_id = generate_trace_id()
      
      Logger.info("Starting new trace flow", trace_id: trace_id)
      
      # Reset steps and start the trace
      socket = 
        socket
        |> assign(:current_trace_id, trace_id)
        |> assign(:is_running, true)
        |> assign(:steps, initialize_steps())
        |> assign(:error_message, nil)
      
      # Start the trace flow asynchronously
      Task.start(fn -> execute_trace_flow(trace_id, self()) end)
      
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("resetTrace", _params, socket) do
    Logger.info("Resetting trace flow")
    
    socket = 
      socket
      |> assign(:current_trace_id, nil)
      |> assign(:is_running, false)
      |> assign(:steps, initialize_steps())
      |> assign(:error_message, nil)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("stepClick", %{"stepId" => step_id}, socket) do
    Logger.info("Step clicked", step_id: step_id)
    # Handle step click - could show details, logs, etc.
    {:noreply, socket}
  end

  @impl true
  def handle_info({:trace_step_update, step_id, status, data}, socket) do
    Logger.info("Received trace step update", step_id: step_id, status: status)
    
    updated_steps = update_step_status(socket.assigns.steps, step_id, status, data)
    
    socket = assign(socket, :steps, updated_steps)
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:trace_complete, final_data}, socket) do
    Logger.info("Trace flow completed", trace_id: socket.assigns.current_trace_id)
    
    # Add to history
    trace_record = %{
      trace_id: socket.assigns.current_trace_id,
      completed_at: DateTime.utc_now(),
      final_data: final_data,
      steps: socket.assigns.steps
    }
    
    updated_history = [trace_record | socket.assigns.trace_history] |> Enum.take(10)
    
    socket = 
      socket
      |> assign(:is_running, false)
      |> assign(:trace_history, updated_history)
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:trace_error, error_message}, socket) do
    Logger.error("Trace flow error", error: error_message, trace_id: socket.assigns.current_trace_id)
    
    socket = 
      socket
      |> assign(:is_running, false)
      |> assign(:error_message, error_message)
    
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12">
      <div class="max-w-6xl mx-auto px-4">
        <!-- Header -->
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            XAVOS Distributed Trace Flow
          </h1>
          <p class="text-lg text-gray-600 mb-2">
            Demonstrating trace propagation across Reactor → n8n → Reactor → LiveVue → Reactor
          </p>
          <p class="text-sm text-gray-500">
            OpenTelemetry distributed tracing with Vue.js visualization
          </p>
        </div>
        
        <!-- Error Display -->
        <div :if={@error_message} class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
          <div class="flex items-center">
            <span class="text-red-600 mr-2">❌</span>
            <span class="text-red-800 font-medium">Trace Error:</span>
          </div>
          <p class="text-red-700 mt-1"><%= @error_message %></p>
        </div>
        
        <!-- Main Trace Flow Component -->
        <div class="grid gap-8 lg:grid-cols-3">
          <!-- Trace Flow Visualization -->
          <div class="lg:col-span-2">
            <.TraceFlow 
              v-socket={@socket}
              currentTraceId={@current_trace_id}
              steps={@steps}
              isRunning={@is_running}
              v-on:startTrace={%JS{} |> JS.push("startTrace")}
              v-on:resetTrace={%JS{} |> JS.push("resetTrace")}
              v-on:stepClick={%JS{} |> JS.push("stepClick")}
            />
          </div>
          
          <!-- System Information -->
          <div class="space-y-6">
            <!-- Current Status -->
            <div class="bg-white rounded-lg shadow border border-gray-200 p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">System Status</h3>
              
              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Status:</span>
                  <span class={if @is_running, do: "text-blue-600 font-medium", else: "text-gray-900"}>
                    <%= if @is_running, do: "Running", else: "Idle" %>
                  </span>
                </div>
                
                <div class="flex justify-between">
                  <span class="text-gray-600">Current Trace:</span>
                  <span class="font-mono text-xs">
                    <%= @current_trace_id || "None" %>
                  </span>
                </div>
                
                <div class="flex justify-between">
                  <span class="text-gray-600">Completed Steps:</span>
                  <span class="text-gray-900">
                    <%= Enum.count(@steps, fn step -> step.status == "completed" end) %> / <%= length(@steps) %>
                  </span>
                </div>
                
                <div class="flex justify-between">
                  <span class="text-gray-600">Total Traces:</span>
                  <span class="text-gray-900"><%= length(@trace_history) %></span>
                </div>
              </div>
            </div>
            
            <!-- Systems Architecture -->
            <div class="bg-white rounded-lg shadow border border-gray-200 p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Architecture</h3>
              
              <div class="space-y-4">
                <div class="flex items-center space-x-3">
                  <div class="w-3 h-3 bg-blue-500 rounded-full"></div>
                  <div>
                    <div class="font-medium text-sm">Reactor (Elixir)</div>
                    <div class="text-xs text-gray-600">Workflow orchestration</div>
                  </div>
                </div>
                
                <div class="flex items-center space-x-3">
                  <div class="w-3 h-3 bg-green-500 rounded-full"></div>
                  <div>
                    <div class="font-medium text-sm">n8n (External)</div>
                    <div class="text-xs text-gray-600">Workflow automation</div>
                  </div>
                </div>
                
                <div class="flex items-center space-x-3">
                  <div class="w-3 h-3 bg-purple-500 rounded-full"></div>
                  <div>
                    <div class="font-medium text-sm">LiveVue (Frontend)</div>
                    <div class="text-xs text-gray-600">Vue.js in LiveView</div>
                  </div>
                </div>
                
                <div class="flex items-center space-x-3">
                  <div class="w-3 h-3 bg-orange-500 rounded-full"></div>
                  <div>
                    <div class="font-medium text-sm">OpenTelemetry</div>
                    <div class="text-xs text-gray-600">Distributed tracing</div>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Trace History -->
            <div :if={length(@trace_history) > 0} class="bg-white rounded-lg shadow border border-gray-200 p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Recent Traces</h3>
              
              <div class="space-y-2 max-h-64 overflow-y-auto">
                <div 
                  :for={trace <- @trace_history} 
                  class="p-3 bg-gray-50 rounded border text-sm"
                >
                  <div class="font-mono text-xs text-gray-600 truncate">
                    <%= trace.trace_id %>
                  </div>
                  <div class="text-xs text-gray-500">
                    <%= Calendar.strftime(trace.completed_at, "%H:%M:%S") %>
                  </div>
                  <div class="text-xs text-green-600 mt-1">
                    ✅ Completed successfully
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Technical Details -->
        <div class="mt-12 grid gap-6 md:grid-cols-2">
          <!-- Implementation Details -->
          <div class="bg-white rounded-lg shadow border border-gray-200 p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Implementation Features</h3>
            
            <ul class="space-y-2 text-sm text-gray-700">
              <li class="flex items-center">
                <span class="text-green-500 mr-2">✓</span>
                OpenTelemetry trace propagation
              </li>
              <li class="flex items-center">
                <span class="text-green-500 mr-2">✓</span>
                Reactor workflow orchestration
              </li>
              <li class="flex items-center">
                <span class="text-green-500 mr-2">✓</span>
                n8n HTTP integration with trace headers
              </li>
              <li class="flex items-center">
                <span class="text-green-500 mr-2">✓</span>
                Vue.js real-time visualization
              </li>
              <li class="flex items-center">
                <span class="text-green-500 mr-2">✓</span>
                LiveView server-side coordination
              </li>
              <li class="flex items-center">
                <span class="text-green-500 mr-2">✓</span>
                Error handling and fallback logic
              </li>
            </ul>
          </div>
          
          <!-- Telemetry Events -->
          <div class="bg-white rounded-lg shadow border border-gray-200 p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Telemetry Events</h3>
            
            <ul class="space-y-2 text-sm text-gray-700">
              <li class="flex items-center">
                <span class="text-blue-500 mr-2">📊</span>
                <code class="text-xs">xavos.trace_flow.complete</code>
              </li>
              <li class="flex items-center">
                <span class="text-blue-500 mr-2">📊</span>
                <code class="text-xs">reactor.execution.start</code>
              </li>
              <li class="flex items-center">
                <span class="text-blue-500 mr-2">📊</span>
                <code class="text-xs">reactor.step.complete</code>
              </li>
              <li class="flex items-center">
                <span class="text-blue-500 mr-2">📊</span>
                <code class="text-xs">http.client.request</code>
              </li>
              <li class="flex items-center">
                <span class="text-blue-500 mr-2">📊</span>
                <code class="text-xs">livevue.component.render</code>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp initialize_steps do
    [
      %{
        id: "step_1",
        name: "Initialize Trace (Reactor)",
        status: "pending",
        timestamp: nil,
        duration: nil,
        data: nil
      },
      %{
        id: "step_2", 
        name: "Call n8n Workflow",
        status: "pending",
        timestamp: nil,
        duration: nil,
        data: nil
      },
      %{
        id: "step_3",
        name: "Process n8n Response (Reactor)", 
        status: "pending",
        timestamp: nil,
        duration: nil,
        data: nil
      },
      %{
        id: "step_4",
        name: "Prepare LiveVue Data",
        status: "pending", 
        timestamp: nil,
        duration: nil,
        data: nil
      },
      %{
        id: "step_5",
        name: "Finalize Trace (Reactor)",
        status: "pending",
        timestamp: nil, 
        duration: nil,
        data: nil
      }
    ]
  end

  defp update_step_status(steps, step_id, status, data) do
    Enum.map(steps, fn step ->
      if step.id == step_id do
        %{step | 
          status: status,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          duration: Map.get(data, :duration),
          data: data
        }
      else
        step
      end
    end)
  end

  defp generate_trace_id do
    "xavos-trace-" <> 
    (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)) <>
    "-" <> 
    (System.system_time(:millisecond) |> to_string())
  end

  defp execute_trace_flow(trace_id, live_view_pid) do
    try do
      Logger.info("Executing trace flow", trace_id: trace_id)
      
      # Emit telemetry for trace flow execution
      :telemetry.execute([:xavos, :trace_flow, :execution, :start], %{
        trace_id: trace_id,
        trace_type: "distributed",
        systems: "reactor,n8n,livevue",
        timestamp: System.system_time(:microsecond)
      }, %{})
        
        # Execute the reactor workflow
        context = %{
          trace_id: trace_id,
          trace_start_time: System.monotonic_time(),
          live_view_pid: live_view_pid
        }
        
        case Reactor.run(TraceFlowReactor, %{trace_id: trace_id}, context) do
          {:ok, result} ->
            Logger.info("Trace flow completed successfully", trace_id: trace_id)
            
            # Emit success telemetry
            :telemetry.execute([:xavos, :trace_flow, :execution, :complete], %{
              trace_id: trace_id,
              status: "success",
              timestamp: System.system_time(:microsecond)
            }, %{result: result})
            
            send(live_view_pid, {:trace_complete, result})
            
          {:error, reason} ->
            Logger.error("Trace flow failed", trace_id: trace_id, reason: reason)
            
            # Emit error telemetry
            :telemetry.execute([:xavos, :trace_flow, :execution, :error], %{
              trace_id: trace_id,
              error: inspect(reason),
              timestamp: System.system_time(:microsecond)
            }, %{})
            
            send(live_view_pid, {:trace_error, "Trace execution failed: #{inspect(reason)}"})
        end
    rescue
      error ->
        Logger.error("Trace flow exception", trace_id: trace_id, error: Exception.message(error))
        send(live_view_pid, {:trace_error, "Trace execution exception: #{Exception.message(error)}"})
    end
  end
end