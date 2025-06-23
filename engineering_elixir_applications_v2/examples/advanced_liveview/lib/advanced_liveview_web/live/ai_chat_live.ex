defmodule AdvancedLiveViewWeb.AiChatLive do
  @moduledoc """
  Advanced LiveView demonstrating v2 patterns:
  - AI integration with streaming responses
  - Real-time collaboration
  - Advanced state management
  - Component composition
  - Performance optimization
  - OpenTelemetry integration
  """
  
  use AdvancedLiveViewWeb, :live_view
  use OpenTelemetry.Tracer
  
  alias AdvancedLiveView.{AI, Telemetry, PubSub}
  alias AdvancedLiveViewWeb.{ChatComponents, Presence}
  
  require Logger

  @impl true
  def mount(_params, %{"user_id" => user_id} = _session, socket) do
    with_span "ai_chat_live_mount" do
      if connected?(socket) do
        # Subscribe to chat updates and user presence
        Phoenix.PubSub.subscribe(AdvancedLiveView.PubSub, "chat_room")
        Phoenix.PubSub.subscribe(AdvancedLiveView.PubSub, "ai_responses")
        
        # Track user presence
        Presence.track(self(), "chat_room", user_id, %{
          online_at: inspect(System.system_time(:second)),
          typing: false
        })
      end

      {:ok,
       socket
       |> assign_defaults()
       |> assign(:user_id, user_id)
       |> assign(:chat_id, generate_chat_id())
       |> assign(:messages, [])
       |> assign(:typing_users, %{})
       |> assign(:ai_thinking, false)
       |> assign(:stream_buffer, "")
       |> assign(:performance_metrics, init_performance_metrics())
       |> assign(:ai_model, "claude-3-sonnet")
       |> assign(:context_window, [])}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    with_span "send_message", %{content_length: String.length(content)} do
      start_time = System.monotonic_time()
      
      # Validate and process message
      case validate_message(content) do
        {:ok, processed_content} ->
          message = create_message(socket.assigns.user_id, processed_content)
          
          # Broadcast to other users
          Phoenix.PubSub.broadcast(
            AdvancedLiveView.PubSub,
            "chat_room",
            {:new_message, message}
          )
          
          # Trigger AI response
          spawn(fn -> process_ai_response(socket.assigns.chat_id, message, socket.assigns.ai_model) end)
          
          # Update performance metrics
          processing_time = System.monotonic_time() - start_time
          metrics = update_performance_metrics(socket.assigns.performance_metrics, :message_sent, processing_time)
          
          {:noreply,
           socket
           |> update(:messages, &[message | &1])
           |> assign(:ai_thinking, true)
           |> assign(:performance_metrics, metrics)
           |> push_event("scroll_to_bottom", %{})
           |> put_flash(:info, "Message sent")}
           
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_event("typing", %{"typing" => typing}, socket) do
    # Broadcast typing status
    Phoenix.PubSub.broadcast(
      AdvancedLiveView.PubSub,
      "chat_room",
      {:user_typing, socket.assigns.user_id, typing}
    )
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_ai_model", %{"model" => model}, socket) do
    with_span "change_ai_model", %{model: model} do
      {:noreply, assign(socket, :ai_model, model)}
    end
  end

  @impl true
  def handle_event("export_chat", _params, socket) do
    with_span "export_chat" do
      chat_data = %{
        chat_id: socket.assigns.chat_id,
        messages: socket.assigns.messages,
        exported_at: DateTime.utc_now(),
        performance_metrics: socket.assigns.performance_metrics
      }
      
      # Generate export file
      export_path = generate_export_file(chat_data)
      
      {:noreply,
       socket
       |> push_event("download_file", %{url: export_path, filename: "chat_export.json"})
       |> put_flash(:info, "Chat exported successfully")}
    end
  end

  @impl true
  def handle_event("clear_chat", _params, socket) do
    with_span "clear_chat" do
      Phoenix.PubSub.broadcast(
        AdvancedLiveView.PubSub,
        "chat_room",
        {:chat_cleared, socket.assigns.user_id}
      )
      
      {:noreply,
       socket
       |> assign(:messages, [])
       |> assign(:context_window, [])
       |> put_flash(:info, "Chat cleared")}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, update(socket, :messages, &[message | &1])}
  end

  @impl true
  def handle_info({:ai_response_chunk, chat_id, chunk}, socket) when chat_id == socket.assigns.chat_id do
    # Handle streaming AI response
    updated_buffer = socket.assigns.stream_buffer <> chunk
    
    {:noreply,
     socket
     |> assign(:stream_buffer, updated_buffer)
     |> push_event("update_ai_response", %{content: updated_buffer})}
  end

  @impl true
  def handle_info({:ai_response_complete, chat_id, final_response}, socket) when chat_id == socket.assigns.chat_id do
    with_span "ai_response_complete" do
      ai_message = create_ai_message(final_response)
      
      # Broadcast to other users
      Phoenix.PubSub.broadcast(
        AdvancedLiveView.PubSub,
        "chat_room",
        {:new_message, ai_message}
      )
      
      # Update context window for better AI responses
      updated_context = update_context_window(socket.assigns.context_window, ai_message)
      
      {:noreply,
       socket
       |> update(:messages, &[ai_message | &1])
       |> assign(:ai_thinking, false)
       |> assign(:stream_buffer, "")
       |> assign(:context_window, updated_context)
       |> push_event("ai_response_complete", %{})}
    end
  end

  @impl true
  def handle_info({:user_typing, user_id, typing}, socket) do
    updated_typing = if typing do
      Map.put(socket.assigns.typing_users, user_id, true)
    else
      Map.delete(socket.assigns.typing_users, user_id)
    end
    
    {:noreply, assign(socket, :typing_users, updated_typing)}
  end

  @impl true
  def handle_info({:chat_cleared, _user_id}, socket) do
    {:noreply, assign(socket, :messages, [])}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    # Handle user presence updates
    {:noreply, handle_presence_diff(socket, diff)}
  end

  # Private functions

  defp assign_defaults(socket) do
    socket
    |> assign(:page_title, "AI Chat - Advanced LiveView Demo")
    |> assign(:loading, false)
    |> assign(:error, nil)
  end

  defp generate_chat_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64(padding: false)
  end

  defp validate_message(content) when is_binary(content) do
    content = String.trim(content)
    
    cond do
      String.length(content) == 0 ->
        {:error, "Message cannot be empty"}
      String.length(content) > 4000 ->
        {:error, "Message too long (max 4000 characters)"}
      true ->
        {:ok, content}
    end
  end

  defp create_message(user_id, content) do
    %{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      content: content,
      type: :user,
      timestamp: DateTime.utc_now(),
      metadata: %{
        client_info: %{
          user_agent: "LiveView Client",
          ip_address: "127.0.0.1"
        }
      }
    }
  end

  defp create_ai_message(content) do
    %{
      id: Ecto.UUID.generate(),
      user_id: "ai_assistant",
      content: content,
      type: :ai,
      timestamp: DateTime.utc_now(),
      metadata: %{
        model: "claude-3-sonnet",
        processing_time_ms: 0,
        tokens_used: estimate_tokens(content)
      }
    }
  end

  defp process_ai_response(chat_id, message, model) do
    with_span "process_ai_response", %{chat_id: chat_id, model: model} do
      # Simulate AI processing with streaming
      Phoenix.PubSub.broadcast(
        AdvancedLiveView.PubSub,
        "ai_responses",
        {:ai_response_chunk, chat_id, "I'm thinking about your question..."}
      )
      
      # Simulate streaming response
      response_chunks = [
        "Based on your message: \"#{message.content}\", ",
        "I can provide some insights. ",
        "This is an advanced LiveView demonstration ",
        "showcasing real-time AI integration with ",
        "streaming responses and collaborative features. ",
        "The system uses OpenTelemetry for observability ",
        "and demonstrates modern Elixir patterns."
      ]
      
      Enum.each(response_chunks, fn chunk ->
        Process.sleep(200)  # Simulate processing time
        Phoenix.PubSub.broadcast(
          AdvancedLiveView.PubSub,
          "ai_responses",
          {:ai_response_chunk, chat_id, chunk}
        )
      end)
      
      final_response = Enum.join(response_chunks, "")
      
      Phoenix.PubSub.broadcast(
        AdvancedLiveView.PubSub,
        "ai_responses",
        {:ai_response_complete, chat_id, final_response}
      )
    end
  end

  defp init_performance_metrics do
    %{
      messages_sent: 0,
      ai_responses: 0,
      avg_response_time: 0,
      total_session_time: System.monotonic_time(),
      bandwidth_used: 0
    }
  end

  defp update_performance_metrics(metrics, :message_sent, processing_time) do
    %{metrics |
      messages_sent: metrics.messages_sent + 1,
      avg_response_time: (metrics.avg_response_time + processing_time) / 2
    }
  end

  defp update_context_window(context, new_message) do
    # Keep last 10 messages for context
    [new_message | context]
    |> Enum.take(10)
  end

  defp estimate_tokens(content) do
    # Simple token estimation (roughly 4 characters per token)
    String.length(content) |> div(4)
  end

  defp generate_export_file(chat_data) do
    # In a real app, this would save to a file system or cloud storage
    "/tmp/chat_export_#{chat_data.chat_id}.json"
  end

  defp handle_presence_diff(socket, _diff) do
    # Handle user presence changes
    socket
  end

  # Template rendering would go here in a real implementation
  @impl true
  def render(assigns) do
    ~H"""
    <div class="ai-chat-container h-screen flex flex-col bg-gray-50">
      <!-- Header -->
      <div class="chat-header bg-white shadow-sm border-b p-4">
        <div class="flex items-center justify-between">
          <h1 class="text-xl font-semibold text-gray-800">AI Chat Demo</h1>
          <div class="flex items-center space-x-4">
            <.ai_model_selector model={@ai_model} />
            <.performance_indicator metrics={@performance_metrics} />
            <.export_button />
          </div>
        </div>
      </div>
      
      <!-- Messages Area -->
      <div class="messages-container flex-1 overflow-y-auto p-4 space-y-4">
        <%= for message <- Enum.reverse(@messages) do %>
          <.message_bubble message={message} current_user={@user_id} />
        <% end %>
        
        <%= if @ai_thinking do %>
          <.ai_thinking_indicator buffer={@stream_buffer} />
        <% end %>
      </div>
      
      <!-- Typing Indicators -->
      <%= if map_size(@typing_users) > 0 do %>
        <.typing_indicators users={@typing_users} />
      <% end %>
      
      <!-- Input Area -->
      <div class="input-area bg-white border-t p-4">
        <.live_component
          module={ChatComponents.MessageInput}
          id="message-input"
          on_send={&send_message/1}
          on_typing={&handle_typing/1}
        />
      </div>
    </div>
    """
  end

  # Component functions would be defined here
  defp ai_model_selector(assigns) do
    ~H"""
    <select phx-change="change_ai_model" class="rounded border p-2">
      <option value="claude-3-sonnet" selected={@model == "claude-3-sonnet"}>Claude 3 Sonnet</option>
      <option value="gpt-4" selected={@model == "gpt-4"}>GPT-4</option>
      <option value="gemini-pro" selected={@model == "gemini-pro"}>Gemini Pro</option>
    </select>
    """
  end

  defp performance_indicator(assigns) do
    ~H"""
    <div class="text-sm text-gray-600">
      Messages: <%= @metrics.messages_sent %> | 
      Avg Response: <%= Float.round(@metrics.avg_response_time / 1_000_000, 2) %>ms
    </div>
    """
  end

  defp export_button(assigns) do
    ~H"""
    <button phx-click="export_chat" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">
      Export Chat
    </button>
    """
  end

  defp message_bubble(assigns) do
    ~H"""
    <div class={["message-bubble", message_class(@message.type, @current_user, @message.user_id)]}>
      <div class="message-content">
        <%= @message.content %>
      </div>
      <div class="message-meta text-xs text-gray-500 mt-1">
        <%= format_timestamp(@message.timestamp) %>
        <%= if @message.type == :ai do %>
          | Tokens: <%= @message.metadata.tokens_used %>
        <% end %>
      </div>
    </div>
    """
  end

  defp ai_thinking_indicator(assigns) do
    ~H"""
    <div class="ai-thinking flex items-center space-x-2 text-gray-600">
      <div class="typing-dots">
        <span></span><span></span><span></span>
      </div>
      <span>AI is thinking...</span>
      <%= if @buffer != "" do %>
        <div class="stream-preview text-sm">
          <%= String.slice(@buffer, 0, 50) %><%= if String.length(@buffer) > 50, do: "..." %>
        </div>
      <% end %>
    </div>
    """
  end

  defp typing_indicators(assigns) do
    ~H"""
    <div class="typing-indicators p-2 text-sm text-gray-600">
      <%= for {user_id, _} <- @users do %>
        <span><%= user_id %> is typing...</span>
      <% end %>
    </div>
    """
  end

  defp message_class(:ai, _current_user, _message_user), do: "ai-message bg-blue-100 ml-8"
  defp message_class(:user, current_user, current_user), do: "user-message bg-green-100 mr-8 ml-auto"
  defp message_class(:user, _current_user, _message_user), do: "other-message bg-gray-100 mr-8"

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%H:%M")
  end
end