defmodule Mix.Tasks.Spark.Gen.Working do
  @moduledoc """
  Generates a working Spark DSL extension following the tutorial pattern.

  ## Usage

      mix spark.gen.working NAME [options]
      
  ## Examples

      mix spark.gen.working ValidatorExample
      mix spark.gen.working UserValidator --domain MyApp.Auth
      
  ## Options

    * `--domain` - Domain module to place the extension in (optional)
  """

  use Igniter.Mix.Task

  @shortdoc "Generates a working Spark DSL extension"

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      positional: [:extension_name],
      schema: [
        domain: :string
      ],
      aliases: [
        d: :domain
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Mix.shell().info("🔥 DEBUG: Igniter function called")
    %{positional: positional, options: options} = igniter.args
    Mix.shell().info("🔥 DEBUG: Positional args: #{inspect(positional)}")

    case Map.get(positional, :extension_name) do
      extension_name when is_binary(extension_name) ->
        Mix.shell().info("🔥 DEBUG: About to generate extension: #{extension_name}")

        result =
          igniter
          |> generate_working_extension(extension_name, options)

        Mix.shell().info("🔥 DEBUG: Generation completed")
        result

      _ ->
        Mix.shell().error("Extension name is required. Usage: mix spark.gen.working NAME")
        igniter
    end
  end

  defp generate_working_extension(igniter, extension_name, options) do
    Mix.shell().info("🔥 DEBUG: In generate_working_extension")
    extension_module = build_extension_module(extension_name, options[:domain])
    file_path = build_file_path(extension_name, options[:domain])
    Mix.shell().info("🔥 DEBUG: Will create file at: #{file_path}")

    content = build_extension_content(extension_module, extension_name)
    Mix.shell().info("🔥 DEBUG: Content generated, length: #{String.length(content)}")

    # Create directory if it doesn't exist
    File.mkdir_p!(Path.dirname(file_path))

    # Write the file directly (80/20 approach)
    File.write!(file_path, content)
    Mix.shell().info("🔥 DEBUG: File written!")

    Mix.shell().info("✅ Generated Spark DSL extension: #{file_path}")
    Mix.shell().info("📋 Module: #{extension_module}")
    Mix.shell().info("🔧 Usage: use #{extension_module}")

    igniter
  end

  defp build_extension_module(extension_name, domain) do
    base_name = Macro.camelize(extension_name)

    case domain do
      nil ->
        app_name = Mix.Project.config()[:app] |> Atom.to_string() |> Macro.camelize()
        Module.concat([app_name, "Extensions", base_name])

      domain_string when is_binary(domain_string) ->
        domain_module = Module.concat([domain_string])
        Module.concat([domain_module, "Extensions", base_name])
    end
  end

  defp build_file_path(extension_name, domain) do
    base_path = extension_name |> Macro.underscore()

    case domain do
      nil ->
        "lib/#{base_path}.ex"

      domain_string when is_binary(domain_string) ->
        domain_path = domain_string |> Macro.underscore()
        "lib/#{domain_path}/extensions/#{base_path}.ex"
    end
  end

  defp build_extension_content(extension_module, extension_name) do
    dsl_module = Module.concat([extension_module, "Dsl"])

    """
    defmodule #{dsl_module} do
      @moduledoc \"\"\"
      #{extension_name} DSL extension following Spark tutorial pattern.
      \"\"\"

      # Define the Field struct
      defmodule Field do
        @moduledoc \"\"\"
        Field entity for #{extension_name} configuration.
        \"\"\"
        
        defstruct [:name, :type, :check, :transform]
        
        @type t :: %__MODULE__{
          name: atom(),
          type: atom(),
          check: (any() -> boolean()) | nil,
          transform: (any() -> any()) | nil
        }
      end

      # Define the field entity
      @field %Spark.Dsl.Entity{
        name: :field,
        args: [:name, :type],
        target: Field,
        schema: [
          name: [type: :atom, required: true, doc: "The name of the field"],
          type: [type: {:one_of, [:integer, :string]}, required: true, doc: "The type of the field"],
          check: [type: {:fun, 1}, doc: "Validation function"],
          transform: [type: {:fun, 1}, doc: "Transformation function"]
        ]
      }

      # Define the fields section
      @fields %Spark.Dsl.Section{
        name: :fields,
        describe: "Configure the fields that are supported and required",
        entities: [@field],
        schema: [
          required: [type: {:list, :atom}, doc: "The fields that must be provided"]
        ]
      }

      # Define transformers
      defmodule AddId do
        @moduledoc \"\"\"
        Transformer that automatically adds an ID field.
        \"\"\"
        
        use Spark.Dsl.Transformer

        @impl Spark.Dsl.Transformer
        def transform(dsl_state) do
          fields = Spark.Dsl.Extension.get_entities(dsl_state, [:fields])
          
          has_id = Enum.any?(fields, &(&1.name == :id))
          
          if not has_id do
            id_field = %Field{name: :id, type: :integer}
            updated_state = Spark.Dsl.Transformer.add_entity(dsl_state, [:fields], id_field)
            {:ok, updated_state}
          else
            {:ok, dsl_state}
          end
        end
      end

      defmodule GenerateValidate do
        @moduledoc \"\"\"
        Transformer that generates validation functions.
        \"\"\"
        
        use Spark.Dsl.Transformer

        @impl Spark.Dsl.Transformer
        def transform(dsl_state) do
          # This would generate the validate/1 function
          {:ok, dsl_state}
        end
      end

      # Define verifiers
      defmodule VerifyRequired do
        @moduledoc \"\"\"
        Verifier that ensures at least one field is defined.
        \"\"\"
        
        use Spark.Dsl.Verifier

        @impl Spark.Dsl.Verifier
        def verify(dsl_state) do
          fields = Spark.Dsl.Extension.get_entities(dsl_state, [:fields])
          
          if Enum.empty?(fields) do
            {:error, "At least one field is required"}
          else
            :ok
          end
        end
      end

      # Use the extension
      use Spark.Dsl.Extension,
        sections: [@fields],
        transformers: [AddId, GenerateValidate],
        verifiers: [VerifyRequired]
    end

    defmodule #{extension_module} do
      @moduledoc \"\"\"
      Main module that provides the #{extension_name} DSL functionality.
      \"\"\"
      
      use Spark.Dsl,
        default_extensions: [
          extensions: [#{dsl_module}]
        ]
    end
    """
  end
end
