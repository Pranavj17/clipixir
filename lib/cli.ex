defmodule CLI do
  def main(args) do
    case args do
      ["history"] -> show_history()
      ["select"] -> interactive_select()
      _ -> start_tracker()
    end
  end

  defp show_history do
    IO.puts("Clipboard History...")

    Clipixir.list_history()
    |> Enum.each(&IO.puts("- #{&1}"))
  end

  defp start_tracker do
    IO.puts("Tracking clipboard...")
    {:ok, _pid} = Clipixir.start_link([])
    Process.sleep(:infinity)
  end

  def interactive_select() do
    Clipixir.Picker.pick_and_copy()
  end
end
