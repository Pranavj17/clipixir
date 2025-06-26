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

  @history_file Path.expand("clipboard_history.txt", __DIR__)
  @check_interval 800
  @max_age_days 7

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    schedule_check()
    {:ok, %{last: nil}}
  end

  @doc """
  Returns the clipboard history from the last N days (default: 7) as a list of maps.

  Each entry is a map with keys:
    - `:value`      — the decoded clipboard text (string)
    - `:encoded`    — base64-encoded string (internal use)
    - `:last_used`  — Unix timestamp (when this value was last seen/copied)

  The result is ordered new-to-old (most recent first).

  Entries older than 7 days are excluded from the returned list.

  ## Example

      iex> Clipixir.list_history()
      [
        %{value: "password123", encoded: "...", last_used: 1718665404},
        %{value: "Elixir cheatsheet", encoded: "...", last_used: 1718600000}
      ]

  Returns `[]` if no history exists or all entries are older than 7 days.
  """
  def list_history do
    now = :os.system_time(:second)
    cutoff = now - @max_age_days * 24 * 3600

    case File.read(@history_file) do
      {:ok, contents} ->
        contents
        # skip empty lines
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_entry/1)
        |> Enum.filter(fn
          %{last_used: last_used} when is_integer(last_used) -> last_used >= cutoff
          _ -> false
        end)

      _ ->
        []
    end
  end

  defp parse_entry(line) do
    case String.split(line, "|") do
      [enc, last_used] ->
        with {:ok, value} <- Base.decode64(enc),
             {lu, ""} <- Integer.parse(last_used) do
          %{value: value, encoded: enc, last_used: lu}
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

    if current != state.last and current != "" do
      entries = list_history()
      rest = Enum.reject(entries, &(&1.value == current))
      updated = [%{value: current, encoded: Base.encode64(current), last_used: now} | rest]
      write_entries(updated)
      schedule_check()
      {:noreply, %{state | last: current}}
    else
      schedule_check()
      {:noreply, state}
    end
  end

  @doc """
  Moves the given clipboard string to the top of the history.

  - If the value already exists, removes all other copies and updates the timestamp to now.
  - If it does not exist, adds it as the newest/first entry.
  - Maintains only entries from the last 7 days.

  Returns `:ok` after updating history.

  ## Example

      iex> Clipixir.promote_to_top_and_dedup("New clipboard text")
      :ok

  After running this, `Clipixir.list_history()` will have
  "New clipboard text" as the top/most-recent entry,
  with all other instances of that value removed.

  If the given value was not in the history, it is added as the new first entry.
  If already at the top, timestamp is updated.
  """
  def promote_to_top_and_dedup(selected_clip) when is_binary(selected_clip) do
    now = :os.system_time(:second)
    rest = list_history() |> Enum.reject(&(&1.value == selected_clip))

    updated = [
      %{value: selected_clip, encoded: Base.encode64(selected_clip), last_used: now} | rest
    ]

    write_entries(updated)
    :ok
  end

  # Write only entries <= 7 days old to file, no count
  defp write_entries(entries) do
    now = :os.system_time(:second)
    cutoff = now - @max_age_days * 24 * 3600

    file_body =
      entries
      |> Enum.filter(fn %{last_used: last_used} -> last_used >= cutoff end)
      |> Enum.map(fn %{encoded: enc, last_used: lu} -> "#{enc}|#{lu}" end)
      |> Enum.join("\n")
      |> Kernel.<>("\n")

    File.write!(@history_file, file_body)
  end

  defp get_clipboard do
    {text, 0} = System.cmd("pbpaste", [])
    String.trim_trailing(text)
  end

  defp schedule_check, do: Process.send_after(self(), :check_clipboard, @check_interval)
end
