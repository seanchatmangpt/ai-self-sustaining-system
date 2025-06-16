#!/usr/bin/env elixir

# Test script to verify the generated DSL works
Mix.install([:spark])

Code.require_file("lib/test_validator.ex")
Code.require_file("lib/test_my_validator.ex")

# Test that the DSL works
try do
  fields = Spark.Dsl.Extension.get_entities(TestMyValidator, [:fields])
  IO.puts("✅ DSL is working!")
  IO.puts("Fields found: #{length(fields)}")
  
  Enum.each(fields, fn field ->
    IO.puts("  - #{field.name} (#{field.type})")
  end)
  
  # Test the verifier (should pass since we have fields)
  case Spark.Dsl.Verifier.verify(TestMyValidator, TestValidator.Dsl.VerifyRequired) do
    :ok -> IO.puts("✅ Verifier passed: Fields are defined")
    {:error, reason} -> IO.puts("❌ Verifier failed: #{reason}")
  end
  
rescue
  error ->
    IO.puts("❌ Error testing DSL: #{inspect(error)}")
end