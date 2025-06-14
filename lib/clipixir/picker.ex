defmodule Clipixir.Picker do
  @moduledoc """
  Interactive CLI picker for clipboard entries.

  ## Usage

      Clipixir.Picker.pick_and_copy()

  Runs an interactive loop to search, preview, and recopy clipboard entries.

  - `/searchterm` — fuzzy search to filter.
  - Index number — copy and promote to top (just press Enter after number).
  - `q` — quit.
  """

  @max_display 15

  @doc """
  Starts the picker loop in the current terminal.

      iex> Clipixir.Picker.pick_and_copy()
      # Interactive TUI shown

  """
  def pick_and_copy do
    entries = Clipixir.list_history()

    if entries == [] do
      IO.puts(IO.ANSI.red() <> "❗ No clipboard history found!" <> IO.ANSI.reset())
    else
      loop(entries)
    end
  end

  defp loop(entries, filtered \\ nil, searchterm \\ nil) do
    items = filtered || entries
    display_count = min(length(items), @max_display)
    IO.puts("")

    IO.puts(
      IO.ANSI.yellow() <>
        "─ Clipboard History Picker ─ (showing #{display_count} of #{length(items)}) \n" <>
        IO.ANSI.reset()
    )

    Enum.with_index(items)
    |> Enum.take(@max_display)
    |> Enum.each(fn {entry, idx} ->
      val = entry.value || ""
      lines = val |> String.split("\n")

      preview_title =
        lines |> List.first() |> take_and_ellipsize(60) |> highlight_search(searchterm)

      snippet =
        lines
        |> Enum.drop(1)
        |> Enum.join(" ")
        |> take_and_ellipsize(40)
        |> highlight_search(searchterm)

      idx_txt = IO.ANSI.green() <> "[#{idx}]" <> IO.ANSI.reset()

      info =
        IO.ANSI.faint() <>
          "[Count: #{entry.count} Last: #{format_ts(entry.last_used)}]" <>
          IO.ANSI.reset()

      IO.puts("#{idx_txt} #{IO.ANSI.bright()}#{preview_title}#{IO.ANSI.reset()} #{info}")

      if snippet != "" do
        IO.puts("    #{IO.ANSI.cyan()}#{snippet}#{IO.ANSI.reset()}")
      end

      IO.puts(IO.ANSI.faint() <> String.duplicate("─", 60) <> IO.ANSI.reset())
    end)

    if length(items) > @max_display do
      IO.puts(
        IO.ANSI.bright() <>
          IO.ANSI.magenta() <>
          "(showing first #{@max_display} results; /search to narrow list)" <>
          IO.ANSI.reset()
      )
    end

    IO.write(
      "\n" <>
        IO.ANSI.bright() <>
        "Type " <>
        IO.ANSI.green() <>
        "number" <>
        IO.ANSI.reset() <>
        IO.ANSI.bright() <>
        ", " <>
        IO.ANSI.magenta() <>
        "/search" <>
        IO.ANSI.reset() <>
        IO.ANSI.bright() <>
        ", or " <>
        IO.ANSI.red() <>
        "q" <>
        IO.ANSI.reset() <>
        IO.ANSI.bright() <>
        " to quit: " <>
        IO.ANSI.reset()
    )

    input = IO.gets("") |> to_string() |> String.trim()

    cond do
      input in ["q", "Q"] ->
        IO.puts(IO.ANSI.yellow() <> "Goodbye!" <> IO.ANSI.reset())

      String.starts_with?(input, "/") ->
        term = String.trim_leading(input, "/") |> String.downcase()

        matches =
          entries
          |> Enum.with_index()
          |> Enum.map(fn {entry, idx} -> {entry, idx, fuzzy_score(entry.value, term)} end)
          |> Enum.filter(fn {_e, _i, score} -> score < 10000 end)
          |> Enum.sort_by(fn {_e, _i, score} -> score end)
          |> Enum.map(fn {entry, _idx, _score} -> entry end)

        if matches == [] do
          IO.puts(IO.ANSI.red() <> "No entries matching #{inspect(term)}" <> IO.ANSI.reset())
        end

        loop(entries, matches, term)

      Integer.parse(input) != :error ->
        {i, _} = Integer.parse(input)

        if i >= 0 and i < length(items) do
          entry = Enum.at(items, i)
          val = entry.value || ""

          if is_binary(val) and val != "" do
            System.cmd("sh", ["-c", "printf '%s' \"$1\" | pbcopy", "_", val])
            Clipixir.promote_to_top_and_dedup(val)

            IO.puts(
              IO.ANSI.green() <>
                "Copied entry ##{i} to clipboard, now promoted to top!" <> IO.ANSI.reset()
            )
          else
            IO.puts(IO.ANSI.red() <> "Cannot copy (empty or invalid)." <> IO.ANSI.reset())
          end
        else
          IO.puts(IO.ANSI.red() <> "Invalid number: #{input}" <> IO.ANSI.reset())
          loop(entries, filtered, searchterm)
        end

      true ->
        IO.puts(IO.ANSI.red() <> "Unrecognized input: #{inspect(input)}" <> IO.ANSI.reset())
        loop(entries, filtered, searchterm)
    end
  end

  # Helpers
  defp fuzzy_score(_entry, ""), do: 10000
  defp fuzzy_score(nil, _term), do: 10000

  defp fuzzy_score(entry, term) do
    text = String.downcase(entry || "")

    cond do
      String.contains?(text, term) ->
        case :binary.match(text, term) do
          {idx, _len} -> idx
          :nomatch -> 0
        end

      fuzzy_includes?(text, term) ->
        5000 + fuzzy_distance(text, term)

      true ->
        10000
    end
  end

  # Accepts all letters of `term` in order (like fzf)
  defp fuzzy_includes?(_text, term) when term in ["", nil], do: false

  defp fuzzy_includes?(text, term) do
    chars = String.graphemes(term)
    reduce_fuzzy(text, chars)
  end

  defp reduce_fuzzy(_, []), do: true
  defp reduce_fuzzy("", _), do: false

  defp reduce_fuzzy(text, [c | rest]) do
    case String.split(text, c, parts: 2) do
      [_, rem] -> reduce_fuzzy(rem, rest)
      [_] -> false
    end
  end

  # Crude "fuzzy" distance
  defp fuzzy_distance(text, term) do
    # Total distance between character matches
    chars = String.graphemes(term)
    find_distance(text, chars, 0)
  end

  defp find_distance(_, [], dist), do: dist

  defp find_distance(text, [c | rest], dist) do
    case :binary.match(text, c) do
      {idx, _len} -> find_distance(String.slice(text, (idx + 1)..-1), rest, dist + idx)
      :nomatch -> 5000 + dist
    end
  end

  defp take_and_ellipsize(nil, _), do: ""

  defp take_and_ellipsize(str, n) when is_binary(str) do
    if String.length(str) > n, do: String.slice(str, 0, n) <> "...", else: str
  end

  defp highlight_search(str, nil), do: str
  defp highlight_search(str, ""), do: str

  defp highlight_search(str, term) when is_binary(str) and is_binary(term) and term != "" do
    String.replace(
      str,
      ~r/(#{Regex.escape(term)})/i,
      IO.ANSI.magenta() <> "\\1" <> IO.ANSI.reset()
    )
  end

  defp highlight_search(str, _), do: str

  defp format_ts(ts) when is_integer(ts) do
    {{y, mo, d}, {h, mi, _s}} = :calendar.gregorian_seconds_to_datetime(ts + 62_167_219_200)

    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B", [y, mo, d, h, mi])
    |> to_string()
  end

  defp format_ts(_), do: ""
end
