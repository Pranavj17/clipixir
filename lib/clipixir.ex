defmodule Clipixir do
  @moduledoc """
  Clipixir is a terminal clipboard manager and history tracker.

  ## Features

    * Auto-promotes most recent clipboard entry.
    * Deduplicates and stores last 1000 clipboard texts.
    * Tracks usage count and last used timestamp.
    * Plain text history file, easy to inspect or backup.
    * Robust against crash, restarts, accidental bad lines.

  ## Example

      # Start tracking clipboard in the background
      {:ok, _pid} = Clipixir.start_link([])

      # List clipboard history (returns list of %{value, count, last_used, ...})
      Clipixir.list_history()

      # Promote a copied entry explicitly (if not already tracked)
      Clipixir.promote_to_top_and_dedup("your copied content")

  """

  use GenServer
  @history_file "clipboard_history.txt"
  @check_interval 800
  @max_entries 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    schedule_check()
    {:ok, %{last: nil}}
  end

  @doc """
  Returns a list of `%{value, encoded, last_used, count}` entries, newest first.

  ## Example

      iex> Clipixir.list_history()
      [%{value: "foo\nbar", count: 4, last_used: 1715753340, encoded: ...}, ...]

  """
  def list_history() do
    case File.read(@history_file) do
      {:ok, contents} ->
        contents
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_entry/1)
        |> Enum.filter(&is_map/1)

      _ ->
        []
    end
  end

  defp parse_entry(line) do
    case String.split(line, "|") do
      [enc, last_used, count] ->
        with {:ok, value} <- Base.decode64(enc),
             {lu, ""} <- Integer.parse(last_used),
             {cnt, ""} <- Integer.parse(count) do
          %{
            value: value,
            encoded: enc,
            last_used: lu,
            count: cnt
          }
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def handle_info(:check_clipboard, state) do
    current = get_clipboard()
    now = :os.system_time(:second)
    entries = list_history()

    already_top =
      case entries do
        [%{value: ^current} | _] -> true
        _ -> false
      end

    cond do
      current == state.last or current == "" or already_top ->
        schedule_check()
        {:noreply, state}

      true ->
        # Remove all existing occurrences
        rest = Enum.reject(entries, &(&1.value == current))

        count =
          (entries
           |> Enum.filter(&(&1.value == current))
           |> Enum.map(& &1.count)
           |> Enum.max(fn -> 0 end)) + 1

        updated = [
          %{value: current, encoded: Base.encode64(current), last_used: now, count: count}
          | rest
        ]

        write_entries(updated)
        schedule_check()
        {:noreply, %{state | last: current}}
    end
  end

  @doc """
  Promotes the given clipboard string to the top of the history, increments its usage count,
  and removes older duplicate entries. Also updates the timestamp.

      iex> Clipixir.promote_to_top_and_dedup("foo bar")
      :ok  # (side effect: updates file)

  """
  def promote_to_top_and_dedup(selected_clip) when is_binary(selected_clip) do
    now = :os.system_time(:second)
    entries = list_history()

    rest = Enum.reject(entries, &(&1.value == selected_clip))

    count =
      (entries
       |> Enum.filter(&(&1.value == selected_clip))
       |> Enum.map(& &1.count)
       |> Enum.max(fn -> 0 end)) + 1

    updated = [
      %{value: selected_clip, encoded: Base.encode64(selected_clip), last_used: now, count: count}
      | rest
    ]

    write_entries(updated)
  end

  defp write_entries(entries) do
    # Auto-trim logic
    now = :os.system_time(:second)
    cutoff = now - 7 * 24 * 3600

    result =
      if length(entries) > @max_entries do
        entries
        |> Enum.sort_by(fn %{last_used: lu, count: cnt} -> {lu >= cutoff, cnt, lu} end, :desc)
        |> Enum.take(@max_entries)
      else
        entries
      end

    File.write!(
      @history_file,
      (Enum.map(result, fn %{encoded: enc, last_used: lu, count: cnt} ->
         "#{enc}|#{lu}|#{cnt}"
       end)
       |> Enum.join("\n")) <> "\n"
    )
  end

  defp get_clipboard do
    {text, 0} = System.cmd("pbpaste", [])
    String.trim_trailing(text)
  end

  defp schedule_check(), do: Process.send_after(self(), :check_clipboard, @check_interval)
end
