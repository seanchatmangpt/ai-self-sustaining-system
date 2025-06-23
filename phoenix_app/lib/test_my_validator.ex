defmodule TestMyValidator do
  @moduledoc """
  Test validator using the generated TestValidator DSL
  """

  use TestValidator

  @doc """
  Validates that a name is a non-empty string.
  """
  def validate_name(name) when is_binary(name) and byte_size(name) > 0, do: true
  def validate_name(_), do: false

  @doc """
  Validates that age is an integer between 0 and 120.
  """
  def validate_age(age) when is_integer(age) and age >= 0 and age <= 120, do: true
  def validate_age(_), do: false

  fields do
    field :name, :string do
      check(&validate_name/1)
    end

    field :age, :integer do
      check(&validate_age/1)
    end
  end
end
