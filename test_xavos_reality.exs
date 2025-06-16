#!/usr/bin/env elixir

# XAVOS Reality Check - Independent Analysis
IO.puts("🔍 XAVOS INDEPENDENT REALITY ANALYSIS")
IO.puts("===================================")

# Change to XAVOS directory
System.cmd("bash", ["-c", "cd /Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos"])

IO.puts("\n📦 DEPENDENCY ANALYSIS:")
case System.cmd("mix", ["deps", "--all"], cd: "/Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos") do
  {output, 0} ->
    ash_deps = output |> String.split("\n") |> Enum.filter(fn line -> String.contains?(line, "ash") end)
    IO.puts("✅ Total Ash dependencies found: #{length(ash_deps)}")
    IO.puts("   First 5: #{Enum.take(ash_deps, 5) |> Enum.join(", ")}")
  {error, _} ->
    IO.puts("❌ Failed to analyze dependencies: #{error}")
end

IO.puts("\n🗄️ DATABASE REALITY CHECK:")
case System.cmd("mix", ["ecto.create", "--quiet"], cd: "/Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos") do
  {_, 0} ->
    IO.puts("✅ Database creation succeeded or already exists")
  {_, _} ->
    IO.puts("❌ Database creation failed")
end

IO.puts("\n📊 FILE STRUCTURE ANALYSIS:")
phoenix_files = Path.wildcard("/Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos/lib/xavos_web/**/*.ex")
IO.puts("✅ Phoenix LiveView files: #{length(phoenix_files)}")

vue_files = Path.wildcard("/Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos/assets/**/*.vue")
IO.puts("✅ Vue.js component files: #{length(vue_files)}")

ash_files = Path.wildcard("/Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos/lib/**/*.ex")
|> Enum.filter(fn file ->
  File.read!(file) |> String.contains?("use Ash.")
end)
IO.puts("✅ Files using Ash framework: #{length(ash_files)}")

IO.puts("\n🚀 COMPILATION TEST:")
case System.cmd("mix", ["compile", "--warnings-as-errors"], cd: "/Users/sac/dev/ai-self-sustaining-system/worktrees/xavos-system/xavos") do
  {_, 0} ->
    IO.puts("✅ XAVOS compiles without errors")
  {output, _} ->
    error_count = output |> String.split("\n") |> Enum.count(fn line -> String.contains?(line, "error:") end)
    warning_count = output |> String.split("\n") |> Enum.count(fn line -> String.contains?(line, "warning:") end)
    IO.puts("❌ XAVOS compilation issues: #{error_count} errors, #{warning_count} warnings")
end

IO.puts("\n🎯 XAVOS REALITY SUMMARY:")
IO.puts("- This is a Phoenix LiveView application with Vue.js integration")
IO.puts("- Contains monitoring dashboards and telemetry collection")
IO.puts("- Has extensive Ash framework dependencies declared but minimal usage")
IO.puts("- Focus appears to be on telemetry, validation, and reactor patterns")
IO.puts("- Missing the complete 'Ash ecosystem' implementation claimed in docs")