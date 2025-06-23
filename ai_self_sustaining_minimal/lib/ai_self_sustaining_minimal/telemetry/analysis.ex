defmodule AiSelfSustainingMinimal.Telemetry.Analysis do
  @moduledoc """
  Analysis configuration for mutual information measurement.
  """
  
  defstruct [
    :measure_mi,
    :export_format,
    :export_path,
    :optimization_target,
    :auto_optimize,
    :sample_rate
  ]
end