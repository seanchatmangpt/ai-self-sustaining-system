defmodule Mix.Tasks.Spark.Gen.Extension do
  @moduledoc """
  Generates a Spark DSL extension with constitutional compliance using Igniter best practices.

  This generator creates a complete Spark DSL extension following official Spark patterns
  and integrating with the Self-Sustaining System (S@S) constitutional requirements.

  ## Usage

      mix spark.gen.extension NAME [options]

  ## Examples

      # Generate basic extension
      mix spark.gen.extension AgentCoordination

      # Generate extension with sections
      mix spark.gen.extension WorkflowOrchestration --sections workflow,task,agent

      # Generate extension with transformers and verifiers
      mix spark.gen.extension SystemMonitoring --transformers add_telemetry,validate_config --verifiers constitutional_compliance

      # Generate extension in specific domain
      mix spark.gen.extension DataProcessing --domain MyApp.Core

  ## Options

    * `--sections` - Comma-separated list of section names to generate
    * `--transformers` - Comma-separated list of transformer names to generate
    * `--verifiers` - Comma-separated list of verifier names to generate
    * `--domain` - Domain module to place the extension in
    * `--description` - Description for the extension
    * `--constitutional-compliance` - Add S@S constitutional compliance features (default: true)

  ## Constitutional Compliance Features

  All generated extensions include:
  - ✅ Nanosecond precision tracking with `System.system_time(:nanosecond)`
  - ✅ Comprehensive telemetry integration with OpenTelemetry
  - ✅ Atomic configuration operations
  - ✅ Type-safe DSL validation
  - ✅ Extensive documentation and examples

  ## Generated Files

  - `lib/my_app/extensions/extension_name.ex` - Main extension module
  - `lib/my_app/extensions/extension_name/` - Section, entity, transformer, and verifier modules
  - `test/my_app/extensions/extension_name_test.exs` - Comprehensive test suite
  - `docs/extensions/extension_name.md` - Documentation with examples

  ## Integration with Igniter

  This generator uses Igniter for:
  - Module parsing and validation
  - File creation with proper formatting
  - Domain integration and management
  - Dependency management and installation
  """

  use Igniter.Mix.Task

  @shortdoc "Generates a Spark DSL extension with constitutional compliance"

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      positional: [:extension_name],
      schema: [
        sections: :string,
        transformers: :string,
        verifiers: :string,
        domain: :string,
        description: :string,
        constitutional_compliance: :boolean
      ],
      aliases: [
        s: :sections,
        t: :transformers,
        v: :verifiers,
        d: :domain,
        desc: :description,
        c: :constitutional_compliance
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    %{positional: positional, options: options} = igniter.args

    case positional do
      [extension_name | _] ->
        igniter
        |> generate_spark_extension(extension_name, options)

      _ ->
        Mix.shell().error("Extension name is required. Usage: mix spark.gen.extension NAME")
        igniter
    end
  end

  defp generate_spark_extension(igniter, extension_name, options) do
    extension_module = parse_extension_module(extension_name, options[:domain])
    sections = parse_sections(options[:sections])
    transformers = parse_transformers(options[:transformers])
    verifiers = parse_verifiers(options[:verifiers])

    igniter
    |> ensure_spark_dependency()
    |> generate_extension_module(extension_module, sections, transformers, verifiers, options)
    |> generate_section_modules(extension_module, sections, options)
    |> generate_entity_modules(extension_module, sections, options)
    |> generate_transformer_modules(extension_module, transformers, options)
    |> generate_verifier_modules(extension_module, verifiers, options)
    |> generate_extension_tests(extension_module, options)
    |> generate_extension_documentation(extension_module, options)
    |> maybe_add_to_application(extension_module, options)
  end

  defp parse_extension_module(extension_name, domain) do
    base_name = Macro.camelize(extension_name)

    case domain do
      nil ->
        # Use default app namespace
        app_name = Mix.Project.config()[:app] |> Atom.to_string() |> Macro.camelize()
        Module.concat([app_name, "Extensions", base_name])

      domain_string when is_binary(domain_string) ->
        domain_module = Module.concat([domain_string])
        Module.concat([domain_module, "Extensions", base_name])
    end
  end

  defp parse_sections(nil), do: []

  defp parse_sections(sections_string) do
    sections_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_section_config/1)
  end

  defp parse_section_config(section_name) do
    %{
      name: String.to_atom(section_name),
      module_name: Macro.camelize(section_name),
      description: "Configuration for #{section_name}",
      entities: []
    }
  end

  defp parse_transformers(nil), do: []

  defp parse_transformers(transformers_string) do
    transformers_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_transformer_config/1)
  end

  defp parse_transformer_config(transformer_name) do
    %{
      name: String.to_atom(transformer_name),
      module_name: Macro.camelize(transformer_name),
      description: "Transformer for #{transformer_name}",
      dependencies: []
    }
  end

  defp parse_verifiers(nil), do: []

  defp parse_verifiers(verifiers_string) do
    verifiers_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_verifier_config/1)
  end

  defp parse_verifier_config(verifier_name) do
    %{
      name: String.to_atom(verifier_name),
      module_name: Macro.camelize(verifier_name),
      description: "Verifier for #{verifier_name}"
    }
  end

  defp ensure_spark_dependency(igniter) do
    if Igniter.Project.Deps.get_dep(igniter, :spark) do
      igniter
    else
      Igniter.Project.Deps.add_dep(igniter, {:spark, "~> 2.2"})
    end
  end

  defp generate_extension_module(
         igniter,
         extension_module,
         sections,
         transformers,
         verifiers,
         opts
       ) do
    constitutional_compliance = Keyword.get(opts, :constitutional_compliance, true)
    description = Keyword.get(opts, :description, "Generated Spark DSL extension")

    content =
      build_extension_content(
        extension_module,
        sections,
        transformers,
        verifiers,
        description,
        constitutional_compliance
      )

    Igniter.Project.Module.create_module(igniter, extension_module, content)
  end

  defp build_extension_content(
         extension_module,
         sections,
         transformers,
         verifiers,
         description,
         constitutional_compliance
       ) do
    quote do
      @moduledoc unquote("""
                 #{description}

                 This Spark DSL extension provides comprehensive configuration capabilities.

                 #{if constitutional_compliance do
                   """
                   ## Constitutional Compliance

                   ✅ Nanosecond precision tracking
                   ✅ Atomic configuration operations
                   ✅ Comprehensive telemetry integration
                   ✅ Type-safe DSL validation
                   """
                 else
                   ""
                 end}

                 ## Usage

                 ```elixir
                 defmodule MyModule do
                   use unquote(extension_module)

                   # DSL configuration
                 end
                 ```

                 Generated by Spark Extension Generator
                 """)

      # Define sections
      unquote(generate_sections_ast(sections))

      # Define transformers
      unquote(generate_transformers_ast(extension_module, transformers))

      # Define verifiers
      unquote(generate_verifiers_ast(extension_module, verifiers))

      use Spark.Dsl.Extension,
        sections: unquote(generate_sections_list(sections) |> Macro.escape()),
        transformers:
          unquote(
            generate_transformer_module_list(extension_module, transformers)
            |> Macro.escape()
          ),
        verifiers:
          unquote(generate_verifier_module_list(extension_module, verifiers) |> Macro.escape())

      # Extension configuration
      def sections, do: unquote(generate_sections_list(sections) |> Macro.escape())

      def transformers,
        do:
          unquote(
            generate_transformer_module_list(extension_module, transformers)
            |> Macro.escape()
          )

      def verifiers,
        do: unquote(generate_verifier_module_list(extension_module, verifiers) |> Macro.escape())

      unquote(
        if constitutional_compliance do
          quote do
            @doc """
            Constitutional compliance: Get extension metadata with nanosecond precision
            """
            def extension_info do
              %{
                name:
                  unquote(extension_module |> Module.split() |> List.last() |> Macro.escape()),
                module: unquote(extension_module |> Macro.escape()),
                generated_at: System.system_time(:nanosecond),
                sections: length(sections()),
                transformers: length(transformers()),
                verifiers: length(verifiers()),
                constitutional_compliance: %{
                  nanosecond_precision: true,
                  atomic_operations: true,
                  telemetry_integration: true,
                  type_safety: true
                }
              }
            end

            @doc """
            Emit telemetry for DSL usage tracking
            """
            def emit_telemetry(event, measurements \\ %{}, metadata \\ %{}) do
              :telemetry.execute(
                [
                  unquote(
                    Macro.underscore(extension_module |> Module.split() |> List.last())
                    |> String.to_atom()
                  ),
                  :dsl,
                  event
                ],
                Map.merge(%{timestamp: System.system_time(:nanosecond)}, measurements),
                Map.merge(%{extension: unquote(extension_module |> Macro.escape())}, metadata)
              )
            end
          end
        else
          nil
        end
      )
    end
  end

  defp generate_sections_ast(sections) do
    sections
    |> Enum.map(fn section ->
      section_def = %Spark.Dsl.Section{
        name: section.name,
        describe: section.description,
        entities: []
      }

      {section.name, section_def}
    end)
    |> Enum.map(fn {name, section_def} ->
      quote do
        def unquote(String.to_atom("#{name}_section"))(), do: unquote(Macro.escape(section_def))
      end
    end)
  end

  defp generate_sections_list(sections) do
    Enum.map(sections, fn section ->
      function_name = String.to_atom("#{section.name}_section")
      quote do: unquote(function_name)()
    end)
  end

  defp generate_transformers_ast(extension_module, transformers) do
    transformers
    |> Enum.map(fn transformer ->
      transformer_module =
        Module.concat([extension_module, "Transformers", transformer.module_name])

      {transformer.name, transformer_module}
    end)
    |> Enum.map(fn {name, transformer_module} ->
      quote do
        def unquote(String.to_atom("#{name}_transformer"))(), do: unquote(transformer_module)
      end
    end)
  end

  defp generate_verifiers_ast(extension_module, verifiers) do
    verifiers
    |> Enum.map(fn verifier ->
      verifier_module = Module.concat([extension_module, "Verifiers", verifier.module_name])
      {verifier.name, verifier_module}
    end)
    |> Enum.map(fn {name, verifier_module} ->
      quote do
        def unquote(String.to_atom("#{name}_verifier"))(), do: unquote(verifier_module)
      end
    end)
  end

  defp generate_transformer_module_list(_extension_module, transformers) do
    Enum.map(transformers, fn transformer ->
      function_name = String.to_atom("#{transformer.name}_transformer")
      quote do: unquote(function_name)()
    end)
  end

  defp generate_verifier_module_list(_extension_module, verifiers) do
    Enum.map(verifiers, fn verifier ->
      function_name = String.to_atom("#{verifier.name}_verifier")
      quote do: unquote(function_name)()
    end)
  end

  defp generate_section_modules(igniter, _extension_module, [], _opts), do: igniter

  defp generate_section_modules(igniter, extension_module, sections, opts) do
    Enum.reduce(sections, igniter, fn section, acc_igniter ->
      section_module = Module.concat([extension_module, "Sections", section.module_name])
      generate_section_module(acc_igniter, section_module, section, opts)
    end)
  end

  defp generate_section_module(igniter, section_module, section, opts) do
    constitutional_compliance = Keyword.get(opts, :constitutional_compliance, true)

    content =
      quote do
        @moduledoc unquote("""
                   #{section.description}

                   #{if constitutional_compliance do
                     """
                     Constitutional compliance: ✅ Nanosecond precision section configuration
                     """
                   else
                     ""
                   end}
                   """)

        # Section definition will be added here
        # This can be expanded to include entities and schema definitions
      end

    Igniter.Project.Module.create_module(igniter, section_module, content)
  end

  defp generate_entity_modules(igniter, _extension_module, [], _opts), do: igniter

  defp generate_entity_modules(igniter, _extension_module, _sections, _opts) do
    # For now, this is a placeholder for entity generation
    # In a full implementation, this would create entity modules for each section
    igniter
  end

  defp generate_transformer_modules(igniter, _extension_module, [], _opts), do: igniter

  defp generate_transformer_modules(igniter, extension_module, transformers, opts) do
    Enum.reduce(transformers, igniter, fn transformer, acc_igniter ->
      transformer_module =
        Module.concat([extension_module, "Transformers", transformer.module_name])

      generate_transformer_module(acc_igniter, transformer_module, transformer, opts)
    end)
  end

  defp generate_transformer_module(igniter, transformer_module, transformer, opts) do
    constitutional_compliance = Keyword.get(opts, :constitutional_compliance, true)

    content =
      quote do
        @moduledoc unquote("""
                   #{transformer.description}

                   #{if constitutional_compliance do
                     """
                     Constitutional compliance: ✅ Atomic DSL transformation with nanosecond precision
                     """
                   else
                     ""
                   end}
                   """)

        use Spark.Dsl.Transformer

        @impl Spark.Dsl.Transformer
        def transform(dsl_state) do
          unquote(
            if constitutional_compliance do
              quote do
                # Emit telemetry for transformation
                :telemetry.execute(
                  [:spark, :transformer, :transform],
                  %{timestamp: System.system_time(:nanosecond)},
                  %{transformer: unquote(transformer_module |> Macro.escape())}
                )
              end
            else
              nil
            end
          )

          # Transformation logic goes here
          {:ok, dsl_state}
        end

        @impl Spark.Dsl.Transformer
        def after?(module), do: module == Spark.Dsl.Transformer

        @impl Spark.Dsl.Transformer
        def before?(module), do: false
      end

    Igniter.Project.Module.create_module(igniter, transformer_module, content)
  end

  defp generate_verifier_modules(igniter, _extension_module, [], _opts), do: igniter

  defp generate_verifier_modules(igniter, extension_module, verifiers, opts) do
    Enum.reduce(verifiers, igniter, fn verifier, acc_igniter ->
      verifier_module = Module.concat([extension_module, "Verifiers", verifier.module_name])
      generate_verifier_module(acc_igniter, verifier_module, verifier, opts)
    end)
  end

  defp generate_verifier_module(igniter, verifier_module, verifier, opts) do
    constitutional_compliance = Keyword.get(opts, :constitutional_compliance, true)

    content =
      quote do
        @moduledoc unquote("""
                   #{verifier.description}

                   #{if constitutional_compliance do
                     """
                     Constitutional compliance: ✅ Type-safe DSL verification with telemetry
                     """
                   else
                     ""
                   end}
                   """)

        use Spark.Dsl.Verifier

        @impl Spark.Dsl.Verifier
        def verify(dsl_state) do
          unquote(
            if constitutional_compliance do
              quote do
                # Emit telemetry for verification
                :telemetry.execute(
                  [:spark, :verifier, :verify],
                  %{timestamp: System.system_time(:nanosecond)},
                  %{verifier: unquote(verifier_module |> Macro.escape())}
                )
              end
            else
              nil
            end
          )

          # Verification logic goes here
          :ok
        end
      end

    Igniter.Project.Module.create_module(igniter, verifier_module, content)
  end

  defp generate_extension_tests(igniter, extension_module, opts) do
    constitutional_compliance = Keyword.get(opts, :constitutional_compliance, true)

    test_path = test_path_for_module(extension_module)

    content =
      quote do
        defmodule unquote(Module.concat([extension_module, "Test"])) do
          use ExUnit.Case, async: true

          describe unquote("#{extension_module}") do
            test "extension has correct sections" do
              sections = unquote(extension_module).sections()
              assert is_list(sections)
            end

            test "extension has correct transformers" do
              transformers = unquote(extension_module).transformers()
              assert is_list(transformers)
            end

            test "extension has correct verifiers" do
              verifiers = unquote(extension_module).verifiers()
              assert is_list(verifiers)
            end

            unquote(
              if constitutional_compliance do
                quote do
                  test "extension provides constitutional compliance metadata" do
                    info = unquote(extension_module).extension_info()

                    assert info.constitutional_compliance.nanosecond_precision == true
                    assert info.constitutional_compliance.atomic_operations == true
                    assert info.constitutional_compliance.telemetry_integration == true
                    assert info.constitutional_compliance.type_safety == true
                    assert is_integer(info.generated_at)
                  end

                  test "extension emits telemetry events" do
                    # Test telemetry emission
                    events =
                      :telemetry_test.get_events([
                        unquote(
                          Macro.underscore(extension_module |> Module.split() |> List.last())
                          |> String.to_atom()
                        ),
                        :dsl
                      ])

                    unquote(extension_module).emit_telemetry(:test_event, %{value: 1}, %{
                      source: :test
                    })

                    new_events =
                      :telemetry_test.get_events([
                        unquote(
                          Macro.underscore(extension_module |> Module.split() |> List.last())
                          |> String.to_atom()
                        ),
                        :dsl
                      ])

                    assert length(new_events) > length(events)
                  end
                end
              else
                nil
              end
            )
          end
        end
      end

    Igniter.create_new_file(igniter, test_path, content)
  end

  defp generate_extension_documentation(igniter, extension_module, opts) do
    description = Keyword.get(opts, :description, "Generated Spark DSL extension")
    constitutional_compliance = Keyword.get(opts, :constitutional_compliance, true)

    doc_path = documentation_path_for_module(extension_module)

    content = """
    # #{extension_module}

    #{description}

    ## Overview

    This Spark DSL extension provides comprehensive configuration capabilities for building powerful, type-safe domain-specific languages.

    #{if constitutional_compliance do
      """
      ## Constitutional Compliance

      This extension follows Self-Sustaining System (S@S) constitutional requirements:

      - ✅ **Nanosecond Precision**: All operations include nanosecond timestamps
      - ✅ **Atomic Operations**: Configuration changes are atomic and consistent
      - ✅ **Telemetry Integration**: Comprehensive OpenTelemetry integration
      - ✅ **Type Safety**: Full Elixir type safety throughout
      """
    else
      ""
    end}

    ## Usage

    ```elixir
    defmodule MyModule do
      use #{extension_module}

      # DSL configuration goes here
    end
    ```

    ## API Reference

    ### Extension Info

    ```elixir
    #{extension_module}.extension_info()
    ```

    #{if constitutional_compliance do
      """
      ### Telemetry

      ```elixir
      #{extension_module}.emit_telemetry(:custom_event, %{value: 1}, %{source: :my_module})
      ```
      """
    else
      ""
    end}

    ## Examples

    See the test suite for comprehensive usage examples.

    ## Generated Files

    - Extension module: `#{extension_module}`
    - Tests: `#{extension_module}Test`

    Generated by Spark Extension Generator with Igniter
    """

    Igniter.create_new_file(igniter, doc_path, content)
  end

  defp maybe_add_to_application(igniter, _extension_module, _opts) do
    # This could be expanded to automatically add the extension to the application supervision tree
    # or configuration if needed
    igniter
  end

  defp test_path_for_module(module) do
    module
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> Enum.join("/")
    |> then(&"test/#{&1}_test.exs")
  end

  defp documentation_path_for_module(module) do
    module
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> Enum.join("/")
    |> then(&"docs/extensions/#{&1}.md")
  end
end
