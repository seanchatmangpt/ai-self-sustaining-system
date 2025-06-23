defmodule Mix.Tasks.Spark.Gen.Simple do
  @moduledoc """
  Simple Spark DSL generator - 80/20 implementation

  Generates a working Spark DSL extension following the tutorial.
  """

  @shortdoc "Generates a simple Spark DSL extension"

  def run(argv) do
    case argv do
      [extension_name | _] ->
        generate_simple_extension(extension_name)

      [] ->
        Mix.shell().error(
          "Extension name is required. Usage: mix spark.gen.simple EXTENSION_NAME"
        )
    end
  end

  defp generate_simple_extension(extension_name) do
    # Generate the exact validator DSL from the tutorial
    dsl_module = Module.concat([Macro.camelize(extension_name), "Dsl"])
    main_module = Macro.camelize(extension_name)

    # Create the DSL extension file
    dsl_content = build_dsl_content(dsl_module, main_module)
    dsl_path = "lib/#{Macro.underscore(extension_name)}.ex"

    File.write!(dsl_path, dsl_content)

    Mix.shell().info("✅ Generated Spark DSL: #{dsl_path}")
    Mix.shell().info("📋 Extension: #{main_module}")
    Mix.shell().info("🔧 Usage: use #{main_module}")
  end

  defp build_dsl_content(dsl_module, main_module) do
    """
    defmodule #{dsl_module} do
      @moduledoc \"\"\"
      Validator DSL extension following Spark tutorial
      \"\"\"

      # Define the Field struct
      defmodule Field do
        defstruct [:name, :type, :check, :transform]
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
        use Spark.Dsl.Transformer

        @impl Spark.Dsl.Transformer
        def transform(dsl_state) do
          # Add ID field if not present
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
        use Spark.Dsl.Transformer

        @impl Spark.Dsl.Transformer
        def transform(dsl_state) do
          # This would generate the validate/1 function
          {:ok, dsl_state}
        end
      end

      # Define verifiers
      defmodule VerifyRequired do
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

    defmodule #{main_module} do
      @moduledoc \"\"\"
      Main module that provides the DSL functionality.
      \"\"\"
      
      use Spark.Dsl,
        default_extensions: [
          extensions: [#{dsl_module}]
        ]
    end
    """
  end
end
