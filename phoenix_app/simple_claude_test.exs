#!/usr/bin/env elixir

# Simple Claude Code integration test

defmodule SimpleClaudeTest do
  def test_claude_availability do
    IO.puts("🤖 Testing Claude Code Availability")
    
    try do
      case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
        {output, 0} ->
          IO.puts("✅ Claude Code detected: #{String.trim(output)}")
          {:ok, String.trim(output)}
        
        {error_output, _exit_code} ->
          IO.puts("⚠️  Claude Code command failed: #{error_output}")
          {:error, "Command failed: #{error_output}"}
      end
    rescue
      _error ->
        IO.puts("⚠️  Claude Code not found in PATH")
        {:error, "Claude command not found in PATH"}
    end
  end
  
  def test_basic_claude_execution do
    IO.puts("\n🔧 Testing Basic Claude Execution")
    
    test_input = "def hello, do: IO.puts(\"Hello World\")"
    
    try do
      case System.cmd("sh", ["-c", "echo '#{test_input}' | claude -p 'Review this Elixir code'"], stderr_to_stdout: true) do
        {output, 0} ->
          IO.puts("✅ Claude execution successful")
          IO.puts("   Output length: #{String.length(output)} characters")
          {:ok, output}
        
        {error_output, exit_code} ->
          IO.puts("❌ Claude execution failed (exit #{exit_code})")
          IO.puts("   Error: #{String.slice(error_output, 0, 200)}")
          {:error, "Exit #{exit_code}: #{error_output}"}
      end
    rescue
      error ->
        IO.puts("❌ Claude command error: #{Exception.message(error)}")
        {:error, Exception.message(error)}
    end
  end
  
  def run_tests do
    IO.puts("=" |> String.duplicate(50))
    
    case test_claude_availability() do
      {:ok, version} ->
        IO.puts("Claude Code version: #{version}")
        test_basic_claude_execution()
      
      {:error, reason} ->
        IO.puts("Skipping Claude tests: #{reason}")
        IO.puts("This demonstrates that the Reactor architecture can gracefully handle missing dependencies")
    end
    
    IO.puts("\n🎯 Simple Claude Test Complete!")
  end
end

SimpleClaudeTest.run_tests()