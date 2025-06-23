defmodule Elixir.TestValidator.Dsl do
  @moduledoc """
  Validator DSL extension following Spark tutorial
  """

  # Define the Field struct
  defmodule Field do
    @moduledoc """
    Field entity for validator configuration.

    Represents a single field in a validator with type information
    and optional validation/transformation functions.
    """

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
    @moduledoc """
    Transformer that automatically adds an ID field to validators.

    Ensures every validator has an :id field of type :integer
    unless one is already explicitly defined.
    """

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
    @moduledoc """
    Transformer that generates validation functions for validators.

    Intended to create a validate/1 function based on the
    configured fields and their validation rules.
    """

    use Spark.Dsl.Transformer

    @impl Spark.Dsl.Transformer
    def transform(dsl_state) do
      # This would generate the validate/1 function
      {:ok, dsl_state}
    end
  end

  # Define verifiers
  defmodule VerifyRequired do
    @moduledoc """
    Verifier that ensures at least one field is defined in validators.

    Validates the DSL configuration to prevent empty validators
    that would not be useful for validation purposes.
    """

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

defmodule TestValidator do
  @moduledoc """
  Main module that provides the DSL functionality.
  """

  use Spark.Dsl,
    default_extensions: [
      extensions: [Elixir.TestValidator.Dsl]
    ]
end
