defmodule AiSelfSustainingMinimal.Telemetry.AutoInstrument do
  @moduledoc """
  Auto-instrumentation configuration for the Spark DSL.
  """
  
  defstruct [
    :functions,
    :context,
    :filter_events,
    :measurements
  ]
end