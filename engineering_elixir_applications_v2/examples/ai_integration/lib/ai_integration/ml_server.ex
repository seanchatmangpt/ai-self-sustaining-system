defmodule AiIntegration.MLServer do
  @moduledoc """
  Engineering Elixir Applications v2 - AI/ML Integration Server
  
  Demonstrates modern patterns for integrating AI/ML capabilities:
  - Model serving with Nx and ONNX
  - Real-time inference pipelines
  - Vector embeddings and similarity search
  - Distributed AI workload processing
  - Claude AI integration for autonomous decisions
  - Performance monitoring and optimization
  """
  
  use GenServer
  use OpenTelemetry.Tracer
  
  require Logger
  
  alias AiIntegration.{
    VectorStore,
    ModelCache,
    InferenceQueue,
    PerformanceMonitor
  }

  # State structure
  defstruct [
    :models,
    :embedding_model,
    :vector_store,
    :inference_queue,
    :performance_metrics,
    :config
  ]

  @default_config %{
    model_cache_size: 100,
    max_concurrent_inferences: 10,
    embedding_dimension: 384,
    similarity_threshold: 0.8,
    claude_api_key: System.get_env("ANTHROPIC_API_KEY"),
    inference_timeout: 30_000,
    model_warmup_enabled: true
  }

  ## Public API

  @doc "Start the ML server with configuration"
  def start_link(opts \\ []) do
    config = Keyword.get(opts, :config, @default_config)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc "Load a machine learning model"
  def load_model(model_id, model_path, opts \\ []) do
    GenServer.call(__MODULE__, {:load_model, model_id, model_path, opts}, 30_000)
  end

  @doc "Perform inference with a loaded model"
  def inference(model_id, input_data, opts \\ []) do
    with_span "ml_inference", %{model_id: model_id} do
      GenServer.call(__MODULE__, {:inference, model_id, input_data, opts}, 30_000)
    end
  end

  @doc "Generate embeddings for text using the embedding model"
  def generate_embeddings(text) when is_binary(text) do
    with_span "generate_embeddings", %{text_length: String.length(text)} do
      GenServer.call(__MODULE__, {:generate_embeddings, text})
    end
  end

  @doc "Perform similarity search in vector store"
  def similarity_search(query_text, opts \\ []) do
    with_span "similarity_search" do
      GenServer.call(__MODULE__, {:similarity_search, query_text, opts})
    end
  end

  @doc "Store embeddings in vector store with metadata"
  def store_embeddings(id, text, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:store_embeddings, id, text, metadata})
  end

  @doc "Get Claude AI insights for autonomous decision making"
  def get_claude_insights(context, decision_type) do
    with_span "claude_insights", %{decision_type: decision_type} do
      GenServer.call(__MODULE__, {:claude_insights, context, decision_type}, 60_000)
    end
  end

  @doc "Batch process multiple inference requests"
  def batch_inference(requests) when is_list(requests) do
    with_span "batch_inference", %{batch_size: length(requests)} do
      GenServer.call(__MODULE__, {:batch_inference, requests}, 60_000)
    end
  end

  @doc "Get current performance metrics"
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc "Health check for the ML server"
  def health_check do
    GenServer.call(__MODULE__, :health_check)
  end

  ## GenServer Callbacks

  @impl true
  def init(config) do
    with_span "ml_server_init" do
      Logger.info("Starting ML Server with config: #{inspect(config)}")
      
      # Initialize components
      state = %__MODULE__{
        models: %{},
        embedding_model: nil,
        vector_store: nil,
        inference_queue: :queue.new(),
        performance_metrics: init_metrics(),
        config: config
      }
      
      # Schedule initialization tasks
      send(self(), :initialize_components)
      
      {:ok, state}
    end
  end

  @impl true
  def handle_call({:load_model, model_id, model_path, opts}, _from, state) do
    with_span "load_model", %{model_id: model_id} do
      case load_model_impl(model_id, model_path, opts, state.config) do
        {:ok, model} ->
          updated_models = Map.put(state.models, model_id, model)
          updated_state = %{state | models: updated_models}
          
          # Update metrics
          metrics = update_metrics(state.performance_metrics, :model_loaded)
          
          Logger.info("Model loaded successfully: #{model_id}")
          {:reply, {:ok, model_id}, %{updated_state | performance_metrics: metrics}}
          
        {:error, reason} ->
          Logger.error("Failed to load model #{model_id}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call({:inference, model_id, input_data, opts}, from, state) do
    case Map.get(state.models, model_id) do
      nil ->
        {:reply, {:error, :model_not_found}, state}
        
      model ->
        # Queue the inference request for async processing
        request = %{
          model_id: model_id,
          model: model,
          input_data: input_data,
          opts: opts,
          from: from,
          timestamp: System.monotonic_time()
        }
        
        updated_queue = :queue.in(request, state.inference_queue)
        updated_state = %{state | inference_queue: updated_queue}
        
        # Process queue asynchronously
        send(self(), :process_inference_queue)
        
        {:noreply, updated_state}
    end
  end

  @impl true
  def handle_call({:generate_embeddings, text}, _from, state) do
    case state.embedding_model do
      nil ->
        {:reply, {:error, :embedding_model_not_loaded}, state}
        
      model ->
        start_time = System.monotonic_time()
        
        case generate_embeddings_impl(text, model) do
          {:ok, embeddings} ->
            processing_time = System.monotonic_time() - start_time
            metrics = update_metrics(state.performance_metrics, :embeddings_generated, processing_time)
            
            {:reply, {:ok, embeddings}, %{state | performance_metrics: metrics}}
            
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:similarity_search, query_text, opts}, _from, state) do
    with {:ok, query_embeddings} <- generate_embeddings(query_text),
         {:ok, results} <- VectorStore.search(state.vector_store, query_embeddings, opts) do
      
      # Filter by similarity threshold
      threshold = Keyword.get(opts, :threshold, state.config.similarity_threshold)
      filtered_results = Enum.filter(results, fn {_id, _text, similarity, _metadata} ->
        similarity >= threshold
      end)
      
      {:reply, {:ok, filtered_results}, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:store_embeddings, id, text, metadata}, _from, state) do
    with {:ok, embeddings} <- generate_embeddings(text),
         :ok <- VectorStore.store(state.vector_store, id, embeddings, text, metadata) do
      {:reply, :ok, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:claude_insights, context, decision_type}, _from, state) do
    case get_claude_insights_impl(context, decision_type, state.config) do
      {:ok, insights} ->
        metrics = update_metrics(state.performance_metrics, :claude_insights_generated)
        {:reply, {:ok, insights}, %{state | performance_metrics: metrics}}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:batch_inference, requests}, _from, state) do
    start_time = System.monotonic_time()
    
    # Process batch requests in parallel using Task.async_stream
    results = requests
    |> Task.async_stream(fn %{model_id: model_id, input_data: input_data, opts: opts} ->
      model = Map.get(state.models, model_id)
      if model do
        perform_inference_impl(model, input_data, opts)
      else
        {:error, :model_not_found}
      end
    end, max_concurrency: state.config.max_concurrent_inferences, timeout: 30_000)
    |> Enum.map(fn 
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:timeout, reason}}
    end)
    
    processing_time = System.monotonic_time() - start_time
    metrics = update_metrics(state.performance_metrics, :batch_inference_completed, processing_time)
    
    {:reply, {:ok, results}, %{state | performance_metrics: metrics}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.performance_metrics, state}
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    health = %{
      status: :healthy,
      models_loaded: map_size(state.models),
      embedding_model_loaded: state.embedding_model != nil,
      vector_store_connected: state.vector_store != nil,
      queue_size: :queue.len(state.inference_queue),
      uptime_seconds: System.monotonic_time() - state.performance_metrics.start_time,
      metrics: state.performance_metrics
    }
    
    {:reply, health, state}
  end

  @impl true
  def handle_info(:initialize_components, state) do
    with_span "initialize_ml_components" do
      Logger.info("Initializing ML components...")
      
      # Initialize embedding model
      embedding_model = case load_embedding_model(state.config) do
        {:ok, model} -> 
          Logger.info("Embedding model loaded successfully")
          model
        {:error, reason} ->
          Logger.warning("Failed to load embedding model: #{inspect(reason)}")
          nil
      end
      
      # Initialize vector store
      vector_store = case VectorStore.start_link(state.config) do
        {:ok, pid} ->
          Logger.info("Vector store initialized successfully")
          pid
        {:error, reason} ->
          Logger.warning("Failed to initialize vector store: #{inspect(reason)}")
          nil
      end
      
      # Start performance monitoring
      if state.config[:performance_monitoring_enabled] do
        PerformanceMonitor.start_monitoring(self())
      end
      
      updated_state = %{state | 
        embedding_model: embedding_model, 
        vector_store: vector_store
      }
      
      Logger.info("ML Server initialization completed")
      {:noreply, updated_state}
    end
  end

  @impl true
  def handle_info(:process_inference_queue, state) do
    case :queue.out(state.inference_queue) do
      {{:value, request}, updated_queue} ->
        # Process inference request asynchronously
        spawn(fn -> process_inference_request(request) end)
        
        updated_state = %{state | inference_queue: updated_queue}
        
        # Continue processing if queue not empty
        if not :queue.is_empty(updated_queue) do
          send(self(), :process_inference_queue)
        end
        
        {:noreply, updated_state}
        
      {:empty, _queue} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:inference_result, from, result}, state) do
    GenServer.reply(from, result)
    {:noreply, state}
  end

  @impl true
  def handle_info(:performance_report, state) do
    Logger.info("ML Server Performance Report: #{inspect(state.performance_metrics)}")
    {:noreply, state}
  end

  ## Private Implementation Functions

  defp load_model_impl(model_id, model_path, opts, config) do
    try do
      # Simulate model loading (in real implementation, use Nx, ONNX, or other ML libraries)
      case File.exists?(model_path) do
        true ->
          model = %{
            id: model_id,
            path: model_path,
            type: Keyword.get(opts, :type, :onnx),
            loaded_at: DateTime.utc_now(),
            metadata: Keyword.get(opts, :metadata, %{})
          }
          
          # Warm up model if enabled
          if config.model_warmup_enabled do
            warmup_model(model)
          end
          
          {:ok, model}
          
        false ->
          {:error, :model_file_not_found}
      end
    rescue
      error -> {:error, {:model_load_failed, error}}
    end
  end

  defp perform_inference_impl(model, input_data, opts) do
    try with_span "model_inference", %{model_id: model.id} do
      # Simulate inference processing
      processing_time = Keyword.get(opts, :processing_time, :rand.uniform(100))
      Process.sleep(processing_time)
      
      # Return mock prediction
      prediction = %{
        model_id: model.id,
        input_shape: get_input_shape(input_data),
        prediction: :rand.uniform(),
        confidence: :rand.uniform(),
        processing_time_ms: processing_time,
        timestamp: DateTime.utc_now()
      }
      
      {:ok, prediction}
    rescue
      error -> {:error, {:inference_failed, error}}
    end
  end

  defp generate_embeddings_impl(text, model) do
    try do
      # Simulate embedding generation (use sentence-transformers, OpenAI, etc. in real implementation)
      words = String.split(text, " ")
      embedding_size = 384  # Common embedding dimension
      
      # Generate mock embeddings based on text content
      embeddings = for i <- 1..embedding_size do
        :rand.uniform() * length(words) / (i + 1)
      end
      
      {:ok, embeddings}
    rescue
      error -> {:error, {:embedding_generation_failed, error}}
    end
  end

  defp get_claude_insights_impl(context, decision_type, config) do
    case config.claude_api_key do
      nil ->
        {:error, :claude_api_key_not_configured}
        
      api_key ->
        try do
          # Simulate Claude API call (use real Anthropic API in production)
          insights = %{
            decision_type: decision_type,
            context_summary: summarize_context(context),
            recommendations: generate_recommendations(context, decision_type),
            confidence_score: :rand.uniform(),
            reasoning: "Based on the provided context and decision type, here are the AI-driven insights...",
            generated_at: DateTime.utc_now()
          }
          
          {:ok, insights}
        rescue
          error -> {:error, {:claude_api_failed, error}}
        end
    end
  end

  defp process_inference_request(request) do
    result = perform_inference_impl(
      request.model, 
      request.input_data, 
      request.opts
    )
    
    # Send result back to caller
    send(self(), {:inference_result, request.from, result})
  end

  defp load_embedding_model(config) do
    # Simulate loading sentence transformer or similar model
    model = %{
      type: :sentence_transformer,
      model_name: "all-MiniLM-L6-v2",
      dimension: config.embedding_dimension,
      loaded_at: DateTime.utc_now()
    }
    
    {:ok, model}
  end

  defp warmup_model(model) do
    Logger.info("Warming up model: #{model.id}")
    # Perform dummy inference to warm up model
    dummy_input = %{data: [1, 2, 3, 4, 5]}
    perform_inference_impl(model, dummy_input, [])
  end

  defp init_metrics do
    %{
      start_time: System.monotonic_time(),
      models_loaded: 0,
      inferences_completed: 0,
      embeddings_generated: 0,
      claude_insights_generated: 0,
      batch_inferences_completed: 0,
      total_processing_time: 0,
      average_inference_time: 0,
      error_count: 0
    }
  end

  defp update_metrics(metrics, :model_loaded) do
    %{metrics | models_loaded: metrics.models_loaded + 1}
  end

  defp update_metrics(metrics, :embeddings_generated, processing_time) do
    %{metrics | 
      embeddings_generated: metrics.embeddings_generated + 1,
      total_processing_time: metrics.total_processing_time + processing_time
    }
  end

  defp update_metrics(metrics, :claude_insights_generated) do
    %{metrics | claude_insights_generated: metrics.claude_insights_generated + 1}
  end

  defp update_metrics(metrics, :batch_inference_completed, processing_time) do
    %{metrics | 
      batch_inferences_completed: metrics.batch_inferences_completed + 1,
      total_processing_time: metrics.total_processing_time + processing_time
    }
  end

  defp get_input_shape(input_data) when is_map(input_data) do
    case Map.get(input_data, :data) do
      list when is_list(list) -> [length(list)]
      _ -> [1]
    end
  end

  defp get_input_shape(_), do: [1]

  defp summarize_context(context) when is_map(context) do
    Map.take(context, [:type, :priority, :data_size, :timestamp])
  end

  defp summarize_context(context), do: %{raw_context: context}

  defp generate_recommendations(context, decision_type) do
    base_recommendations = [
      "Optimize model performance for current workload",
      "Consider batch processing for efficiency",
      "Monitor memory usage during inference",
      "Implement caching for repeated requests"
    ]
    
    specific_recommendations = case decision_type do
      :scaling -> ["Scale up inference workers", "Distribute load across nodes"]
      :optimization -> ["Profile model execution", "Optimize input preprocessing"]
      :monitoring -> ["Add detailed telemetry", "Set up alerts for anomalies"]
      _ -> []
    end
    
    base_recommendations ++ specific_recommendations
  end
end